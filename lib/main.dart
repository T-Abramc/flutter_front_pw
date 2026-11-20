import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_front_pw/admin_dialogs.dart';
import 'package:flutter_front_pw/api_client.dart';
import 'package:flutter_front_pw/Models.dart';
import 'package:flutter_front_pw/print_bridge.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RendererBinding.instance.ensureSemantics();
  final apiClient = ApiClient(baseUrl: 'https://localhost:44343');
  await apiClient.initSession();
  runApp(SensorDashboardApp(apiClient: apiClient));
}

class SensorDashboardApp extends StatelessWidget {
  final ApiClient apiClient;
  const SensorDashboardApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serie Pomiarowe IoT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: DashboardScreen(apiClient: apiClient),
    );
  }
}

class TableRowData {
  final DateTime timestamp;
  final Map<String, Measurement> bySeries;

  TableRowData({required this.timestamp, required this.bySeries});
}

class DashboardScreen extends StatefulWidget {
  final ApiClient apiClient;
  const DashboardScreen({super.key, required this.apiClient});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final TextEditingController _urlCtrl;

  String? _authStatusLabel;
  bool _isAuthDropdownOpen = false;
  bool _isPrintMode = false;

  bool _isLoading = false;
  String? _errorMessage;
  List<Series> _allSeries = [];
  Set<String> _selectedSeriesIds = {};
  List<Measurement> _measurements = [];
  DateTime? _fromDate;
  DateTime? _toDate;

  DateTime? _selectedTimestamp;
  Set<String> _highlightedMeasurementIds = {};

  final DateFormat _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm:ss');
  final DateFormat _shortTimeFmt = DateFormat('MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.apiClient.baseUrl);
    registerPrintEventListeners(
      onBeforePrint: () {
        if (mounted) {
          setState(() {
            _isAuthDropdownOpen = false;
            _isPrintMode = true;
          });
        }
      },
      onAfterPrint: () {
        if (mounted) {
          setState(() => _isPrintMode = false);
        }
      },
    );
    _loadInitialData();
  }

  void _handlePrintClick() {
    setState(() {
      _isAuthDropdownOpen = false;
      _isPrintMode = true;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        triggerBrowserPrint();
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      widget.apiClient.baseUrl = _urlCtrl.text;
      final series = await widget.apiClient.getSeries();
      final validIds = series.map((s) => s.id).toSet();
      final selected = _selectedSeriesIds.isEmpty
          ? validIds
          : _selectedSeriesIds.intersection(validIds);

      final measurements = await widget.apiClient.getMeasurements(
        seriesIds: selected.toList(),
        from: _fromDate,
        to: _toDate,
      );
      setState(() {
        _allSeries = series;
        _selectedSeriesIds = selected;
        _measurements = measurements;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshMeasurementsOnly() async {
    if (_selectedSeriesIds.isEmpty) {
      setState(() => _measurements = []);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final measurements = await widget.apiClient.getMeasurements(
        seriesIds: _selectedSeriesIds.toList(),
        from: _fromDate,
        to: _toDate,
      );
      setState(() => _measurements = measurements);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateTime({required bool isFrom}) async {
    final initial = (isFrom ? _fromDate : _toDate) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isFrom) {
        _fromDate = combined;
      } else {
        _toDate = combined;
      }
    });
    await _refreshMeasurementsOnly();
  }

  FlDotPainter _getDotPainter(int seriesIndex, Color color, bool isHighlighted) {
    final double size = isHighlighted ? 8.0 : 4.0;
    final Color strokeColor = isHighlighted ? Colors.black : Colors.white;
    final double strokeWidth = isHighlighted ? 3.0 : 1.0;

    switch (seriesIndex % 3) {
      case 0:
        return FlDotCirclePainter(
          radius: size,
          color: color,
          strokeWidth: strokeWidth,
          strokeColor: strokeColor,
        );
      case 1:
        return FlDotSquarePainter(
          size: size * 2,
          color: color,
          strokeWidth: strokeWidth,
          strokeColor: strokeColor,
        );
      default:
        return FlDotCrossPainter(
          size: size * 2,
          color: color,
          width: isHighlighted ? 4.0 : 2.0,
        );
    }
  }

  List<TableRowData> _buildTableRows() {
    final Map<int, Map<String, Measurement>> grouped = {};
    for (final m in _measurements) {
      if (!_selectedSeriesIds.contains(m.seriesId)) continue;
      final key = m.timestamp.millisecondsSinceEpoch;
      grouped.putIfAbsent(key, () => {})[m.seriesId] = m;
    }
    final keys = grouped.keys.toList()..sort();
    return keys
        .map((k) => TableRowData(
              timestamp: DateTime.fromMillisecondsSinceEpoch(k),
              bySeries: grouped[k]!,
            ))
        .toList();
  }

  String? _resolveSingleOrCommonUnit(List<Series> activeSeries) {
    if (activeSeries.length == 1) {
      final u = activeSeries.first.unit?.trim();
      if (u != null && u.isNotEmpty) return u;
      return null;
    }
    if (activeSeries.length > 1) {
      final units = activeSeries.map((s) => (s.unit ?? '').trim()).toSet();
      if (units.length == 1 && units.first.isNotEmpty) {
        return units.first;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activeSeries = _allSeries.where((s) => _selectedSeriesIds.contains(s.id)).toList();
    final tableRows = _buildTableRows();

    final contentColumn = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 0 ? constraints.maxWidth : 1024.0;
        final isMobile = width < 600;
        final padding = _isPrintMode
            ? const EdgeInsets.all(6)
            : EdgeInsets.all(isMobile ? 8 : 16);

        return Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isPrintMode) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Raport pomiarowy – wykres i tabela',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _isPrintMode = false),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Wyjdź z podglądu wydruku'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (!_isPrintMode) ...[
                if (_isLoading) const LinearProgressIndicator(),
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade100,
                    child: Text(
                      'Błąd komunikacji z serwerem: $_errorMessage',
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                _buildFiltersCard(isMobile),
                const SizedBox(height: 16),
              ],
              _buildChartCard(activeSeries, isMobile, width),
              const SizedBox(height: 16),
              _buildTableCard(activeSeries, tableRows),
              if (!_isPrintMode && widget.apiClient.isLoggedIn) ...[
                const SizedBox(height: 20),
                AdminManagementPanel(
                  apiClient: widget.apiClient,
                  seriesList: _allSeries,
                  onDataChanged: _loadInitialData,
                ),
              ],
            ],
          ),
        );
      },
    );

    if (_isPrintMode) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(child: contentColumn),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomiary IoT', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Drukuj wykres i tabelę',
            onPressed: _handlePrintClick,
            icon: const Icon(Icons.print),
          ),
          IconButton(
            tooltip: 'Odśwież dane z API',
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh),
          ),
          AuthHeaderStatusWidget(
            apiClient: widget.apiClient,
            statusLabel: _authStatusLabel,
            onToggleDropdown: () =>
                setState(() => _isAuthDropdownOpen = !_isAuthDropdownOpen),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(child: contentColumn),
          if (_isAuthDropdownOpen)
            Positioned(
              top: 8,
              right: 12,
              width: 320,
              child: AuthDropdownPanel(
                apiClient: widget.apiClient,
                urlController: _urlCtrl,
                onClose: () => setState(() => _isAuthDropdownOpen = false),
                onAuthStateChanged: (label) {
                  setState(() => _authStatusLabel = label);
                  _loadInitialData();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard(bool isMobile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtrowanie: Przedział czasu i widoczne serie',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _fromDate == null
                        ? 'Od: początek'
                        : 'Od: ${_shortTimeFmt.format(_fromDate!)}',
                  ),
                  onPressed: () => _pickDateTime(isFrom: true),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 16),
                  label: Text(
                    _toDate == null ? 'Do: teraz' : 'Do: ${_shortTimeFmt.format(_toDate!)}',
                  ),
                  onPressed: () => _pickDateTime(isFrom: false),
                ),
                if (_fromDate != null || _toDate != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _fromDate = null;
                        _toDate = null;
                      });
                      _refreshMeasurementsOnly();
                    },
                    child: const Text('Wyczyść daty'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_allSeries.isEmpty)
              const Text('Brak serii do wyświetlenia. Upewnij się, że API działa.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: List.generate(_allSeries.length, (index) {
                  final s = _allSeries[index];
                  final isSelected = _selectedSeriesIds.contains(s.id);
                  final unitSuffix =
                      (s.unit != null && s.unit!.isNotEmpty) ? ' (${s.unit})' : '';
                  return FilterChip(
                    selected: isSelected,
                    avatar: CircleAvatar(
                      backgroundColor: s.flutterColor,
                      radius: 12,
                      child: Icon(
                        s.flutterIcon,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    label: Text('${s.name}$unitSuffix [${s.minValue}..${s.maxValue}]'),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedSeriesIds.add(s.id);
                        } else {
                          _selectedSeriesIds.remove(s.id);
                        }
                      });
                      _refreshMeasurementsOnly();
                    },
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(List<Series> activeSeries, bool isMobile, double availableWidth) {
    final visibleMeasurements = _measurements
        .where((m) => _selectedSeriesIds.contains(m.seriesId))
        .toList();
    final unitLabel = _resolveSingleOrCommonUnit(activeSeries);

    double? minX;
    double? maxX;
    double xInterval = 1;

    if (visibleMeasurements.isNotEmpty) {
      final timestamps = visibleMeasurements
          .map((m) => m.timestamp.millisecondsSinceEpoch.toDouble())
          .toList()
        ..sort();
      final rawMinX = timestamps.first;
      final rawMaxX = timestamps.last;
      final span = (rawMaxX - rawMinX).abs();
      final pad = span > 0 ? span * 0.03 : 60000.0;
      minX = rawMinX - pad;
      maxX = rawMaxX + pad;

      final totalSpan = (maxX - minX).abs();
      final desiredTicks = isMobile ? 4.0 : (availableWidth / 150.0).clamp(4.0, 8.0);
      xInterval = totalSpan > 0 ? (totalSpan / desiredTicks) : 60000.0;
    }

    final chartWidget = LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        clipData: const FlClipData.all(),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        lineTouchData: LineTouchData(
          enabled: !_isPrintMode,
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            if (event is FlTapUpEvent &&
                response != null &&
                response.lineBarSpots != null &&
                response.lineBarSpots!.isNotEmpty) {
              final spot = response.lineBarSpots!.first;
              final ts = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
              setState(() {
                _selectedTimestamp = ts;
                _highlightedMeasurementIds = visibleMeasurements
                    .where((m) => m.timestamp.millisecondsSinceEpoch == spot.x.toInt())
                    .map((m) => m.id)
                    .toSet();
              });
            }
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameSize: unitLabel != null ? 24 : 0,
            axisNameWidget: unitLabel != null
                ? Center(
                    child: Text(
                      unitLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : null,
            sideTitles: const SideTitles(
              showTitles: true,
              reservedSize: 44,
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameSize: 22,
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '[data]',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                if (value < meta.min || value > meta.max) {
                  return const SizedBox.shrink();
                }
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('HH:mm\ndd.MM').format(dt),
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: List.generate(activeSeries.length, (idx) {
          final series = activeSeries[idx];
          final seriesPoints = visibleMeasurements
              .where((m) => m.seriesId == series.id)
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

          return LineChartBarData(
            spots: seriesPoints
                .map((m) => FlSpot(
                      m.timestamp.millisecondsSinceEpoch.toDouble(),
                      m.value,
                    ))
                .toList(),
            isCurved: false,
            color: series.flutterColor,
            barWidth: 2.5,
            dashArray: idx % 2 == 1 ? [6, 3] : null,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, spotIndex) {
                final m = seriesPoints[spotIndex];
                final isHighlighted = _highlightedMeasurementIds.contains(m.id) ||
                    (_selectedTimestamp != null &&
                        m.timestamp.millisecondsSinceEpoch ==
                            _selectedTimestamp!.millisecondsSinceEpoch);
                return _getDotPainter(idx, series.flutterColor, isHighlighted);
              },
            ),
          );
        }),
      ),
    );

    // Ramka ograniczająca wykres: w trybie wydruku zwęża i skaluje wykres w dół, aby nie ucinało prawej strony
    final constrainedChart = _isPrintMode
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: (availableWidth - 36).clamp(240.0, 620.0),
              maxHeight: 220,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 680,
                height: 230,
                child: chartWidget,
              ),
            ),
          )
        : SizedBox(
            height: isMobile ? 270 : 350,
            width: double.infinity,
            child: chartWidget,
          );

    return Card(
      elevation: _isPrintMode ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Wykres pomiarów w funkcji czasu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isPrintMode && _selectedTimestamp != null)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedTimestamp = null;
                      _highlightedMeasurementIds.clear();
                    }),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Usuń wyróżnienie'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (visibleMeasurements.isEmpty)
              const SizedBox(
                height: 220,
                child: Center(child: Text('Brak wyników pomiarów w wybranym zakresie.')),
              )
            else
              constrainedChart,
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(List<Series> activeSeries, List<TableRowData> rows) {
    return Card(
      elevation: _isPrintMode ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tabela pomiarów',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Brak danych do wyświetlenia w tabeli.'),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: [
                    const DataColumn(label: Text('Czas pomiaru')),
                    ...activeSeries.map(
                      (s) {
                        final unitSuffix =
                            (s.unit != null && s.unit!.isNotEmpty) ? ' (${s.unit})' : '';
                        return DataColumn(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(s.flutterIcon, size: 14, color: s.flutterColor),
                              const SizedBox(width: 6),
                              Text('${s.name}$unitSuffix'),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  rows: rows.map((row) {
                    final isSelected = _selectedTimestamp != null &&
                        row.timestamp.millisecondsSinceEpoch ==
                            _selectedTimestamp!.millisecondsSinceEpoch;

                    return DataRow(
                      selected: isSelected,
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isSelected) return Colors.amber.withValues(alpha: 0.35);
                        return null;
                      }),
                      onSelectChanged: _isPrintMode
                          ? null
                          : (_) {
                              setState(() {
                                if (isSelected) {
                                  _selectedTimestamp = null;
                                  _highlightedMeasurementIds.clear();
                                } else {
                                  _selectedTimestamp = row.timestamp;
                                  _highlightedMeasurementIds =
                                      row.bySeries.values.map((m) => m.id).toSet();
                                }
                              });
                            },
                      cells: [
                        DataCell(Text(_dateTimeFmt.format(row.timestamp))),
                        ...activeSeries.map((s) {
                          final m = row.bySeries[s.id];
                          return DataCell(
                            Text(
                              m != null ? m.value.toStringAsFixed(2) : '—',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }),
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