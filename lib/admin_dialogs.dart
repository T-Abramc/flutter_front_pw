import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_front_pw/api_client.dart';
import 'package:flutter_front_pw/Models.dart';

class AuthHeaderStatusWidget extends StatelessWidget {
  final ApiClient apiClient;
  final String? statusLabel;
  final VoidCallback onToggleDropdown;

  const AuthHeaderStatusWidget({
    super.key,
    required this.apiClient,
    required this.statusLabel,
    required this.onToggleDropdown,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                statusLabel!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusLabel == 'Zalogowano'
                      ? Colors.green.shade800
                      : Colors.deepOrange.shade800,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              label: 'Konto administratora',
              button: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onToggleDropdown,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: apiClient.isLoggedIn
                      ? Colors.green.shade700
                      : Colors.indigo.shade700,
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthDropdownPanel extends StatefulWidget {
  final ApiClient apiClient;
  final TextEditingController urlController;
  final VoidCallback onClose;
  final void Function(String statusLabel) onAuthStateChanged;

  const AuthDropdownPanel({
    super.key,
    required this.apiClient,
    required this.urlController,
    required this.onClose,
    required this.onAuthStateChanged,
  });

  @override
  State<AuthDropdownPanel> createState() => _AuthDropdownPanelState();
}

class _AuthDropdownPanelState extends State<AuthDropdownPanel> {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'admin');

  bool _isBusy = false;

  void _notify(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _login() async {
    if (_isBusy) return;
    widget.apiClient.baseUrl = widget.urlController.text;
    widget.urlController.text = widget.apiClient.baseUrl;

    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _notify('Podaj login i hasło.', isError: true);
      return;
    }

    setState(() => _isBusy = true);
    try {
      await widget.apiClient.login(_userCtrl.text.trim(), _passCtrl.text);
      widget.onAuthStateChanged('Zalogowano');
      widget.onClose();
      _notify('Zalogowano pomyślnie.');
    } catch (e) {
      _notify('Błąd logowania: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _logout() async {
    if (_isBusy) return;
    widget.apiClient.baseUrl = widget.urlController.text;
    setState(() => _isBusy = true);
    try {
      await widget.apiClient.logout();
      widget.onAuthStateChanged('Wylogowano');
      widget.onClose();
      _notify('Wylogowano.');
    } catch (e) {
      widget.onAuthStateChanged('Wylogowano');
      widget.onClose();
      _notify('Wylogowano (odpowiedź serwera: $e)');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openChangePasswordDialog() async {
    widget.onClose();
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ChangePasswordDialog(
        apiClient: widget.apiClient,
        onSuccess: () => _notify('Hasło zostało zmienione.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Konto administratora',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                IconButton(
                  tooltip: 'Zamknij panel logowania',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            TextField(
              controller: widget.urlController,
              decoration: const InputDecoration(
                labelText: 'Adres API',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'Login',
                isDense: true,
              ),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Hasło',
                isDense: true,
              ),
              onSubmitted: (_) => _login(),
            ),
            if (_isBusy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isBusy ? null : _login,
                    child: const Text('Zaloguj'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : _logout,
                    child: const Text('Wyloguj'),
                  ),
                ),
              ],
            ),
            if (widget.apiClient.isLoggedIn) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _openChangePasswordDialog,
                icon: const Icon(Icons.key, size: 18),
                label: const Text('Zmiana hasła'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback onSuccess;

  const _ChangePasswordDialog({
    required this.apiClient,
    required this.onSuccess,
  });

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isSaving = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.apiClient.changePassword(_currentCtrl.text, _newCtrl.text);
      widget.onSuccess();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zmiana hasła administratora'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
              TextFormField(
                controller: _currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Bieżące hasło'),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Podaj bieżące hasło' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nowe hasło (min. 8 znaków)'),
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'Nowe hasło musi mieć co najmniej 8 znaków';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Powtórz nowe hasło'),
                validator: (v) {
                  if (v != _newCtrl.text) {
                    return 'Hasła nie są identyczne';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_isSaving) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: const Text('Zapisz hasło'),
        ),
      ],
    );
  }
}

class AdminManagementPanel extends StatefulWidget {
  final ApiClient apiClient;
  final List<Series> seriesList;
  final VoidCallback onDataChanged;

  const AdminManagementPanel({
    super.key,
    required this.apiClient,
    required this.seriesList,
    required this.onDataChanged,
  });

  @override
  State<AdminManagementPanel> createState() => _AdminManagementPanelState();
}

class _AdminManagementPanelState extends State<AdminManagementPanel> {
  List<Sensor> _sensors = [];
  bool _loadingSensors = false;
  bool _busyAction = false;
  String? _panelError;

  final _sensorNameCtrl = TextEditingController();
  String? _selectedSensorSeriesId;

  @override
  void initState() {
    super.initState();
    if (widget.seriesList.isNotEmpty) {
      _selectedSensorSeriesId = widget.seriesList.first.id;
    }
    _loadSensors();
  }

  @override
  void didUpdateWidget(covariant AdminManagementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedSensorSeriesId == null && widget.seriesList.isNotEmpty) {
      _selectedSensorSeriesId = widget.seriesList.first.id;
    } else if (_selectedSensorSeriesId != null &&
        !widget.seriesList.any((s) => s.id == _selectedSensorSeriesId)) {
      _selectedSensorSeriesId =
          widget.seriesList.isNotEmpty ? widget.seriesList.first.id : null;
    }
  }

  void _showMsg(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _loadSensors() async {
    if (!widget.apiClient.isLoggedIn) return;
    setState(() {
      _loadingSensors = true;
      _panelError = null;
    });
    try {
      final list = await widget.apiClient.getSensors();
      setState(() => _sensors = list);
    } catch (e) {
      setState(() => _panelError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSensors = false);
    }
  }

  Future<void> _openSeriesForm({Series? existing}) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _SeriesFormDialog(
        apiClient: widget.apiClient,
        existing: existing,
        onSaved: (msg) {
          _showMsg(msg);
          widget.onDataChanged();
        },
      ),
    );
  }

  Future<void> _deleteSeries(Series series) async {
    if (_busyAction) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunięcie serii'),
        content: Text(
          'Usunąć serię "${series.name}" wraz ze wszystkimi jej wynikami i czujnikami?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _busyAction = true;
      _panelError = null;
    });
    try {
      await widget.apiClient.deleteSeries(series.id);
      _showMsg('Usunięto serię "${series.name}".');
      widget.onDataChanged();
      await _loadSensors();
    } catch (e) {
      setState(() => _panelError = e.toString());
      _showMsg('Błąd usuwania serii: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _registerSensor() async {
    if (_busyAction) return;
    final name = _sensorNameCtrl.text.trim();
    final seriesId = _selectedSensorSeriesId;
    if (name.isEmpty) {
      _showMsg('Podaj nazwę czujnika.', isError: true);
      return;
    }
    if (seriesId == null || seriesId.isEmpty) {
      _showMsg('Wybierz serię dla czujnika.', isError: true);
      return;
    }

    setState(() {
      _busyAction = true;
      _panelError = null;
    });
    try {
      final created = await widget.apiClient.createSensor(name, seriesId);
      _sensorNameCtrl.clear();
      await _loadSensors();
      if (mounted && created.apiKey != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Klucz API czujnika (widoczny tylko raz!)'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Czujnik: ${created.name}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Skopiuj ten klucz teraz – serwer przechowuje tylko jego skrót i nie pokaże go ponownie:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    created.apiKey!,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: created.apiKey!));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Skopiowano klucz API do schowka.')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Kopiuj klucz API'),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Zamknij'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _panelError = e.toString());
      _showMsg('Błąd rejestracji czujnika: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _unregisterSensor(Sensor sensor) async {
    if (_busyAction) return;
    setState(() {
      _busyAction = true;
      _panelError = null;
    });
    try {
      await widget.apiClient.deleteSensor(sensor.id);
      _showMsg('Wyrejestrowano czujnik "${sensor.name}". Jego klucz przestał działać.');
      await _loadSensors();
    } catch (e) {
      setState(() => _panelError = e.toString());
      _showMsg('Błąd wyrejestrowywania czujnika: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  String _seriesNameById(String id) {
    final match = widget.seriesList.where((s) => s.id == id);
    return match.isNotEmpty ? match.first.name : 'ID: $id';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Panel administratora',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_busyAction || _loadingSensors) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_panelError != null) ...[
              const SizedBox(height: 8),
              Text(
                _panelError!,
                style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Zarządzanie seriami',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                FilledButton.icon(
                  onPressed: _busyAction ? null : () => _openSeriesForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nowa seria'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.seriesList.isEmpty)
              const Text('Brak zdefiniowanych serii.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nazwa')),
                    DataColumn(label: Text('Zakres min..max')),
                    DataColumn(label: Text('Kolor')),
                    DataColumn(label: Text('Ikona')),
                    DataColumn(label: Text('Jednostka')),
                    DataColumn(label: Text('Akcje')),
                  ],
                  rows: widget.seriesList.map((s) {
                    return DataRow(
                      cells: [
                        DataCell(Text(s.name)),
                        DataCell(Text('${s.minValue} .. ${s.maxValue}')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.only(right: 6),
                                color: s.flutterColor,
                              ),
                              Text(s.color),
                            ],
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(s.flutterIcon, size: 18, color: s.flutterColor),
                              const SizedBox(width: 6),
                              Text(s.icon ?? 'domyślna'),
                            ],
                          ),
                        ),
                        DataCell(Text(s.unit ?? '—')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edytuj serię',
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: _busyAction
                                    ? null
                                    : () => _openSeriesForm(existing: s),
                              ),
                              IconButton(
                                tooltip: 'Usuń serię',
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: _busyAction ? null : () => _deleteSeries(s),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            const Divider(height: 28),
            const Text(
              'Zarządzanie czujnikami',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _sensorNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nazwa czujnika',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _registerSensor(),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSensorSeriesId,
                    decoration: const InputDecoration(
                      labelText: 'Seria pomiarowa',
                      isDense: true,
                    ),
                    items: widget.seriesList
                        .map((s) => DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedSensorSeriesId = val),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _busyAction ? null : _registerSensor,
                  icon: const Icon(Icons.sensors, size: 18),
                  label: const Text('Zarejestruj czujnik'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_sensors.isEmpty)
              const Text('Brak zarejestrowanych czujników.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nazwa czujnika')),
                    DataColumn(label: Text('Przypisana seria')),
                    DataColumn(label: Text('Wyrejestrowanie')),
                  ],
                  rows: _sensors.map((sensor) {
                    return DataRow(
                      cells: [
                        DataCell(Text(sensor.name)),
                        DataCell(Text(_seriesNameById(sensor.seriesId))),
                        DataCell(
                          OutlinedButton.icon(
                            onPressed:
                                _busyAction ? null : () => _unregisterSensor(sensor),
                            icon: const Icon(Icons.link_off, size: 16),
                            label: const Text('Wyrejestruj'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeriesFormDialog extends StatefulWidget {
  final ApiClient apiClient;
  final Series? existing;
  final void Function(String message) onSaved;

  const _SeriesFormDialog({
    required this.apiClient,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_SeriesFormDialog> createState() => _SeriesFormDialogState();
}

class _SeriesFormDialogState extends State<_SeriesFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _unitCtrl;

  late int _red;
  late int _green;
  late int _blue;
  late String _selectedIconName;

  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _minCtrl = TextEditingController(text: e != null ? e.minValue.toString() : '0');
    _maxCtrl = TextEditingController(text: e != null ? e.maxValue.toString() : '100');
    _unitCtrl = TextEditingController(text: e?.unit ?? '');

    // Domyślny kolor (#1f77b4) albo aktualny kolor edytowanej serii
    final initialColor = e != null ? e.flutterColor : const Color(0xFF1F77B4);
    _red = (initialColor.r * 255).round().clamp(0, 255);
    _green = (initialColor.g * 255).round().clamp(0, 255);
    _blue = (initialColor.b * 255).round().clamp(0, 255);

    // Mapowanie istniejącej nazwy ikony lub domyślny klucz z mapy
    final mappedExisting = SeriesIconMapper.normalizeName(e?.icon);
    _selectedIconName = mappedExisting ?? SeriesIconMapper.availableIcons.keys.first;
  }

  Color get _currentRgbColor => Color.fromARGB(255, _red, _green, _blue);

  String get _currentHexColor => Series.colorToHex(_currentRgbColor);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    final minVal = double.parse(_minCtrl.text.trim().replaceAll(',', '.'));
    final maxVal = double.parse(_maxCtrl.text.trim().replaceAll(',', '.'));
    final unitVal = _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim();
    final iconVal = SeriesIconMapper.normalizeName(_selectedIconName);

    final payload = Series(
      id: widget.existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      minValue: minVal,
      maxValue: maxVal,
      color: _currentHexColor,
      icon: iconVal,
      unit: unitVal,
    );

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      if (widget.existing == null) {
        await widget.apiClient.createSeries(payload);
        widget.onSaved('Utworzono serię "${payload.name}".');
      } else {
        await widget.apiClient.updateSeries(widget.existing!.id, payload);
        widget.onSaved('Zaktualizowano serię "${payload.name}".');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildRgbSlider({
    required String label,
    required int value,
    required Color activeColor,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: activeColor,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edycja serii' : 'Nowa seria pomiarowa'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nazwa serii (1-100 znaków)'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty || t.length > 100) {
                      return 'Nazwa musi mieć od 1 do 100 znaków';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minCtrl,
                        decoration: const InputDecoration(labelText: 'Wartość min'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) {
                          final parsed = double.tryParse(
                            (v ?? '').trim().replaceAll(',', '.'),
                          );
                          if (parsed == null) return 'Podaj liczbę';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _maxCtrl,
                        decoration: const InputDecoration(labelText: 'Wartość max'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) {
                          final maxParsed = double.tryParse(
                            (v ?? '').trim().replaceAll(',', '.'),
                          );
                          if (maxParsed == null) return 'Podaj liczbę';
                          final minParsed = double.tryParse(
                            _minCtrl.text.trim().replaceAll(',', '.'),
                          );
                          if (minParsed != null && minParsed >= maxParsed) {
                            return 'Min musi być < Max';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Pełny wybór koloru RGB
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kolor RGB',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _currentRgbColor,
                            border: Border.all(color: Colors.black38),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Text(
                          _currentHexColor,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildRgbSlider(
                  label: 'R',
                  value: _red,
                  activeColor: Colors.red,
                  onChanged: (val) => setState(() => _red = val),
                ),
                _buildRgbSlider(
                  label: 'G',
                  value: _green,
                  activeColor: Colors.green,
                  onChanged: (val) => setState(() => _green = val),
                ),
                _buildRgbSlider(
                  label: 'B',
                  value: _blue,
                  activeColor: Colors.blue,
                  onChanged: (val) => setState(() => _blue = val),
                ),

                const SizedBox(height: 10),
                TextFormField(
                  controller: _unitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Jednostka (opcjonalnie, np. °C)',
                  ),
                  onFieldSubmitted: (_) => _submit(),
                ),

                const SizedBox(height: 14),
                const Text(
                  'Wybór ikony serii (wysyłana nazwa ikony)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SeriesIconMapper.availableIcons.entries.map((entry) {
                    final isSelected = _selectedIconName == entry.key;
                    return InkWell(
                      onTap: () => setState(() => _selectedIconName = entry.key),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _currentRgbColor.withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? _currentRgbColor : Colors.black26,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Tooltip(
                          message: entry.key,
                          child: Icon(
                            entry.value,
                            color: isSelected ? _currentRgbColor : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_isSaving) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: Text(isEdit ? 'Zapisz zmiany' : 'Utwórz'),
        ),
      ],
    );
  }
}