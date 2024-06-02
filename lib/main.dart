import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parcel/util.dart';
import 'package:window_size/window_size.dart';
import 'package:path/path.dart' as path;

import 'project.dart';
import 'widgets/mod_list.dart';

enum AppSignal {
    closeProject,
    openProject,
    setLocalPath,
}

void main() {
    WidgetsFlutterBinding.ensureInitialized();
    final navigator = GlobalKey<NavigatorState>();
    FlutterError.onError = (details) {
        navigator.currentState!.push(MaterialPageRoute(builder: (context) {
            return SimpleDialog(children: [Text(details.exception.toString())]);
        }));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
        navigator.currentState!.push(MaterialPageRoute(builder: (context) {
            return SimpleDialog(children: [
                Text(error.toString()),
                Text(stack.toString()),
            ]);
        }));
        return true;
    };
    runApp(const ParcelApp());
}

class ParcelApp extends StatefulWidget {
  const ParcelApp({super.key});

  @override
  State<StatefulWidget> createState() => ParcelState();
}

class ParcelState extends State<ParcelApp> {
    String title = "Parcel";
    ProjectData? project;

    void setTitle(String? title) {
        setWindowTitle(title == null ? "Parcel" : "Parcel: $title");
        this.title = title ?? "No pack open";
    }


    Future<ProjectData?> _openPack() async {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
            dialogTitle: "Select pack.toml",
            allowMultiple: false,
            type: FileType.custom,
            allowedExtensions: ["toml"],
            lockParentWindow: true,
        );
        if (result != null) {
            String tomlPath = result.files.single.path!;
            var maybeProject = await ProjectData.load(tomlPath);
            if (maybeProject.isOk) {
                var project = maybeProject.unwrap();
                if (!localDefExists(project.rootPath)) {
                    await showSimpleDialog("Need instance path", "Modpack requires a local instance path. Please provide the path to the local Minecraft instance (the \".minecraft\" folder) for this pack.", false);
                    if (!(await this.userSelectLocalDef(project.rootPath))) {
                        await showSimpleDialog("Canceled", "Operation canceled.", false);
                        return null;
                    }
                }
                return project;
            }
            else {
                await showSimpleDialog("Error", "Error(s) parsing pack.toml:\n${maybeProject.unwrapErr().join("\n")}", true);
            }
        } else {
            await showSimpleDialog("Canceled", "Operation canceled.", false);
        }
        return null;
    }


    Future<bool> userSelectLocalDef(String rootPath) async {
        String? localPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: "Select instance folder",
            lockParentWindow: true,
        );
        if (localPath != null) {
            if (path.basename(localPath).toLowerCase() != ".minecraft") {
                var confirm = await showConfirmDialog("Warning", "The selected path does not appear to be a \".minecraft\" instance folder. Are you sure you want to choose this folder?");
                if (confirm) {
                    writeLocalDef(rootPath, localPath);
                    return true;
                }
                else {
                    await showSimpleDialog("Canceled", "Operation canceled.", false);
                    return false;
                }
            }
            writeLocalDef(rootPath, localPath);
            return true;
        }
        await showSimpleDialog("Canceled", "Operation canceled.", false);
        return false;
    }


    

    Future<void> onSignal(AppSignal signal) async {
        if (signal == AppSignal.closeProject) {
            this.setState(() {
                this.project = null;
                this.setTitle(null);
            });
        }
        else if (signal == AppSignal.openProject) {
            var result = await this._openPack();
            if (result != null) {
                this.setState(() {
                    this.project = result;
                    this.setTitle(this.project?.name);
                });
            }
        }
        else if (signal == AppSignal.setLocalPath) {
            if (this.project == null) {
                throw "Tried to change local path while project was null. This is a bug in Parcel and should never happen.";
            }
            await this.userSelectLocalDef(this.project!.rootPath);
        }
    }

    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            title: this.title,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
                useMaterial3: true,
            ),
            home: Container(
                color: Theme.of(context).colorScheme.surface,
                child: this.project == null
                    ? Center(child: FilledButton(
                        onPressed: () async {
                            var result = await this._openPack();
                            this.setState(() {
                                this.project = result;
                                this.setTitle(this.project?.name ?? "");
                            });
                        },
                        child: const Text("Open Pack"))
                    )
                    : ModListPage(project: this.project!, title: this.title, emit: (e) => this.onSignal(e)),
            ),
        );
    }
}