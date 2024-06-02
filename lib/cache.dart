import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:parcel/util.dart';


// ignore: constant_identifier_names
const Duration CACHE_DURATION = Duration(hours: 12);


class ModCache {
    static Future<DateTime?> cacheEntryTimestamp(String subpath) async {
        File f = File("${cacheDir()}/$subpath");
        if (!await f.exists()) {
            return null;
        }
        return await f.lastModified();
    }

    static Future<dynamic> getCacheEntry(
        String subpath,
        { Duration cacheDuration = CACHE_DURATION }
    ) async {
        var ts = await cacheEntryTimestamp(subpath);
        if (ts == null) {
            return null;
        }
        if (DateTime.now().difference(ts) > cacheDuration) {
            return null;
        }
        var cachePath = "${cacheDir()}/$subpath";
        if (await File(cachePath).exists()) {
            var contents = await File(cachePath).readAsString();
            return jsonDecode(contents);
        }
        return null;
    }

    static Future<void> setCacheEntry(String subpath, dynamic data) async {
        var cachePath = "${cacheDir()}/$subpath";
        var folder = path.dirname(cachePath);
        await Directory(folder).create(recursive: true);
        await File(cachePath).create();
        await File(cachePath).writeAsString(jsonEncode(data));
    }

    static Future<String?> tryGetThumbnail(String thumbPath) async {
        if (await File(thumbPath).exists()) {
            return thumbPath;
        }
        else {
            return null;
        }
    }

    static Future<String> setThumbnail(String thumbPath, List<int> data) async {
        var folder = path.dirname(thumbPath);
        await Directory(folder).create(recursive: true);
        await File(thumbPath).writeAsBytes(data);
        return thumbPath;
    }
}