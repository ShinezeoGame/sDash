import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

enum ButtonKind { primary, secondary }

/// Bouton texte. `primary` : action principale de l'écran ; `secondary` : action courante.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ButtonKind.secondary,
    this.compact = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonKind kind;
  final bool compact;

  /// Occupe toute la largeur disponible (à placer dans un `Expanded`).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null;
    final primary = kind == ButtonKind.primary;
    final fg = primary ? c.onAccent : c.text;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.button.copyWith(color: fg),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: primary ? c.accent : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dim.buttonRadius),
          side: primary ? BorderSide.none : BorderSide(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          child: Container(
            height: compact ? 44 : 52,
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
                if (expand) Flexible(child: text) else text,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton carré à icône (−, +, ▲, ■, ▼, marche/arrêt). Ambré quand [active].
class SquareButton extends StatelessWidget {
  const SquareButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 48,
    this.active = false,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Libellé de l'action, lu par les lecteurs d'écran et affiché en info-bulle.
  final String tooltip;
  final double size;
  final bool active;

  /// Affiche un indicateur d'attente et bloque les appuis.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !busy;
    final fg = active ? c.onActive : c.text;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: onPressed == null && !busy ? 0.4 : 1,
          child: SizedBox(
            width: size,
            height: size,
            child: Material(
              color: active ? c.active : c.surfaceMuted,
              borderRadius: BorderRadius.circular(Dim.buttonRadius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        onPressed!();
                      }
                    : null,
                child: Center(
                  child: busy
                      ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: fg))
                      : Icon(icon, size: math.min(size * 0.52, 30), color: fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Interrupteur.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged, this.enabled = true, this.label});

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 58,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                color: value ? c.accent : c.surfaceMuted,
                border: Border.all(color: value ? c.accent : c.border),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: value ? c.onAccent : c.textMuted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Curseur horizontal épais, facile à saisir au doigt. Valeur entre 0 et 1.
class AppSlider extends StatefulWidget {
  const AppSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeEnd,
    this.height = 44,
    this.enabled = true,
    this.icon,
    this.trackColor,
    this.fillColor,
    this.foregroundColor,
    this.semanticLabel,
  });

  final double value;

  /// Appelé à chaque déplacement du doigt.
  final ValueChanged<double>? onChanged;

  /// Appelé quand le doigt est relevé : c'est ici qu'on envoie la commande.
  final ValueChanged<double>? onChangeEnd;
  final double height;
  final bool enabled;
  final IconData? icon;
  final Color? trackColor;
  final Color? fillColor;

  /// Couleur de l'icône et de la poignée.
  final Color? foregroundColor;
  final String? semanticLabel;

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  double? _drag;

  double get _value => (_drag ?? widget.value).clamp(0.0, 1.0);

  void _update(Offset local, double width) {
    final v = (local.dx / width).clamp(0.0, 1.0);
    setState(() => _drag = v);
    widget.onChanged?.call(v);
  }

  void _end() {
    final v = _value;
    setState(() => _drag = null);
    widget.onChangeEnd?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = widget.height;
    final fg = widget.foregroundColor ?? c.onAccent;
    final active = widget.enabled;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Largeur minimale : la poignée reste visible et saisissable à 0 %.
        final fill = math.max(h * 0.8, width * _value);
        final duration = _drag == null ? const Duration(milliseconds: 160) : Duration.zero;
        return Semantics(
          slider: true,
          enabled: active,
          label: widget.semanticLabel,
          value: '${(_value * 100).round()} %',
          child: Opacity(
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
              onHorizontalDragCancel: active ? () => setState(() => _drag = null) : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: h,
                  child: Stack(
                    children: [
                      Positioned.fill(child: ColoredBox(color: widget.trackColor ?? c.surfaceMuted)),
                      AnimatedContainer(
                        duration: duration,
                        curve: Curves.easeOut,
                        width: fill,
                        height: h,
                        color: widget.fillColor ?? c.accent,
                      ),
                      if (widget.icon != null)
                        Positioned(left: 10, top: 0, bottom: 0, child: Icon(widget.icon, size: 18, color: fg)),
                      AnimatedPositioned(
                        duration: duration,
                        curve: Curves.easeOut,
                        left: fill - 10,
                        top: h * 0.25,
                        child: Container(
                          width: 4,
                          height: h * 0.5,
                          decoration: BoxDecoration(color: fg, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Choix exclusif : une rangée de segments égaux, le segment choisi est rempli.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.iconOf,
    this.height = 52,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final IconData Function(T value)? iconOf;
  final ValueChanged<T> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(Dim.buttonRadius)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Les icônes s'effacent quand la place manque : le libellé prime.
          final showIcons = iconOf != null && constraints.maxWidth / values.length >= 108;
          return Row(
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
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: v == selected ? c.accent : c.accent.withValues(alpha: 0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showIcons) ...[
                                Icon(iconOf!(v), size: 18, color: v == selected ? c.onAccent : c.textMuted),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                labelOf(v),
                                maxLines: 1,
                                style: t.button.copyWith(fontSize: 15, color: v == selected ? c.onAccent : c.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Réglage par paliers : bouton −, valeur, bouton +.
class StepperControl extends StatelessWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.buttonSize = 44,
    this.valueWidth = 72,
    this.valueStyle,
    this.minusTooltip = 'Baisser',
    this.plusTooltip = 'Augmenter',
  });

  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final double buttonSize;
  final double valueWidth;
  final TextStyle? valueStyle;
  final String minusTooltip;
  final String plusTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SquareButton(icon: Icons.remove_rounded, tooltip: minusTooltip, size: buttonSize, onPressed: onMinus),
        SizedBox(
          width: valueWidth,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, maxLines: 1, style: valueStyle ?? context.text.number),
            ),
          ),
        ),
        SquareButton(icon: Icons.add_rounded, tooltip: plusTooltip, size: buttonSize, onPressed: onPlus),
      ],
    );
  }
}
