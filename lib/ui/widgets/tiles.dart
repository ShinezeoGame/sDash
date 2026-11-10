import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Surface de base de l'interface : fond uni, bord fin, coins arrondis.
/// Devient ambrée quand [active] est vrai (appareil allumé).
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.child,
    this.onTap,
    this.active = false,
    this.padding = const EdgeInsets.all(14),
    this.radius = Dim.tileRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: active ? c.active : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: active ? c.active : c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum BadgeTone {
  /// Sur une tuile neutre.
  neutral,

  /// Sur une tuile allumée (ambrée).
  onActive,

  /// Pastille ambrée sur une tuile neutre (ex. ordinateur allumé).
  highlight,
}

/// Pastille ronde contenant l'icône d'un appareil ou d'une pièce.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.tone = BadgeTone.neutral, this.size = 40});

  final IconData icon;
  final BadgeTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (background, foreground) = switch (tone) {
      BadgeTone.neutral => (c.surfaceMuted, c.textMuted),
      BadgeTone.onActive => (c.onActive.withValues(alpha: 0.12), c.onActive),
      BadgeTone.highlight => (c.active, c.onActive),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.52, color: foreground),
    );
  }
}

/// Tuile d'un appareil allumable : un appui bascule l'état.
/// Ambrée quand l'appareil est allumé, neutre sinon — l'état se lit de loin.
class ToggleTile extends StatelessWidget {
  const ToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    required this.on,
    required this.onTap,
    this.available = true,
    this.vertical = false,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool on;
  final VoidCallback onTap;

  /// Faux quand l'appareil ne répond pas : la tuile est estompée et inactive.
  final bool available;

  /// Disposition compacte (icône au-dessus du texte) pour les tuiles étroites.
  final bool vertical;

  /// Contenu supplémentaire sous l'en-tête (ex. curseur de luminosité).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final badge = IconBadge(icon: icon, tone: on ? BadgeTone.onActive : BadgeTone.neutral, size: vertical ? 34 : 40);
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.itemTitle.copyWith(color: on ? c.onActive : c.text),
    );
    final statusText = Text(
      status,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.secondary.copyWith(color: on ? c.onActive.withValues(alpha: 0.78) : c.textMuted),
    );

    final Widget content;
    if (vertical) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [badge, const Spacer(), titleText, statusText],
      );
    } else {
      final header = Row(
        children: [
          badge,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [titleText, statusText],
            ),
          ),
        ],
      );
      content = footer == null
          ? header
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const Spacer(), footer!]);
    }

    return Semantics(
      toggled: on,
      enabled: available,
      child: Opacity(
        opacity: available ? 1 : 0.5,
        child: Tile(
          active: on,
          onTap: available ? onTap : null,
          padding: EdgeInsets.all(vertical ? 12 : 14),
          child: content,
        ),
      ),
    );
  }
}

/// En-tête de section : titre, précision, lien vers la page détaillée et action éventuelle.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.detail, this.icon, this.onOpen, this.trailing});

  final String title;

  /// Précision affichée après le titre (« 4 allumées »).
  final String? detail;
  final IconData? icon;

  /// Ouvre la page détaillée ; un chevron l'indique.
  final VoidCallback? onOpen;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    // Le titre prime : il garde toute la place nécessaire, la précision se réduit en premier.
    Widget label = LayoutBuilder(
      builder: (context, constraints) {
        final reserved = (icon != null ? 32.0 : 0.0) + (onOpen != null ? 28.0 : 0.0);
        final titleWidth = (constraints.maxWidth - reserved).clamp(40.0, double.infinity);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 22, color: c.textMuted), const SizedBox(width: 10)],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: titleWidth),
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.sectionTitle),
            ),
            if (detail != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Text(detail!, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: t.secondary),
                ),
              ),
            if (onOpen != null) Icon(Icons.chevron_right_rounded, size: 24, color: c.textFaint),
          ],
        );
      },
    );
    if (onOpen != null) {
      label = Semantics(
        button: true,
        label: 'Ouvrir $title',
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(10),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2), child: label),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: label),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Point d'état coloré.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// Information en lecture seule dans l'en-tête (« Extérieur 8,5° »).
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.value, this.icon, this.color, this.onTap});

  final String label;
  final String? value;
  final IconData? icon;

  /// Couleur d'alerte (bord, icône et texte) ; neutre si absente.
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dim.buttonRadius),
        side: BorderSide(color: color ?? c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20, color: color ?? c.textMuted), const SizedBox(width: 8)],
              Text(label, maxLines: 1, style: t.secondary.copyWith(color: color ?? c.textMuted)),
              if (value != null) ...[
                const SizedBox(width: 6),
                Text(value!, maxLines: 1, style: t.button.copyWith(color: color ?? c.text)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Message affiché quand il n'y a rien à montrer.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tile(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: c.textFaint),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: context.text.secondary),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
