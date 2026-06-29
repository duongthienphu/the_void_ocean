import 'package:flutter/material.dart';
import 'package:ocean/features/gameplay/map_mobile.dart';
import 'package:ocean/features/gameplay/map_web.dart';

class GameWrapper extends StatelessWidget {
  const GameWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return const OceanWebScreen();
        }

        return const OceanMobileScreen();
      },
    );
  }
}
