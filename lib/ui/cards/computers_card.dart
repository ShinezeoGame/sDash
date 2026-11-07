import 'package:flutter/material.dart';

import '../../models/home.dart';
import '../../state/home_controller.dart';
import '../../state/home_scope.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';

Color powerColor(PowerState state) => switch (state) {
      PowerState.on => Palette.sage,
      PowerState.starting || PowerState.stopping => Palette.amber,
      PowerState.off => Palette.taupe,
      PowerState.unknown => Palette.dusk,
    };

/// Allume ou éteint un ordinateur, avec confirmation avant l'extinction.
Future<void> toggleComputer(BuildContext context, HomeController home, ComputerDevice pc) async {
  if (pc.state.isBusy) return;
  if (pc.state != PowerState.on) {
    await home.setComputerPower(pc.id, true);
    return;
  }
  if (!pc.canShutdown) {
    home.post('Aucune commande d’extinction n’est configurée pour « ${pc.name} ».', isError: true);
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Éteindre « ${pc.name} » ?'),
      content: const Text('Les travaux non enregistrés sur cette machine pourraient être perdus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Éteindre')),
      ],
    ),
  );
  if (confirmed == true) await home.setComputerPower(pc.id, false);
}

/// Bouton d'alimentation : lumineux quand la machine est allumée, animé pendant le démarrage.
class PowerButton extends StatelessWidget {
  const PowerButton({super.key, required this.state, required this.onPressed, this.size = 48});

  final PowerState state;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GlassIconButton(
            icon: Icons.power_settings_new_rounded,
            size: size,
            active: state == PowerState.on,
            tooltip: state == PowerState.on ? 'Éteindre' : 'Allumer',
            onPressed: state.isBusy ? null : onPressed,
          ),
          if (state.isBusy)
            SizedBox(
              width: size + 6,
              height: size + 6,
              child: const CircularProgressIndicator(strokeWidth: 2.4, color: Palette.amber),
            ),
        ],
      ),
    );
  }
}

class ComputersCard extends StatelessWidget {
  const ComputersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final computers = home.state.computers;
    final onCount = computers.where((c) => c.state == PowerState.on).length;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeader(
            title: 'Ordinateurs',
            subtitle: computers.isEmpty ? 'Réveil à distance' : '$onCount allumé${onCount > 1 ? 's' : ''} sur ${computers.length}',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: computers.isEmpty
                ? EmptyHint(
                    icon: Icons.desktop_windows_rounded,
                    text: 'Aucun ordinateur configuré',
                    action: PillButton(
                      label: 'Ajouter',
                      icon: Icons.add_rounded,
                      compact: true,
                      onPressed: () => ShellNav.go(context, AppSection.settings),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: computers.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                    itemBuilder: (context, i) {
                      final pc = computers[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            IconOrb(
                              icon: pc.isServer ? Icons.dns_rounded : Icons.desktop_windows_rounded,
                              active: pc.state == PowerState.on,
                              color: Palette.honey,
                              size: 42,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pc.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.subtitle.copyWith(fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      StatusDot(color: powerColor(pc.state), size: 7),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          [pc.state.label, if (pc.detail != null) pc.detail!].join(' · '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.label,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            PowerButton(
                              state: pc.state,
                              size: 46,
                              onPressed: () => toggleComputer(context, home, pc),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
