import 'package:flutter/material.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:parcel/sources/source.dart';
import 'package:url_launcher/url_launcher.dart';


class ModSourceIconButton extends StatelessWidget {
    const ModSourceIconButton({super.key, required this.source});
  
    final ModSource source;

    WidgetStateProperty<MouseCursor> _getMouseCursor() {
        if (this.source.modURL() == null) {
            return WidgetStateProperty.all(SystemMouseCursors.forbidden);
        }
        else {
            return WidgetStateProperty.all(SystemMouseCursors.click);
        }
    }
    
    void Function()? _getOnPressed() {
        if (this.source.modURL() == null) {
            return null;
        }
        else {
            return () {
                launchUrl(Uri.parse(this.source.modURL()!));
            };
        }
    }

    @override
    Widget build(BuildContext context) {
        return SizedBox(
            width: 36,
            height: 36,
            child: JustTheTooltip(
                preferredDirection: AxisDirection.left,
                waitDuration: const Duration(seconds: 1),
                fadeOutDuration: Duration.zero,
                tailLength: 0,
                offset: -10,
                backgroundColor: Colors.grey.shade800,
                content: const Padding(padding: EdgeInsets.all(8), child: Text("Open mod page", style: TextStyle(color: Colors.white))),
                child: IconButton(
                    padding: const EdgeInsets.all(2),
                    style: ButtonStyle(mouseCursor: this._getMouseCursor()),
                    onPressed: this._getOnPressed(),
                    icon: Image.asset(this.source.iconPath()),
                )
            )
        );
    }
}