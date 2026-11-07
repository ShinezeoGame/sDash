import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../cards/climate_card.dart';
import '../cards/computers_card.dart';
import '../cards/covers_card.dart';
import '../cards/energy_card.dart';
import '../cards/lights_card.dart';
import '../cards/scenes_card.dart';

/// Tableau de bord : tout tient sur un écran de tablette en paysage,
/// et se réorganise en colonnes défilantes sur les écrans plus étroits.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const gap = 18.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= 1000) {
          final height = math.max(constraints.maxHeight, 600.0);
          final grid = SizedBox(
            height: height,
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      Expanded(flex: 62, child: ClimateCard()),
                      SizedBox(height: gap),
                      Expanded(flex: 38, child: ScenesCard()),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      Expanded(flex: 58, child: LightsCard()),
                      SizedBox(height: gap),
                      Expanded(flex: 42, child: CoversCard()),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  flex: 8,
                  child: Column(
                    children: [
                      Expanded(flex: 44, child: ComputersCard()),
                      SizedBox(height: gap),
                      Expanded(flex: 56, child: EnergyCard()),
                    ],
                  ),
                ),
              ],
            ),
          );
          return height > constraints.maxHeight ? SingleChildScrollView(child: grid) : grid;
        }

        if (width >= 640) {
          return const SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: 440, child: ClimateCard()),
                      SizedBox(height: gap),
                      SizedBox(height: 250, child: ScenesCard()),
                      SizedBox(height: gap),
                      SizedBox(height: 320, child: EnergyCard()),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(height: 420, child: LightsCard()),
                      SizedBox(height: gap),
                      SizedBox(height: 280, child: CoversCard()),
                      SizedBox(height: gap),
                      SizedBox(height: 310, child: ComputersCard()),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          children: const [
            SizedBox(height: 430, child: ClimateCard()),
            SizedBox(height: gap),
            SizedBox(height: 400, child: LightsCard()),
            SizedBox(height: gap),
            SizedBox(height: 270, child: CoversCard()),
            SizedBox(height: gap),
            SizedBox(height: 300, child: ScenesCard()),
            SizedBox(height: gap),
            SizedBox(height: 280, child: ComputersCard()),
            SizedBox(height: gap),
            SizedBox(height: 320, child: EnergyCard()),
          ],
        );
      },
    );
  }
}
