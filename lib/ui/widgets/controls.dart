import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../look.dart';
import 'surface.dart';

/// Interrupteur lumineux : rail ambré qui « s'allume » quand il est activé.
class GlowToggle extends StatelessWidget {
  const GlowToggle({super.key, required this.value, required this.onChanged, this.enabled = true});

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final look = AppLook.of(context);
    final BoxDecoration track;
    if (value) {
      track = look.active(radius: 20, glow: 0.8);
    } else if (look.leather) {
      track = BoxDecoration(borderRadius: BorderRadius.circular(20));
    } else {
      track = BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.09),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      );
    }
    // Style cuir : bouton en laiton, comme un rivet de maroquinerie.
    final thumb = look.leather
        ? BoxDecoration(
            shape: BoxShape.circle,
            gradient: Palette.brass,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          )
        : BoxDecoration(
            shape: BoxShape.circle,
            color: value ? Palette.cream : Palette.taupe,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          );
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: CustomPaint(
              painter: !value && look.leather ? look.surface(radius: 16, relief: Relief.sunken, grain: false) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: 54,
                height: 32,
                padding: const EdgeInsets.all(4),
                decoration: track,
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(width: 22, height: 22, decoration: thumb),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Curseur en forme de gélule dont la partie remplie est un dégradé miel → cognac.
class WarmSlider extends StatefulWidget {
  const WarmSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeEnd,
    this.height = 40,
    this.label,
    this.enabled = true,
    this.icon,
  });

  /// Valeur entre 0 et 1.
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double height;

  /// Texte affiché dans la partie remplie (par défaut le pourcentage).
  final String Function(double value)? label;
  final bool enabled;
  final IconData? icon;

  @override
  State<WarmSlider> createState() => _WarmSliderState();
}

class _WarmSliderState extends State<WarmSlider> {
  double? _dragValue;

  double get _value => (_dragValue ?? widget.value).clamp(0.0, 1.0);

  void _update(Offset local, double width) {
    final v = (local.dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = v);
    widget.onChanged?.call(v);
  }

  void _end() {
    final v = _value;
    setState(() => _dragValue = null);
    widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label ?? (v) => '${(v * 100).round()} %';
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final h = widget.height;
        final fill = h + (_value * (width - h));
        final active = widget.enabled;
        final look = AppLook.of(context);
        return Opacity(
          opacity: active ? 1 : 0.45,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: active
                ? (d) {
                    _update(d.localPosition, width);
                    _end();
                  }
                : null,
            onHorizontalDragStart: active ? (d) => _update(d.localPosition, width) : null,
            onHorizontalDragUpdate: active ? (d) => _update(d.localPosition, width) : null,
            onHorizontalDragEnd: active ? (_) => _end() : null,
            onHorizontalDragCancel: active ? () => setState(() => _dragValue = null) : null,
            child: SizedBox(
              height: h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: look.surface(radius: h / 2, relief: Relief.sunken, grain: look.leather),
                      child: look.leather
                          ? null
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(h / 2),
                              ),
                            ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: _dragValue == null ? const Duration(milliseconds: 220) : Duration.zero,
                    curve: Curves.easeOutCubic,
                    width: fill,
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(h / 2),
                      // Style cuir : sangle de cuir fauve ; style verre : dégradé lumineux.
                      gradient: look.leather
                          ? const LinearGradient(colors: [Color(0xFF9A5A2A), Color(0xFFC88A4E), Color(0xFFE6B27A)])
                          : const LinearGradient(colors: [Palette.cognac, Palette.amber, Palette.honey]),
                      border: look.leather ? Border.all(color: const Color(0xFFFFE4BE).withValues(alpha: 0.35)) : null,
                      boxShadow: [
                        look.leather
                            ? BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            : BoxShadow(color: Palette.ember.withValues(alpha: 0.30), blurRadius: 14, spreadRadius: -4),
                      ],
                    ),
                    foregroundDecoration: look.leather ? const _StrapStitchDecoration() : null,
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(left: h * 0.42),
                    child: fill > h * 2.2
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon, size: h * 0.42, color: Palette.onWarm),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                label(_value),
                                maxLines: 1,
                                style: AppText.label.copyWith(color: Palette.onWarm, fontWeight: FontWeight.w600),
                              ),
                            ],
                          )
                        : null,
                  ),
                  // Poignée discrète au bout de la partie remplie.
                  AnimatedPositioned(
                    duration: _dragValue == null ? const Duration(milliseconds: 220) : Duration.zero,
                    curve: Curves.easeOutCubic,
                    left: fill - h * 0.32,
                    top: h * 0.28,
                    child: Container(
                      width: 3,
                      height: h * 0.44,
                      decoration: BoxDecoration(
                        color: Palette.cream.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Surpiqûre le long de la sangle d'un curseur (style cuir).
class _StrapStitchDecoration extends Decoration {
  const _StrapStitchDecoration();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _StrapStitchPainter();
}

class _StrapStitchPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.width < size.height * 1.4) return;
    final inset = size.height * 0.2;
    final rrect = RRect.fromRectAndRadius((offset & size).deflate(inset), Radius.circular(size.height / 2 - inset));
    final path = Path()..addRRect(rrect);
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFF0D8).withValues(alpha: 0.55);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4.5), thread);
        d += 8;
      }
    }
  }
}

/// Bouton rond (icône) : cuir embossé ou verre, avec un état actif.
class SurfaceIconButton extends StatelessWidget {
  const SurfaceIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 46,
    this.active = false,
    this.tooltip,
    this.iconSize,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool active;
  final String? tooltip;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final look = AppLook.of(context);
    final enabled = onPressed != null;
    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onPressed!();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: size,
          height: size,
          decoration: active
              ? look.active(shape: BoxShape.circle)
              : BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: look.leather
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
          child: CustomPaint(
            painter: active ? null : look.surface(radius: size / 2, strength: 0.9, grain: look.leather),
            child: Icon(icon, size: iconSize ?? size * 0.46, color: active ? Palette.onWarm : Palette.cream),
          ),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return Semantics(button: true, label: tooltip, child: button);
  }
}

/// Bouton texte en gélule (action secondaire ou principale).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: SurfacePill(
        selected: primary,
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Choix exclusif sous forme de pastilles (ex. modes de chauffage).
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
    this.compact = false,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final IconData Function(T value)? iconOf;
  final ValueChanged<T> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          SurfacePill(
            selected: v == selected,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(v);
            },
            padding: compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconOf != null) ...[Icon(iconOf!(v), size: 16), const SizedBox(width: 6)],
                Text(labelOf(v)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Contrôle segmenté : une gélule de verre partagée en segments égaux.
/// Les icônes disparaissent automatiquement quand la place manque.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
    this.height = 40,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final IconData Function(T value)? iconOf;
  final ValueChanged<T> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final look = AppLook.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final perSegment = constraints.maxWidth / values.length;
        final showIcons = iconOf != null && perSegment >= 100;
        return CustomPaint(
          painter: look.surface(radius: 100, relief: Relief.sunken, strength: 0.7, grain: look.leather),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (final v in values)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: v == selected,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelected(v);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          height: height - 8,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: v == selected
                              ? look.active(radius: 100, glow: 0.8)
                              : BoxDecoration(borderRadius: BorderRadius.circular(100)),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showIcons) ...[
                                  Icon(iconOf!(v), size: 16, color: v == selected ? Palette.onWarm : Palette.sand),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  labelOf(v),
                                  maxLines: 1,
                                  style: AppText.label.copyWith(
                                    fontSize: 14,
                                    color: v == selected ? Palette.onWarm : Palette.sand,
                                    fontWeight: v == selected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
