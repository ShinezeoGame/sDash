import 'package:flutter/material.dart';

import '../../data/home_backend.dart';
import '../../data/network/wake_on_lan.dart';
import '../../data/settings.dart';
import '../../state/home_scope.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/tiles.dart';
import 'page_scaffold.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _token;
  late final TextEditingController _energy;
  late BackendKind _backend;
  bool _showToken = false;

  @override
  void initState() {
    super.initState();
    final s = HomeScope.read(context).settings;
    _name = TextEditingController(text: s.userName)..addListener(_refresh);
    _url = TextEditingController(text: s.haUrl)..addListener(_refresh);
    _token = TextEditingController(text: s.haToken)..addListener(_refresh);
    _energy = TextEditingController(text: s.energySensor)..addListener(_refresh);
    _backend = s.backend;
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _url, _token, _energy]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Vrai si les champs de saisie diffèrent des réglages enregistrés.
  bool _isDirty(AppSettings s) =>
      _name.text.trim() != s.userName ||
      _url.text.trim() != s.haUrl ||
      _token.text.trim() != s.haToken ||
      _energy.text.trim() != s.energySensor ||
      _backend != s.backend;

  Future<void> _save() async {
    final home = HomeScope.read(context);
    if (_backend == BackendKind.homeAssistant && (_url.text.trim().isEmpty || _token.text.trim().isEmpty)) {
      home.post('Renseignez l’adresse et le jeton de Home Assistant.', isError: true);
      return;
    }
    await home.updateSettings(
      home.settings.copyWith(
        userName: _name.text.trim(),
        backend: _backend,
        haUrl: _url.text.trim(),
        haToken: _token.text.trim(),
        energySensor: _energy.text.trim(),
      ),
    );
    home.post('Réglages enregistrés');
  }

  Future<void> _editComputer(ComputerConfig? initial) async {
    final home = HomeScope.read(context);
    final result = await showDialog<ComputerConfig>(
      context: context,
      builder: (_) => _ComputerDialog(initial: initial),
    );
    if (result == null) return;
    final list = [...home.settings.computers];
    final index = list.indexWhere((c) => c.id == result.id);
    if (index >= 0) {
      list[index] = result;
    } else {
      list.add(result);
    }
    await home.updateSettings(home.settings.copyWith(computers: list));
    home.post('« ${result.name} » enregistré');
  }

  Future<void> _deleteComputer(ComputerConfig config) async {
    final home = HomeScope.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${config.name} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed != true) return;
    await home.updateSettings(
      home.settings.copyWith(computers: home.settings.computers.where((c) => c.id != config.id).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = HomeScope.of(context);
    final settings = home.settings;
    final c = context.colors;
    final t = context.text;
    final dirty = _isDirty(settings);
    final link = home.link;
    final linkText =
        link.message ??
        switch (link.state) {
          LinkState.online => 'connecté',
          LinkState.connecting => 'connexion…',
          LinkState.offline => 'hors ligne',
        };

    return AppPage(
      title: 'Réglages',
      subtitle: dirty ? 'Modifications non enregistrées' : 'Connexion, ordinateurs et affichage',
      maxWidth: 860,
      actions: [
        AppButton(
          label: 'Enregistrer',
          icon: Icons.check_rounded,
          kind: ButtonKind.primary,
          onPressed: dirty ? _save : null,
        ),
      ],
      children: [
        _Panel(
          title: 'Connexion domotique',
          icon: Icons.hub_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Segmented<BackendKind>(
                    values: BackendKind.values,
                    selected: _backend,
                    labelOf: (b) => b == BackendKind.demo ? 'Maison de démo' : 'Home Assistant',
                    onSelected: (b) => setState(() => _backend = b),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_backend == BackendKind.demo)
                Text(
                  'Le mode démo simule une maison complète (lumières, chauffage, volets, ordinateurs) '
                  'pour découvrir sDash sans rien configurer.',
                  style: t.secondary,
                )
              else ...[
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Adresse de Home Assistant',
                    hintText: 'http://192.168.1.10:8123',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _token,
                  obscureText: !_showToken,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Jeton d’accès longue durée',
                    helperText: 'Dans Home Assistant : Profil → Sécurité → Jetons d’accès longue durée',
                    suffixIcon: IconButton(
                      tooltip: _showToken ? 'Masquer le jeton' : 'Afficher le jeton',
                      icon: Icon(_showToken ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _showToken = !_showToken),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _energy,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Capteur d’énergie (facultatif)',
                    hintText: 'sensor.compteur_energie',
                    helperText: 'Affiche la consommation des 7 derniers jours sur l’accueil',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  StatusDot(
                    color: switch (link.state) {
                      LinkState.online => c.success,
                      LinkState.connecting => c.accent,
                      LinkState.offline => c.danger,
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${home.backendLabel} — $linkText', style: t.secondary)),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Reconnecter',
                    icon: Icons.refresh_rounded,
                    compact: true,
                    onPressed: home.reconnect,
                  ),
                ],
              ),
            ],
          ),
        ),
        _Panel(
          title: 'Ordinateurs',
          icon: Icons.desktop_windows_rounded,
          trailing: AppButton(
            label: 'Ajouter',
            icon: Icons.add_rounded,
            compact: true,
            onPressed: () => _editComputer(null),
          ),
          child: settings.computers.isEmpty
              ? Text(
                  'Ajoutez un ordinateur pour l’allumer à distance par Wake-on-LAN (adresse MAC), '
                  'ou via une entité Home Assistant (ex. switch.pc_bureau).',
                  style: t.secondary,
                )
              : Column(
                  children: [
                    for (final computer in settings.computers)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const IconBadge(icon: Icons.desktop_windows_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(computer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.itemTitle),
                                  Text(
                                    computer.usesHomeAssistant
                                        ? 'Home Assistant · ${computer.haEntity}'
                                        : [
                                            if (computer.mac.isNotEmpty) computer.mac.toUpperCase(),
                                            if (computer.host.isNotEmpty) computer.host,
                                          ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.secondary,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            SquareButton(
                              icon: Icons.edit_rounded,
                              tooltip: 'Modifier ${computer.name}',
                              onPressed: () => _editComputer(computer),
                            ),
                            const SizedBox(width: 8),
                            SquareButton(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Supprimer ${computer.name}',
                              onPressed: () => _deleteComputer(computer),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        _Panel(
          title: 'Affichage',
          icon: Icons.palette_rounded,
          child: Column(
            children: [
              _SettingRow(
                title: 'Thème',
                subtitle: 'Auto suit le mode clair ou sombre de la tablette',
                wide: true,
                control: SizedBox(
                  width: 330,
                  child: Segmented<AppThemeMode>(
                    values: AppThemeMode.values,
                    selected: settings.theme,
                    labelOf: (m) => switch (m) {
                      AppThemeMode.auto => 'Auto',
                      AppThemeMode.light => 'Clair',
                      AppThemeMode.dark => 'Sombre',
                    },
                    iconOf: (m) => switch (m) {
                      AppThemeMode.auto => Icons.brightness_auto_rounded,
                      AppThemeMode.light => Icons.light_mode_rounded,
                      AppThemeMode.dark => Icons.dark_mode_rounded,
                    },
                    onSelected: (m) => home.updateSettings(home.settings.copyWith(theme: m)),
                  ),
                ),
              ),
              _SettingRow(
                title: 'Garder l’écran allumé',
                subtitle: 'Pour une tablette fixée au mur',
                control: AppSwitch(
                  label: 'Garder l’écran allumé',
                  value: settings.keepScreenOn,
                  onChanged: (v) => home.updateSettings(home.settings.copyWith(keepScreenOn: v)),
                ),
              ),
              _SettingRow(
                title: 'Plein écran',
                subtitle: 'Masque les barres du système ; glissez depuis le bord pour les revoir',
                control: AppSwitch(
                  label: 'Plein écran',
                  value: settings.immersive,
                  onChanged: (v) => home.updateSettings(home.settings.copyWith(immersive: v)),
                ),
              ),
            ],
          ),
        ),
        _Panel(
          title: 'Profil',
          icon: Icons.person_rounded,
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Votre prénom',
              helperText: 'Affiché dans le message d’accueil',
            ),
          ),
        ),
        _Panel(
          title: 'À propos',
          icon: Icons.info_outline_rounded,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/branding/logo.png', width: 52, height: 52, semanticLabel: 'Logo sDash'),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'sDash — tableau de bord domotique pour tablette.\n'
                  'Police Outfit sous licence SIL Open Font License 1.1.',
                  style: t.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child, this.trailing});

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Tile(
        radius: Dim.panelRadius,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: context.colors.accent),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: context.text.sectionTitle)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Ligne de réglage : intitulé et explication à gauche, commande à droite.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.subtitle, required this.control, this.wide = false});

  final String title;
  final String subtitle;
  final Widget control;

  /// Commande large : passe sous le texte quand la place manque.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: t.itemTitle),
        const SizedBox(height: 2),
        Text(subtitle, style: t.secondary),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (wide && constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [texts, const SizedBox(height: 10), control],
            );
          }
          return Row(
            children: [
              Expanded(child: texts),
              const SizedBox(width: 16),
              control,
            ],
          );
        },
      ),
    );
  }
}

/// Formulaire d'ajout ou de modification d'un ordinateur.
class _ComputerDialog extends StatefulWidget {
  const _ComputerDialog({this.initial});

  final ComputerConfig? initial;

  @override
  State<_ComputerDialog> createState() => _ComputerDialogState();
}

class _ComputerDialogState extends State<_ComputerDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _mac = TextEditingController(text: widget.initial?.mac ?? '');
  late final _host = TextEditingController(text: widget.initial?.host ?? '');
  late final _broadcast = TextEditingController(text: widget.initial?.broadcast ?? '255.255.255.255');
  late final _shutdown = TextEditingController(text: widget.initial?.shutdownUrl ?? '');
  late final _entity = TextEditingController(text: widget.initial?.haEntity ?? '');
  late final _shutdownEntity = TextEditingController(text: widget.initial?.haShutdownEntity ?? '');

  @override
  void dispose() {
    for (final c in [_name, _mac, _host, _broadcast, _shutdown, _entity, _shutdownEntity]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      ComputerConfig(
        id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        mac: _mac.text.trim(),
        host: _host.text.trim(),
        broadcast: _broadcast.text.trim().isEmpty ? '255.255.255.255' : _broadcast.text.trim(),
        shutdownUrl: _shutdown.text.trim(),
        haEntity: _entity.text.trim(),
        haShutdownEntity: _shutdownEntity.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return AlertDialog(
      title: Text(widget.initial == null ? 'Ajouter un ordinateur' : 'Modifier l’ordinateur'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nom', hintText: 'PC du bureau'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Donnez un nom à cet ordinateur' : null,
                ),
                gap,
                TextFormField(
                  controller: _mac,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Adresse MAC (Wake-on-LAN)',
                    hintText: 'AA:BB:CC:DD:EE:FF',
                  ),
                  validator: (v) {
                    final mac = (v ?? '').trim();
                    if (mac.isEmpty && _entity.text.trim().isEmpty) {
                      return 'Indiquez une adresse MAC ou une entité Home Assistant';
                    }
                    if (mac.isNotEmpty && !isValidMac(mac)) return 'Adresse MAC invalide';
                    return null;
                  },
                ),
                gap,
                TextFormField(
                  controller: _host,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Adresse IP (facultatif)',
                    hintText: '192.168.1.42',
                    helperText: 'Permet d’afficher si la machine est allumée',
                  ),
                ),
                gap,
                TextFormField(
                  controller: _broadcast,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Adresse de diffusion', hintText: '255.255.255.255'),
                ),
                gap,
                TextFormField(
                  controller: _shutdown,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL d’extinction (facultatif)',
                    hintText: 'http://192.168.1.42:8000/shutdown',
                    helperText: 'Appelée en POST pour éteindre la machine',
                  ),
                  validator: (v) {
                    final url = (v ?? '').trim();
                    if (url.isEmpty) return null;
                    final uri = Uri.tryParse(url);
                    return uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty
                        ? 'URL invalide (http:// ou https://)'
                        : null;
                  },
                ),
                gap,
                TextFormField(
                  controller: _entity,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Entité Home Assistant (facultatif)',
                    hintText: 'switch.pc_bureau',
                    helperText: 'Prioritaire en mode Home Assistant',
                  ),
                  validator: (v) {
                    final e = (v ?? '').trim();
                    return e.isNotEmpty && !RegExp(r'^[a-z_]+\.[a-z0-9_]+$').hasMatch(e)
                        ? 'Format attendu : domaine.nom'
                        : null;
                  },
                ),
                gap,
                TextFormField(
                  controller: _shutdownEntity,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Entité Home Assistant pour éteindre (facultatif)',
                    hintText: 'button.nas_shut_down',
                    helperText: 'Bouton ou script qui éteint la machine (NAS Synology, HASS.Agent…)',
                  ),
                  validator: (v) {
                    final e = (v ?? '').trim();
                    return e.isNotEmpty && !RegExp(r'^[a-z_]+\.[a-z0-9_]+$').hasMatch(e)
                        ? 'Format attendu : domaine.nom'
                        : null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}
