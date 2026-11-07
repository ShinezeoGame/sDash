import 'package:flutter/material.dart';

import '../theme.dart';

/// En-tête de carte : titre, sous-titre et actions éventuelles.
class CardHeader extends StatelessWidget {
  const CardHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// Pastille ronde contenant une icône, colorée quand l'appareil est actif.
class IconOrb extends StatelessWidget {
  const IconOrb({super.key, required this.icon, this.active = false, this.size = 44, this.color});

  final IconData icon;
  final bool active;
  final double size;

  /// Couleur d'accent (miel par défaut).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Palette.honey;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(accent, Colors.white, 0.25)!, accent],
              )
            : null,
        color: active ? null : Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: active ? 0.35 : 0.10)),
        boxShadow: active ? [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: -2)] : null,
      ),
      child: Icon(icon, size: size * 0.48, color: active ? Palette.onWarm : Palette.sand),
    );
  }
}

/// Petit point d'état lumineux.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8, this.glow = true});

  final Color color;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: size)] : null,
      ),
    );
  }
}

/// Étiquette colorée façon « badge ».
class Tag extends StatelessWidget {
  const Tag({super.key, required this.text, this.color = Palette.honey, this.filled = false});

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: filled ? 0 : 0.35)),
      ),
      child: Text(
        text,
        style: AppText.label.copyWith(color: filled ? Palette.onWarm : color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Titre de section dans les pages détaillées.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text, this.icon, this.trailing});

  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: Palette.amber), const SizedBox(width: 10)],
          Expanded(child: Text(text, style: AppText.subtitle.copyWith(fontSize: 19))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Message affiché quand une liste est vide.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: Palette.taupe),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: AppText.body.copyWith(color: Palette.taupe)),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}
