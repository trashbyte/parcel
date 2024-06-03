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


// ignore: constant_identifier_names
const String API_KEY = r"$2a$10$6btsAQi/jT7rvrD5A8D9W.VnGhv6Ngyt0kaRmbviQn.OTRxuxAPuK";

Future<Map> apiRequest(String path) async {
    var url = Uri.https("api.curseforge.com", path);
    var resp = await http.get(url, headers: { 'x-api-key': API_KEY });
    if (resp.statusCode != 200) {
        throw "Failed to query $url: Server returned code ${resp.statusCode}.";
    }

    var json = jsonDecode(resp.body);
    return json['data'];
}

Future<bool> hashCheck(File localFile, List<dynamic> hashes) async {
    if (!(await localFile.exists())) {
        return false;
    }
    List<int> bytes = await localFile.readAsBytes();
    // try SHA1 first
    for (var entry in hashes) {
        if (entry['algo'] == 1) {
            var remoteHash = entry['value'].toLowerCase();
            var localHash = hex.encode(SHA1().update(bytes).digest()).toLowerCase();
            return remoteHash == localHash;
        }
    }
    // if no SHA1, use MD5
    for (var entry in hashes) {
        if (entry['algo'] == 2) {
            var remoteHash = entry['value'].toLowerCase();
            var localHash = hex.encode(MD5().update(bytes).digest()).toLowerCase();
            return remoteHash == localHash;
        }
    }
    return false;
}


class CurseforgeSource extends ModSource {
    String projectId = "";
    String fileId = "";
    Map? projectInfo;
    Map? packVerInfo;

    CurseforgeSource();

    CurseforgeSource.parse(Map input) {
        var (res, errs) = TypeValidator<Map>()
            .withPrimitiveField('project', TypeOfTag.string)
            .withPrimitiveField('file', TypeOfTag.string)
            .validate(input);
        if (errs.isNotEmpty) {
            throw "Failed to parse Curseforge mod source. The following errors occured:\n${errs.join('\n')}";
        }
        else {
            this.projectId = res!['project'];
            this.fileId = res['file'];
        }
    }


    @override
    Future<SourceStatus> fetchInfo(ProjectData packInfo, String filename) async {
        this.status = SourceStatus.missing;
        var filePath = "${localInstanceDir(packInfo.rootPath)}/mods/$filename";
        var localFileExists = await File(filePath).exists();

        // fetch mod project info
        var projectDataCachePath = "curseforge/${this.projectId}.json";
        var maybeProject = await ModCache.getCacheEntry(projectDataCachePath);
        if (maybeProject != null) {
            this.projectInfo = maybeProject;
        }
        else {
            var json = await apiRequest("/v1/mods/${this.projectId}");
            this.projectInfo = json;
            await ModCache.setCacheEntry(projectDataCachePath, json);
        }
        this.thumbnailURL = this.projectInfo!['logo']['thumbnailUrl'];

        // get date of pack version
        var resp = await apiRequest("/v1/mods/${this.projectId}/files/${this.fileId}");
        this.packVerInfo = resp;

        // find latest version
        Map? latestVerInfo;
        DateTime? latestDate;
        for (var ver in this.projectInfo!['latestFilesIndexes']) {
            if (ver['gameVersion'] != packInfo.mcVersion) {
                continue;
            }
            String id = ver['fileId'].toString();
            var resp = await apiRequest("/v1/mods/${this.projectId}/files/$id");
            var date = DateTime.parse(resp['fileDate']);
            if (latestDate == null || date.isAfter(latestDate)) {
                latestDate = date;
                latestVerInfo = ver;
            }
        }
        if (latestVerInfo == null) {
            throw "Failed to find a version for Modrinth mod ${this.projectId} for game version ${packInfo.mcVersion}";
        }
        
        if (!localFileExists) {
            this.status = SourceStatus.missing;
        }
        else {
            var upToDateWithPack = await hashCheck(File(filePath), this.packVerInfo!['hashes']);
            if (!upToDateWithPack) {
                this.status = SourceStatus.behindPack;
            }
            else {
                var packVerIsLatest = this.packVerInfo!['id'] == latestVerInfo['id'];
                this.status = packVerIsLatest ? SourceStatus.current : SourceStatus.behindSource;
            }
        }

        return this.status;
    }


    @override
    Future<void> download(ProjectData packInfo, String filename, void Function(double) callback) async {
        if (this.status == SourceStatus.downloading) {
            return;
        }
        if (this.packVerInfo == null) {
            await this.fetchInfo(packInfo, filename);
        }
        this.status = SourceStatus.downloading;
        
        var url = this.packVerInfo!['downloadUrl'];
        if (url == null) {
            throw "Curseforge mod ${this.projectId}:${this.fileId} is not available for remote download. Please contact the mod author.";
        }
        var req = http.Request('GET', Uri.parse(url));
        req.headers['x-api-key'] = API_KEY;
        var resp = await http.Client().send(req);
        
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
        return "assets/icons/curseforge.png";
    }
    
    @override
    String? modURL() {
        return this.projectInfo?['links']?['websiteUrl'];
    }
}