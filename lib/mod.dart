import 'package:parcel/project.dart';
import 'package:parcel/sources/source.dart';

enum SideUsage {
    optional, necessary, unsupported, excluded;

    @override String toString() {
        switch (this) {
          case SideUsage.optional:
            return "optional";
          case SideUsage.necessary:
            return "required";
          case SideUsage.unsupported:
            return "unsupported";
          case SideUsage.excluded:
            return "excluded";
        }
    }
}

SideUsage parseUsage(String input) {
    switch (input.toLowerCase()) {
        case 'optional': return SideUsage.optional;
        case 'required': return SideUsage.necessary;
        case 'unsupported': return SideUsage.unsupported;
        case 'excluded': return SideUsage.excluded;
        default: throw "Unrecognized mod usage: '$input'";
    }
}

class ModInfo {
    late String name;
    late String filename;
    late SideUsage server;
    late SideUsage client;
    late ModSource source;
    String? note;
    WeakReference<ProjectData> project;

    ModInfo(Map data, this.project) {
        if (!data.containsKey('server')) {
            throw "Mod is missing required field 'name'.";
        }
        this.name = data['name'];
        this.filename = data['filename'] ?? ModInfo.sanitize(this.name);
        if (!data.containsKey('server')) {
            throw "Mod '${this.name}' is missing required field 'server'.";
        }
        this.server = parseUsage(data['server'] as String);
        if (!data.containsKey('client')) {
            throw "Mod '${this.name}' is missing required field 'client'.";
        }
        this.client = parseUsage(data['client'] as String);
        if (!data.containsKey('source')) {
            throw "Mod '${this.name}' is missing required field 'source'.";
        }
        this.source = parseModSource(data['source'] as Map);
        this.note = data['note'];
    }

    Future<SourceStatus> fetch() async {
        return await this.source.fetchInfo(this.project.target!, this.filename);
    }

    download(void Function(double) callback) {
        this.source.download(this.project.target!, this.filename, callback);
    }

    delete() async {
        await this.source.delete(this.project.target!, this.filename);
    }

    Future<bool> localFileExists() async {
        return await this.source.localFileExists(this.project.target!, this.filename);
    }

    String filePath(String root) {
        return root + this.filename;
    }

    String sourceIconPath() {
        return this.source.iconPath();
    }

    static String sanitize(String input) {
        return input.replaceAll(RegExp(r'/[^ ]:[^ ]/g'), '-')  // x:x   ->  x-x
                    .replaceAll(':', '')            // x: x  ->  x x
                    .replaceAll('"', '')
                    .replaceAll(RegExp(r"/['\?]/g"), '');
    }

    bool isOptionalFor(bool serverMode) {
        return (serverMode && this.server == SideUsage.optional) || (!serverMode && this.client == SideUsage.optional);
    }
}