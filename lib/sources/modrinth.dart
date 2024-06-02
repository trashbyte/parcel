import 'dart:convert';
import 'dart:io';
import 'package:convert/convert.dart';
import 'package:hash/hash.dart';
import 'package:http/http.dart' as http;
import 'package:parcel/util.dart';

import '../project.dart';
import '../validator.dart';
import '../cache.dart';
import 'source.dart';


class ModrinthSource extends ModSource {
    String projectId = "";
    String versionId = "";
    Map? projectData;
    Map? packVerData;
    Map? latestVersionData;

    ModrinthSource();

    ModrinthSource.parse(Map input) {
        var (res, errs) = TypeValidator<Map>()
            .withPrimitiveField('project', TypeOfTag.string)
            .withPrimitiveField('version', TypeOfTag.string)
            .validate(input);
        if (errs.isNotEmpty) {
            throw "Failed to parse Modrinth mod source. The following errors occured:\n${errs.join('\n')}";
        }
        else {
            this.projectId = res!['project'];
            this.versionId = res['version'];
        }
    }


    @override
    Future<SourceStatus> fetchInfo(ProjectData packInfo, String filename) async {
        this.status = SourceStatus.missing;
        var filePath = "${localInstanceDir(packInfo.rootPath)}/mods/$filename";
        if (await File(filePath).exists()) {
            this.status = SourceStatus.behindPack;
        }

        var projectCachePath = "modrinth/${this.projectId}/project.json";
        var packVersionCachePath = "modrinth/${this.projectId}/${this.versionId}.json";
        var latestVersionsCachePath = "modrinth/${this.projectId}/latest.json";

        // fetch project info
        var maybeProjectCache = await ModCache.getCacheEntry(projectCachePath);
        if (maybeProjectCache != null) {
            this.projectData = maybeProjectCache;
        }
        else {
            var url = Uri.https("api.modrinth.com", "/v2/project/${this.projectId}");
            var resp = await http.get(url);
            if (resp.statusCode != 200) {
                throw "Failed to query $url: Server returned code ${resp.statusCode}.";
            }
            this.projectData = jsonDecode(resp.body);
            await ModCache.setCacheEntry(projectCachePath, this.projectData);
        }
        this.thumbnailURL = this.projectData!['icon_url'];

        // fetch pack version info
        var maybePackVerCache = await ModCache.getCacheEntry(packVersionCachePath);
        if (maybePackVerCache != null) {
            this.packVerData = maybePackVerCache;
        }
        else {
            var url = Uri.https("api.modrinth.com", "/v2/version/${this.versionId}");
            var resp = await http.get(url);
            if (resp.statusCode != 200) {
                throw "Failed to query $url: Server returned code ${resp.statusCode}.";
            }
            this.packVerData = jsonDecode(resp.body);
            await ModCache.setCacheEntry(packVersionCachePath, this.packVerData);
        }
        Map? file;
        if (this.packVerData!['files'].length > 1) {
            for (var f in this.packVerData!['files']) {
                if (f['primary'] == true) {
                    file = f;
                }
            }
            if (file == null) {
                throw "Modrinth mod version ${this.projectId}:${this.versionId} has multiple designated files but none are marked as primary.";
            }
        }
        else {
            file = this.packVerData!['files'][0];
        }
        String? currentHash;
        if (this.status == SourceStatus.behindPack) {
            var packVerHash = file!['hashes']['sha1'].toLowerCase();
            var bytes = await File(filePath).readAsBytes();
            currentHash = hex.encode(SHA1().update(bytes).digest()).toLowerCase();
            if (packVerHash == currentHash) {
                this.status = SourceStatus.current;
            }
        }

        // fetch latest versions
        var latestCacheTimestamp = await ModCache.cacheEntryTimestamp(latestVersionsCachePath);
        if (latestCacheTimestamp != null && DateTime.now().difference(latestCacheTimestamp) < const Duration(hours: 24)) {
            this.latestVersionData = (await ModCache.getCacheEntry(latestVersionsCachePath))!;
        }
        else {
            var url = Uri.https("api.modrinth.com", "/v2/project/${this.projectId}/version");
            var resp = await http.get(url);
            if (resp.statusCode != 200) {
                throw "Failed to query $url: Server returned code ${resp.statusCode}.";
            }
            var latestVersions = jsonDecode(resp.body);
            DateTime? latestDate;
            Map? latestVer;
            for (var ver in latestVersions) {
                if (ver['game_versions'].contains(packInfo.mcVersion)) {
                    var date = DateTime.parse(ver['date_published']);
                    if (latestDate == null || date.isAfter(latestDate)) {
                        latestDate = date;
                        latestVer = ver;
                    }
                }
            }
            if (latestVer == null) {
                throw "Failed to find a version for Modrinth mod ${this.projectId} for game version ${packInfo.mcVersion}";
            }
            this.latestVersionData = latestVer;
            await ModCache.setCacheEntry(latestVersionsCachePath, latestVer);
        }
        if (currentHash != null && this.status == SourceStatus.current) {
            Map? file;
            if (this.latestVersionData!['files'].length > 1) {
                for (var f in this.latestVersionData!['files']) {
                    if (f['primary'] == true) {
                        file = f;
                    }
                }
                if (file == null) {
                    throw "Modrinth mod version ${this.projectId}:${this.latestVersionData!['id']} has multiple designated files but none are marked as primary.";
                }
            }
            else {
                file = this.latestVersionData!['files'][0];
            }
            
            var latestHash = this.latestVersionData!['files'][0]['hashes']['sha1'];
            if (latestHash != currentHash) {
                this.status = SourceStatus.behindSource;
            }
        }

        return this.status;
    }


    @override
    Future<void> download(ProjectData packInfo, String filename, void Function(double) callback) async {
        if (this.status == SourceStatus.downloading) {
            return;
        }
        if (this.packVerData == null) {
            await this.fetchInfo(packInfo, filename);
        }
        this.status = SourceStatus.downloading;
        Map? file;
        if (this.packVerData!['files'].length > 1) {
            for (var f in this.packVerData!['files']) {
                if (f['primary'] == true) {
                    file = f;
                }
            }
            if (file == null) {
                throw "Modrinth mod version ${this.projectId}:${this.versionId} has multiple designated files but none are marked as primary.";
            }
        }
        else {
            file = this.packVerData!['files'][0];
        }
        var url = file!['url'];
        var resp = await http.Client().send(
            http.Request('GET', Uri.parse(url))
        );
        
        var total = resp.contentLength ?? 0;
        var received = 0;
        List<int> bytes = [];

        resp.stream.listen((value) {
            bytes.addAll(value);
            received += value.length;
            this.downloadProgress = total != 0 ? (received / total) : 0;
            callback(this.downloadProgress);
        }).onDone(() async {
            var modDir = "${localInstanceDir(packInfo.rootPath)}/mods";
            await Directory(modDir).create();
            var outputPath = "$modDir/$filename";
            
            await File(outputPath).writeAsBytes(bytes);
            callback(1.0);
        });
    }
    
    @override
    Future<void> delete(ProjectData packInfo, String filename) async {
        if (this.status == SourceStatus.downloading) {
            return;
        }
        var localFilePath = "${localInstanceDir(packInfo.rootPath)}/mods/$filename";
        if (await File(localFilePath).exists()) {
            await File(localFilePath).delete();
        }
        await this.fetchInfo(packInfo, filename);
    }
    
    @override
    String iconPath() {
        return "assets/icons/modrinth.png";
    }
}