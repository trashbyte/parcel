import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:parcel/mod.dart';
import 'package:parcel/project.dart';
import 'package:parcel/util.dart';
import 'package:parcel/widgets/mod_list_entry.dart';

import 'package:path/path.dart' as path;

import '../main.dart';
import '../sources/source.dart';


const int menuDividerIdx = 2;

enum MenuItem {
    open(idx: 0, text: "Open Pack", icon: Icons.folder_open),
    close(idx: 1, text: "Close Pack", icon: Icons.close),

    setLocalPath(idx: 2, text: "Set Local Instance Path", icon: Icons.drive_file_move_outline),
    clean(idx: 3, text: "Clean Leftover Mods", icon: Icons.delete_outline),
    ;

    const MenuItem({ required this.idx, required this.text, required this.icon });

    final int idx;
    final String text;
    final IconData icon;
}


class ModListPage extends StatefulWidget {
  const ModListPage({super.key, required this.project, required this.title, required this.emit});

  final String title;
  final ProjectData project;
  final void Function(AppSignal) emit;

  @override
  // ignore: no_logic_in_create_state
  State<ModListPage> createState() => _ModListPageState(this.project);
}

class _ModListPageState extends State<ModListPage> {
    ProjectData project;
    final ScrollController _scrollController = ScrollController();
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
    bool _downloading = false;
    bool _serverMode = false;

    _ModListPageState(this.project);

    @override
    void initState() {
        super.initState();
        this.initAsync();
    }

    @override
    void activate() {
        super.activate();
        this.initAsync();
    }

    void initAsync() async {
        for (var mod in this.project.mods) {
            await mod.fetch();
            this.setState(() {});
        }
    }

    Future<void> _showCopyCompleteDialog(String title, String msg) async {
        return showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
                return AlertDialog(
                    title: Text(title),
                    content: SingleChildScrollView(
                        child: ListBody(
                            children: <Widget>[
                                Text(msg),
                            ],
                        ),
                    ),
                    actions: <Widget>[
                        TextButton(
                            child: const Text('OK'),
                            onPressed: () {
                                Navigator.of(context).pop();
                            },
                        ),
                    ],
                );
            },
        );
    }

    void _copyOverrides() async {
        var dirPath = "${this.project.rootPath}/overrides";
        var dir = Directory(dirPath);

        if (!(await dir.exists())) {
            this._showCopyCompleteDialog('Complete', 'Overrides copied to instance folder.');
            return;
        }
        
        try {
            var instancePath = localInstanceDir(this.project.rootPath);
            var dirList = dir.list(recursive: true);
            await for (final FileSystemEntity f in dirList) {
                if (f is File) {
                    var rel = path.relative(f.path, from: dirPath);
                    var targetPath = "$instancePath/$rel";
                    await File(targetPath).parent.create(recursive: true);
                    await f.copy(targetPath);
                }
            }
            this._showCopyCompleteDialog('Complete', 'Overrides copied to instance folder.');
        } catch (e) {
            this._showCopyCompleteDialog('Error', 'An error occurred: ${e.toString()}');
            return;
        }
    }

    void _downloadAll(bool isServer) async {
        if (this._downloading) { return; }

        List<ModInfo> toDownload = [];
        List<(ModInfo, bool)> optionals = [];
        for (var m in this.project.mods) {
            switch (isServer ? m.server : m.client) {
              case SideUsage.optional:
                optionals.add((m, await m.localFileExists()));
              case SideUsage.necessary:
                toDownload.add(m);
              case SideUsage.unsupported:
                continue;
              case SideUsage.excluded:
                continue;
            }
        }

        if (optionals.isNotEmpty) {
            List<ModInfo>? selectedOptionals = await showDialog<List<ModInfo>>(
                context: context,
                barrierDismissible: false,
                builder: (context) => StatefulBuilder(
                    builder: (BuildContext context, setState) {
                        List<Widget> promptWidgets = [];
                        for (var (idx, (mod, selected)) in optionals.indexed) {
                            promptWidgets.add(Row(
                                children: [
                                    Checkbox(value: selected, onChanged: (v) {
                                        setState(() => optionals[idx] = (optionals[idx].$1, v ?? false));
                                    }),
                                    Text(mod.name)
                                ],
                            ));
                        }
                        return AlertDialog(
                            title: const Text("Optional mods"),
                            content: SingleChildScrollView(
                                child: ListBody(
                                    children: promptWidgets,
                                ),
                            ),
                            actions: <Widget>[
                                FilledButton(
                                    child: const Text('OK'),
                                    onPressed: () {
                                        Navigator.of(context).pop(
                                            optionals.where((tuple) => tuple.$2)
                                                .map((tuple) => tuple.$1)
                                                .toList()
                                        );
                                    },
                                ),
                                TextButton(
                                    child: const Text('Cancel'),
                                    onPressed: () {
                                        Navigator.of(context).pop();
                                    },
                                ),
                            ],
                        );
                    },
                ),
            );
            if (selectedOptionals == null) {
                return;
            }
            toDownload.addAll(selectedOptionals);
        }

        this._downloading = true;
        for (var m in toDownload) {
            if (m.source.status == SourceStatus.unknown) {
                await m.fetch();
            }
            if (m.source.status == SourceStatus.behindPack || m.source.status == SourceStatus.missing) {
                var c = Completer();
                m.download((progress) async {
                    if (progress == 1.0) {
                        await m.fetch();
                        if (!c.isCompleted) {
                            c.complete();
                        }
                    }
                    this.setState(() {});
                });
                await c.future;
            }
        }
        this._downloading = false;
    }

    Future<void> _clean() async {
        List<(String, bool)> leftovers = [];
        await for (var entry in Directory("${localInstanceDir(this.project.rootPath)}/mods").list()) {
            var filename = path.basename(entry.path);
            if (!this.project.mods.any((m) => m.filename == filename)) {
                leftovers.add((filename, false));
            }
        }
        if (leftovers.isEmpty) {
            await showSimpleDialog("No Leftover Files", "No leftover mod files found.", false);
            return;
        }
        List<String>? selectedFiles = await showDialog<List<String>>(
            context: context,
            barrierDismissible: false,
            builder: (context) => StatefulBuilder(
                builder: (BuildContext context, setState) {
                    List<Widget> promptWidgets = [];
                    for (var (idx, (fname, selected)) in leftovers.indexed) {
                        promptWidgets.add(Row(
                            children: [
                                Checkbox(value: selected, onChanged: (v) {
                                    setState(() => leftovers[idx] = (leftovers[idx].$1, v ?? false));
                                }),
                                Text(fname)
                            ],
                        ));
                    }
                    return AlertDialog(
                        title: const Text("Clean Files"),
                        content: SingleChildScrollView(
                            child: ListBody(
                                children: promptWidgets,
                            ),
                        ),
                        actions: <Widget>[
                            FilledButton(
                                child: const Text('OK'),
                                onPressed: () {
                                    Navigator.of(context).pop(
                                        leftovers.where((tuple) => tuple.$2)
                                            .map((tuple) => tuple.$1)
                                            .toList()
                                    );
                                },
                            ),
                            TextButton(
                                child: const Text('Cancel'),
                                onPressed: () {
                                    Navigator.of(context).pop();
                                },
                            ),
                        ],
                    );
                },
            ),
        );
        if (selectedFiles != null && selectedFiles.isNotEmpty) {
            for (var str in selectedFiles) {
                await File("${localInstanceDir(this.project.rootPath)}/mods/$str").delete();
            }
            await showSimpleDialog("Files Deleted", "Deleted ${selectedFiles.length} files", false);
        }
    }

    void _openMenu() {
        scaffoldKey.currentState!.openDrawer();
    }

    void handleMenuItemSelected(int selectedItem) async {
        if (selectedItem == MenuItem.open.idx) {
            this.widget.emit(AppSignal.openProject);
        }
        else if (selectedItem == MenuItem.close.idx) {
            this.widget.emit(AppSignal.closeProject);
        }
        else if (selectedItem == MenuItem.setLocalPath.idx) {
            this.widget.emit(AppSignal.setLocalPath);
        }
        else if (selectedItem == MenuItem.clean.idx) {
            await this._clean();
        }
        scaffoldKey.currentState!.closeDrawer();
    }

    final WidgetStateProperty<Icon?> thumbIcon = WidgetStateProperty.resolveWith<Icon?>(
        (Set<WidgetState> states) {
            return states.contains(WidgetState.selected)
                ? const Icon(Icons.dvr)
                : const Icon(Icons.sports_esports);
        },
    );

    final WidgetStateProperty<MaterialColor?> switchOutlineColor = WidgetStateProperty.resolveWith<MaterialColor?>(
        (Set<WidgetState> states) {
            return states.contains(WidgetState.selected)
                ? Colors.blue
                : Colors.green;
        },
    );

    @override
    Widget build(BuildContext context) {
        var altCount = 0;
        List<ModListEntry> mods = [];
        for (var m in this.project.mods) {
            if (
                (this._serverMode && (m.server == SideUsage.unsupported || m.server == SideUsage.excluded))
                || (!this._serverMode && (m.client == SideUsage.unsupported || m.client == SideUsage.excluded))
            ) {
                continue;
            }
            else {
                ++altCount;
                mods.add(ModListEntry(
                    project: this.project,
                    mod: m,
                    serverMode: this._serverMode,
                    alternate: altCount % 2 == 0,
                ));
            }
        }
        return Scaffold(
            key: scaffoldKey,
            appBar: AppBar(
                backgroundColor: this._serverMode ? Colors.blue.shade100 : Colors.green.shade100,
                leading: IconButton(onPressed: this._openMenu, icon: const Icon(Icons.menu)),
                title: Text(widget.title),
                actions: [
                    const Text("Client"),
                    const SizedBox(width: 2),
                    Switch(
                        value: this._serverMode,
                        thumbIcon: this.thumbIcon,
                        activeColor: Colors.blue,
                        inactiveThumbColor: Colors.green,
                        trackOutlineColor: this.switchOutlineColor,
                        onChanged: (bool value) {
                            this.setState(() {
                                this._serverMode = value;
                            });
                        }
                    ),
                    const SizedBox(width: 2),
                    const Text("Server"),
                    const SizedBox(width: 20),
                    FilledButton(onPressed: () => this._copyOverrides(), child: const Text("Copy Overrides")),
                    const SizedBox(width: 10),
                    FilledButton(onPressed: () => this._downloadAll(this._serverMode), child: const Text("Download All")),
                    const SizedBox(width: 20),
                ],
            ),
            body: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 12,
                radius: Radius.zero,
                child: ListView(
                    controller: _scrollController,
                    children: mods
                ),
            ),
            drawer: NavigationDrawer(
                onDestinationSelected: handleMenuItemSelected,
                selectedIndex: null,
                children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(30, 20, 28, 10),
                        child: Text("Menu", style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(30, 0, 20, 10),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(this.project.name, style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold)),
                                Text("MC Version ${this.project.mcVersion}"),
                                Text("${this.project.loader.toTitleCase()} version ${this.project.loaderVersion}"),
                            ],
                        ),
                    ),
                    const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: Divider(),
                    ),
                    ...(() sync* {
                        for (var i in Iterable.generate(MenuItem.values.length)) {
                            if (i == menuDividerIdx) {
                                yield const Padding(
                                    padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                                    child: Divider(),
                                );
                            }
                            yield NavigationDrawerDestination(
                                label: Text(MenuItem.values[i].text),
                                icon: Icon(MenuItem.values[i].icon),
                            );
                        }
                    })()
                ]
            ),
        );
    }
}
