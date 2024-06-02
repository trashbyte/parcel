import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_platform_alert/flutter_platform_alert.dart';
import 'package:path/path.dart' as path;

class Result<T, E> {
    const Result(this.value, this.error);

    const Result.ok(T value) : this(value, null);
    const Result.err(E err) : this(null, err);

    final T? value;
    final E? error;

    bool get isOk => this.value != null;
    bool get isErr => this.error != null;

    T unwrap() {
        if (this.isOk) { return this.value!; }
        throw "Called unwrap() on a Result.err: ${this.error!.toString()}";
    }

    E unwrapErr() {
        if (this.isErr) { return this.error!; }
        throw "Called unwrapErr() on a Result.ok: ${this.value!.toString()}";
    }
}

String executableDir() {
    var exePath = Platform.resolvedExecutable;
    return path.dirname(exePath);
}

String cacheDir() {
    var dir = "${executableDir()}/cache";
    Directory(dir).createSync(recursive: true);
    return dir;
}

bool localDefExists(String projectDir) {
    var localDefPath = "$projectDir/local.txt";
    return File(localDefPath).existsSync();
}

void writeLocalDef(String projectDir, String instanceDir) {
    var localDefPath = "$projectDir/local.txt";
    File(localDefPath).writeAsStringSync(instanceDir);
}

String localInstanceDir(String projectDir) {
    var localDefPath = "$projectDir/local.txt";
    var f = File(localDefPath);
    if (!f.existsSync()) {
        throw "$localDefPath missing. Project folder needs a 'local.txt' containing a path to a local Minecraft instance";
    }
    var targetPath = f.readAsStringSync();
    var instance = Directory(targetPath);
    if (!instance.existsSync()) {
        throw "Local instance path $targetPath does not exist.";
    }
    if (path.basename(targetPath) != ".minecraft") {
        throw "Local instance path $targetPath doesn't appear to be a Minecraft instance.";
    }
    return targetPath;
}

Future<void> showSimpleDialog(String title, String msg, bool isError) async {
    await FlutterPlatformAlert.showAlert(
        windowTitle: title,
        text: msg,
        alertStyle: AlertButtonStyle.ok,
        iconStyle: isError ? IconStyle.error : IconStyle.information,
    );
}


Future<bool> showConfirmDialog(String title, String msg) async {
    return (await FlutterPlatformAlert.showAlert(
        windowTitle: title,
        text: msg,
        alertStyle: AlertButtonStyle.yesNo,
        iconStyle: IconStyle.warning,
        options: PlatformAlertOptions(windows: WindowsAlertOptions(additionalWindowTitle: title))
    )) == AlertButton.yesButton;
}

extension MoreCases on String {
  String toTitleCase() {
    var buf = StringBuffer();
    var wordStart = true;
    for (var c in this.characters) {
        if (wordStart) {
            buf.write(c.toUpperCase());
            wordStart = false;
        }
        else {
            if (c == ' ') {
                wordStart = true;
            }
            buf.write(c.toLowerCase());
        }
    }
    return buf.toString();
  }
}