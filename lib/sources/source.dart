import 'dart:io';

import '../project.dart';
import '../util.dart';
import 'curseforge.dart';
import 'modrinth.dart';


enum SourceStatus {
    unknown, missing, behindPack, behindSource, current, downloading, noInfo;

    @override
    String toString() {
        switch (this) {
            case SourceStatus.unknown:
                return "Unknown";
            case SourceStatus.missing:
                return "Missing";
            case SourceStatus.behindPack:
                return "Behind pack";
            case SourceStatus.behindSource:
                return "Behind source";
            case SourceStatus.current:
                return "Current";
            case SourceStatus.downloading:
                return "Downloading...";
            case SourceStatus.noInfo:
                return "No info";
        }
    }
}

abstract class ModSource {
    SourceStatus status = SourceStatus.unknown;
    String? thumbnailURL;
    double downloadProgress = 0.0;

    Future<SourceStatus> fetchInfo(ProjectData packInfo, String filename);
    Future<void> download(ProjectData packInfo, String filename, void Function(double) callback);
    Future<void> delete(ProjectData packInfo, String filename);
    String iconPath();
    
    Future<bool> localFileExists(ProjectData packInfo, String filename) async {
        if (this.status == SourceStatus.downloading) {
            return false;
        }
        var localFilePath = "${localInstanceDir(packInfo.rootPath)}/mods/$filename";
        return await File(localFilePath).exists();
    }
}

ModSource parseModSource(dynamic input) {
    switch(input['type'].toLowerCase()) {
        case 'modrinth': return ModrinthSource.parse(input);
        case 'curseforge': return CurseforgeSource.parse(input);
        //case 'url': return UrlSource.parse(input);
        default: throw "Mod source has unsupported type '${input['type']}'";
    }
}


