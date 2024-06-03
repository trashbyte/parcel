import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parcel/mod.dart';
import 'package:parcel/project.dart';
import 'package:parcel/sources/source.dart';
import 'package:parcel/widgets/mod_requirement.dart';
import 'package:parcel/widgets/mod_source_button.dart';
import 'package:parcel/widgets/mod_status.dart';


class ModListEntry extends StatefulWidget {
    const ModListEntry({super.key, required this.project, required this.mod, required this.serverMode, required this.alternate});
  
    final ProjectData project;
    final ModInfo mod;
    final bool serverMode;
    final bool alternate;
    
    @override
    State<StatefulWidget> createState() => ModListEntryState();
}

class ModListEntryState extends State<ModListEntry> {
    void _download() async {
        if (this.widget.mod.source.status == SourceStatus.unknown) {
            await this.widget.mod.fetch();
        }
        var c = Completer();
        this.widget.mod.download((progress) async {
            if (progress == 1.0) {
                await this.widget.mod.fetch();
                if (!c.isCompleted) {
                    c.complete();
                }
            }
            this.setState(() {});
        });
        return c.future;
    }

    void _deleteFile() async {
        await this.widget.mod.delete();
        this.setState(() {});
    }

    @override
    Widget build(BuildContext context) {
        var progressVisible = this.widget.mod.source.downloadProgress > 0.0
            && this.widget.mod.source.downloadProgress < 1.0;
        var status = this.widget.mod.source.status;
        bool optionalToRemove = (status == SourceStatus.behindSource || status == SourceStatus.current)
            && (
                (this.widget.serverMode && this.widget.mod.server == SideUsage.optional)
                || (!this.widget.serverMode && this.widget.mod.client == SideUsage.optional)
            );
        return Container(
            color: this.widget.alternate ? const Color.fromARGB(6, 0, 0, 0) : Colors.transparent,
            padding: const EdgeInsets.all(4),
            child: Row(
                children: [
                    ModSourceIconButton(source: this.widget.mod.source),
                    const SizedBox(width: 5),
                    SizedBox(
                        width: 36,
                        height: 36,
                        child: this.widget.mod.source.thumbnailURL != null
                            ? Image.network(this.widget.mod.source.thumbnailURL!)
                            : null,
                    ),
                    const SizedBox(width: 5),
                    Expanded(child: Column(children: [
                        Row(children: [
                            Expanded(child: Text(this.widget.mod.name, style: Theme.of(context).textTheme.bodyLarge)),
                            Text(this.widget.mod.note ?? ""),
                            const SizedBox(width: 20),
                            SizedBox(
                                width: 130,
                                child: ModStatusWidget(status, this.widget.mod.isOptionalFor(this.widget.serverMode)),
                            ),
                        ]),
                        Visibility(
                            visible: progressVisible,
                            child: LinearProgressIndicator(
                                value: this.widget.mod.source.downloadProgress,
                            ),
                        ),
                    ])),
                    ModRequirementWidget(mod: this.widget.mod, serverMode: this.widget.serverMode),
                    SizedBox(
                        width: 140,
                        child:
                            optionalToRemove
                                ? FilledButton.tonal(
                                    onPressed: () => this._deleteFile(),
                                    style: ButtonStyle(backgroundColor: WidgetStateProperty.resolveWith((_) => Colors.pink.shade100)),
                                    child: const Text("Remove"),
                                )
                                : FilledButton.tonal(
                                    onPressed: (
                                        status == SourceStatus.current
                                        || status == SourceStatus.behindSource
                                        || status == SourceStatus.downloading
                                    )
                                        ? null
                                        : () => this._download(),
                                    child: Text(switch (status) {
                                        SourceStatus.unknown => "Download",
                                        SourceStatus.missing => "Download",
                                        SourceStatus.behindPack => "Update",
                                        SourceStatus.behindSource => "Up to date",
                                        SourceStatus.current => "Up to date",
                                        SourceStatus.downloading => "Downloading",
                                        SourceStatus.noInfo => "Download",
                                    })
                                )
                    ),
                    const SizedBox(width: 20),
                ],
            ),
        );
    }
}