import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'glass.dart';

/// Interrupteur lumineux : rail ambré qui « s'allume » quand il est activé.
class GlowToggle extends StatelessWidget {
  const GlowToggle({super.key, required this.value, required this.onChanged, this.enabled = true});

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: 54,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: value ? Palette.warm : null,
                color: value ? null : Colors.white.withValues(alpha: 0.09),
                border: Border.all(
                  color: value ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.12),
                ),
                boxShadow: value
                    ? [BoxShadow(color: Palette.ember.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: -2)]
                    : const [],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? Palette.cream : Palette.taupe,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
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
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final h = widget.height;
      final fill = h + (_value * (width - h));
      final active = widget.enabled;
      final reduced = GlassSettings.reducedOf(context);
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
                    painter: GlassPainter(radius: h / 2, reduced: reduced, grain: false, strength: 0.6),
                    child: DecoratedBox(
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
                    gradient: const LinearGradient(colors: [Palette.cognac, Palette.amber, Palette.honey]),
                    boxShadow: [
                      BoxShadow(color: Palette.ember.withValues(alpha: 0.30), blurRadius: 14, spreadRadius: -4),
                    ],
                  ),
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
    });
  }
}

/// Bouton rond en verre (icône), avec un état actif lumineux.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
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
    final reduced = GlassSettings.reducedOf(context);
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
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Palette.warm,
                  boxShadow: [BoxShadow(color: Palette.ember.withValues(alpha: 0.45), blurRadius: 18)],
                )
              : const BoxDecoration(shape: BoxShape.circle),
          child: CustomPaint(
            painter: active ? null : GlassPainter(radius: size / 2, reduced: reduced, grain: false, strength: 0.9),
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
      child: GlassPill(
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
          GlassPill(
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
