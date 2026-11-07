import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/home.dart';
import '../../state/home_scope.dart';
import '../icons.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';

/// Grille de scènes (ambiances) activables d'un geste.
class ScenesGrid extends StatefulWidget {
  const ScenesGrid({super.key, required this.scenes, this.minTileWidth = 150, this.maxRows});

  final List<SceneItem> scenes;
  final double minTileWidth;

  /// Nombre de lignes à faire tenir dans la hauteur disponible (carte du tableau de bord).
  final int? maxRows;

  @override
  State<ScenesGrid> createState() => _ScenesGridState();
}

class _ScenesGridState extends State<ScenesGrid> {
  String? _flash;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _activate(SceneItem scene) {
    HapticFeedback.mediumImpact();
    HomeScope.read(context).activateScene(scene.id);
    setState(() => _flash = scene.id);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 10.0;
      final columns = math.max(1, ((constraints.maxWidth + gap) / (widget.minTileWidth + gap)).floor());
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      final rows = (widget.scenes.length / columns).ceil();
      final double tileHeight = widget.maxRows != null && constraints.hasBoundedHeight
          ? ((constraints.maxHeight - gap * (math.min(rows, widget.maxRows!) - 1)) / math.min(rows, widget.maxRows!))
              .clamp(48.0, 84.0)
          : 64.0;
      return SingleChildScrollView(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final scene in widget.scenes)
              SizedBox(
                width: width,
                height: tileHeight,
                child: _SceneTile(scene: scene, active: _flash == scene.id, onTap: () => _activate(scene)),
              ),
          ],
        ),
      );
    });
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({required this.scene, required this.active, required this.onTap});

  final SceneItem scene;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduced = GlassSettings.reducedOf(context);
    return Semantics(
      button: true,
      label: 'Activer la scène ${scene.name}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: active ? Palette.warm : null,
            boxShadow: active ? [BoxShadow(color: Palette.ember.withValues(alpha: 0.45), blurRadius: 20)] : null,
          ),
          child: CustomPaint(
            painter: active ? null : GlassPainter(radius: 20, reduced: reduced, grain: false, strength: 0.8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(sceneIcon(scene.kind), size: 22, color: active ? Palette.onWarm : Palette.honey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      scene.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(
                        fontSize: 14,
                        color: active ? Palette.onWarm : Palette.cream,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScenesCard extends StatelessWidget {
  const ScenesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scenes = HomeScope.of(context).state.scenes;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardHeader(title: 'Scènes', subtitle: 'Une ambiance en un geste'),
          const SizedBox(height: 14),
          Expanded(
            child: scenes.isEmpty
                ? const EmptyHint(icon: Icons.auto_awesome_rounded, text: 'Aucune scène disponible')
                : ScenesGrid(scenes: scenes, minTileWidth: 120, maxRows: 2),
          ),
        ],
      ),
    );
  }
}
