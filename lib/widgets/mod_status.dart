import 'package:flutter/material.dart';
import 'package:parcel/sources/source.dart';

class ModStatusWidget extends StatelessWidget {
    const ModStatusWidget(this.status, this.optional, {super.key});

    final SourceStatus status;
    final bool optional;

    String _iconPath() {
        switch (this.status) {
            case SourceStatus.unknown:
                return 'assets/icons/unknown.png';
            case SourceStatus.missing:
                return optional ? 'assets/icons/optional-rejected.png' : 'assets/icons/missing.png';
            case SourceStatus.behindPack:
                return 'assets/icons/behind-pack.png';
            case SourceStatus.behindSource:
                return 'assets/icons/behind-source.png';
            case SourceStatus.current:
                return 'assets/icons/current.png';
            case SourceStatus.downloading:
                return 'assets/icons/downloading.png';
            case SourceStatus.noInfo:
                return 'assets/icons/unknown.png';
        }
    }
  
  @override
  Widget build(BuildContext context) {
    return Row(
        children: [
            Expanded(child: Container()),
            Image(image: AssetImage(this._iconPath())),
            const SizedBox(width: 4),
            Text((this.optional && this.status == SourceStatus.missing)
                ? "Ignored"
                : this.status.toString()),
            Expanded(child: Container()),
        ]
    );
  }
}