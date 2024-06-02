import 'dart:io';

import 'package:parcel/mod.dart';
import 'package:parcel/util.dart';
import 'package:parcel/validator.dart';
import 'package:toml/toml.dart';



class ProjectData {
    int version = -1;
    String rootPath = "";
    String name = "";
    List<String> authors = [];
    String packVersion = "";
    String mcVersion = "";
    String loader = "";
    String loaderVersion = "";
    bool dirty = false;

    List<ModInfo> mods = [];

    ProjectData();

    static Future<Result<ProjectData, List<String>>> load(String filePath) async {
        if (!await File(filePath).exists()) {
            throw "Given path '$filePath' does not exist.";
        }

        var data = ProjectData();
        data.rootPath = File(filePath).parent.path;
        var toml = (await TomlDocument.load(filePath)).toMap();

        for (var key in toml.keys) {
            if (key.toLowerCase() == 'pack') {
                Map<String, dynamic> meta = toml[key];
                var (result, errs) = TypeValidator<Map>()
                    .withPrimitiveField('version', TypeOfTag.number)
                    .withPrimitiveField('name', TypeOfTag.string)
                    .withArrayField('authors', ArrayValidators(validateEach: (s) => s is String))
                    .withPrimitiveField('mcVersion', TypeOfTag.string)
                    .withPrimitiveField('packVersion', TypeOfTag.string)
                    .withPrimitiveField('loader', TypeOfTag.string)
                    .withPrimitiveField('loaderVersion', TypeOfTag.string)
                    .validate(meta);
                if (errs.isNotEmpty) {
                    return Result.err(errs);
                }
                data.version = result!['version'];
                data.name = result['name'];
                data.authors = List.from(result['authors'].map((x) => x.toString()));
                data.mcVersion = result['mcVersion'];
                data.packVersion = result['packVersion'];
                data.loader = result['loader'];
                data.loaderVersion = result['loaderVersion'];
            }
            else if (key.toLowerCase() == 'mod') {
                for (var mod in toml[key]) {
                    data.mods.add(ModInfo(mod, WeakReference(data)));
                }
            }
            else {
                // throw `Unrecognized table found in toml file: '${key}'`
            }
        }

        return Result.ok(data);
    }
}