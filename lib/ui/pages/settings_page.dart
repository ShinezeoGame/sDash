import 'package:flutter/material.dart';

import '../../data/home_backend.dart';
import '../../data/network/wake_on_lan.dart';
import '../../data/settings.dart';
import '../../state/home_scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
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
    await home.updateSettings(home.settings.copyWith(
      userName: _name.text.trim(),
      backend: _backend,
      haUrl: _url.text.trim(),
      haToken: _token.text.trim(),
      energySensor: _energy.text.trim(),
    ));
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
    final link = home.link;
    final linkText = link.message ??
        switch (link.state) {
          LinkState.online => 'connecté',
          LinkState.connecting => 'connexion…',
          LinkState.offline => 'hors ligne',
        };

    return DetailPage(
      title: 'Réglages',
      subtitle: 'Connexion, ordinateurs et affichage',
      maxWidth: 920,
      actions: [
        PillButton(
          label: 'Enregistrer',
          icon: Icons.check_rounded,
          primary: _isDirty(settings),
          onPressed: _isDirty(settings) ? _save : null,
        ),
      ],
      children: [
        _Section(
          title: 'Profil',
          icon: Icons.person_rounded,
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Votre prénom', hintText: 'Affiché dans le message d’accueil'),
          ),
        ),
        _Section(
          title: 'Connexion domotique',
          icon: Icons.hub_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: PillSelector<BackendKind>(
                  values: BackendKind.values,
                  selected: _backend,
                  labelOf: (b) => b == BackendKind.demo ? 'Maison de démo' : 'Home Assistant',
                  iconOf: (b) => b == BackendKind.demo ? Icons.auto_awesome_rounded : Icons.home_rounded,
                  onSelected: (b) => setState(() => _backend = b),
                ),
              ),
              const SizedBox(height: 18),
              if (_backend == BackendKind.demo)
                const Text(
                  'Le mode démo simule une maison complète (lumières, chauffage, volets, ordinateurs) '
                  'pour découvrir sDash sans rien configurer.',
                  style: AppText.body,
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
                    helperText: 'Home Assistant → Profil → Sécurité → Jetons d’accès longue durée',
                    suffixIcon: IconButton(
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
              const SizedBox(height: 18),
              Row(
                children: [
                  StatusDot(
                    color: switch (link.state) {
                      LinkState.online => Palette.sage,
                      LinkState.connecting => Palette.amber,
                      LinkState.offline => Palette.rose,
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${home.backendLabel} — $linkText', style: AppText.label)),
                  PillButton(label: 'Reconnecter', icon: Icons.refresh_rounded, compact: true, onPressed: home.reconnect),
                ],
              ),
            ],
          ),
        ),
        _Section(
          title: 'Ordinateurs',
          icon: Icons.desktop_windows_rounded,
          trailing: PillButton(
            label: 'Ajouter',
            icon: Icons.add_rounded,
            compact: true,
            onPressed: () => _editComputer(null),
          ),
          child: settings.computers.isEmpty
              ? const Text(
                  'Ajoutez un PC pour l’allumer à distance par Wake-on-LAN (adresse MAC), '
                  'ou via une entité Home Assistant (ex. switch.pc_bureau).',
                  style: AppText.body,
                )
              : Column(
                  children: [
                    for (final c in settings.computers)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const IconOrb(icon: Icons.desktop_windows_rounded, size: 40),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name, style: AppText.subtitle.copyWith(fontSize: 16)),
                                  Text(
                                    c.usesHomeAssistant
                                        ? 'Home Assistant · ${c.haEntity}'
                                        : [if (c.mac.isNotEmpty) c.mac.toUpperCase(), if (c.host.isNotEmpty) c.host].join(' · '),
                                    style: AppText.label,
                                  ),
                                ],
                              ),
                            ),
                            GlassIconButton(icon: Icons.edit_rounded, size: 40, tooltip: 'Modifier', onPressed: () => _editComputer(c)),
                            const SizedBox(width: 8),
                            GlassIconButton(
                              icon: Icons.delete_outline_rounded,
                              size: 40,
                              tooltip: 'Supprimer',
                              onPressed: () => _deleteComputer(c),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        _Section(
          title: 'Affichage',
          icon: Icons.palette_rounded,
          child: Column(
            children: [
              _ToggleRow(
                title: 'Effet verre allégé',
                subtitle: 'Désactive le flou d’arrière-plan sur les tablettes peu puissantes',
                value: settings.reducedGlass,
                onChanged: (v) => home.updateSettings(home.settings.copyWith(reducedGlass: v)),
              ),
              _ToggleRow(
                title: 'Garder l’écran allumé',
                subtitle: 'Idéal pour une tablette fixée au mur',
                value: settings.keepScreenOn,
                onChanged: (v) => home.updateSettings(home.settings.copyWith(keepScreenOn: v)),
              ),
              _ToggleRow(
                title: 'Plein écran',
                subtitle: 'Masque les barres système (glisser depuis le bord pour les afficher)',
                value: settings.immersive,
                onChanged: (v) => home.updateSettings(home.settings.copyWith(immersive: v)),
              ),
            ],
          ),
        ),
        const _Section(
          title: 'À propos',
          icon: Icons.info_outline_rounded,
          child: Text(
            'sDash 1.0 — tableau de bord domotique pour tablette.\nPolice Outfit sous licence SIL Open Font License 1.1.',
            style: AppText.body,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child, this.trailing});

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Palette.amber, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppText.title)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.subtitle.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.label),
              ],
            ),
          ),
          GlowToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Formulaire d'ajout / modification d'un ordinateur.
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

  @override
  void dispose() {
    for (final c in [_name, _mac, _host, _broadcast, _shutdown, _entity]) {
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
                    return e.isNotEmpty && !RegExp(r'^[a-z_]+\.[a-z0-9_]+$').hasMatch(e) ? 'Format attendu : domaine.nom' : null;
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
