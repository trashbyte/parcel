import 'package:flutter/material.dart';
import 'package:parcel/mod.dart';

class ModRequirementWidget extends StatelessWidget {
    const ModRequirementWidget({super.key, required this.mod, required this.serverMode});

    final ModInfo mod;
    final bool serverMode;

    @override
    Widget build(BuildContext context) {
        return  SizedBox(
            width: 120,
            height: 24,
            child: Text(
                this.serverMode
                    ? this.mod.server.toString().toUpperCase()
                    : this.mod.client.toString().toUpperCase(),
                textAlign: TextAlign.center,
            ),
        );
    }
}