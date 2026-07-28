import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/services/market_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
import 'package:path_provider/path_provider.dart';

class _CsvRateRow {
  const _CsvRateRow({
    required this.cropName,
    required this.marketName,
    required this.district,
    required this.minPrice,
    required this.maxPrice,
    required this.unit,
  });

  final String cropName;
  final String marketName;
  final String district;
  final String minPrice;
  final String maxPrice;
  final String unit;
}

class AdminRatesScreen extends StatefulWidget {
  const AdminRatesScreen({super.key});

  @override
  State<AdminRatesScreen> createState() => _AdminRatesScreenState();
}

class _AdminRatesScreenState extends State<AdminRatesScreen> {
  final _api = AdminApiService();
  Future<List<CropRateDto>>? _future;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCrop;
  String? _selectedDistrict;

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void initState() {
    super.initState();
    _reload();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.fetchRates(limit: 200);
    });
  }

  List<String> _optionsFrom(Iterable<String> values) {
    final options =
        values
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList();
    options.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return options;
  }

  List<CropRateDto> _applyFilters(List<CropRateDto> rows) {
    final query = _searchController.text.trim().toLowerCase();
    return rows.where((row) {
      if (_selectedCrop != null && row.cropName != _selectedCrop) return false;
      if (_selectedDistrict != null && row.district != _selectedDistrict) {
        return false;
      }
      if (query.isEmpty) return true;
      return row.cropName.toLowerCase().contains(query) ||
          row.marketName.toLowerCase().contains(query) ||
          row.district.toLowerCase().contains(query) ||
          row.sourceName.toLowerCase().contains(query);
    }).toList();
  }

  List<_CsvRateRow> _parseCsvRows(String text) {
    final lines =
        text
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
    if (lines.isEmpty) return const [];

    List<String> splitCsv(String line) =>
        line.split(',').map((e) => e.trim()).toList();

    final header = splitCsv(lines.first).map((h) => h.toLowerCase()).toList();
    final cropIdx = header.indexWhere((h) => h == 'cropname' || h == 'crop');
    final marketIdx = header.indexWhere((h) => h == 'marketname');
    final districtIdx = header.indexWhere((h) => h == 'district');
    final minIdx = header.indexWhere((h) => h == 'minprice');
    final maxIdx = header.indexWhere((h) => h == 'maxprice');
    final unitIdx = header.indexWhere((h) => h == 'unit');

    final rows = <_CsvRateRow>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = splitCsv(lines[i]);
      String at(int idx) => (idx >= 0 && idx < cols.length) ? cols[idx] : '';
      final crop = at(cropIdx);
      final district = at(districtIdx);
      if (crop.isEmpty || district.isEmpty) continue;
      rows.add(
        _CsvRateRow(
          cropName: crop,
          marketName: at(marketIdx),
          district: district,
          minPrice: at(minIdx),
          maxPrice: at(maxIdx),
          unit: at(unitIdx),
        ),
      );
    }
    return rows;
  }

  String _csvEscape(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  String _buildTemplateCsv() {
    final rows = <List<String>>[
      [
        'cropName',
        'marketName',
        'district',
        'minPrice',
        'maxPrice',
        'unit',
        'sourceName',
        'sourceUrl',
        'rateDate',
      ],
      [
        'Wheat',
        'Lahore Market',
        'Lahore',
        '3000',
        '3200',
        '40kg',
        'manual',
        '',
        DateTime.now().toIso8601String(),
      ],
    ];
    return rows
        .map((row) => row.map(_csvEscape).join(','))
        .join('\n');
  }

  Future<void> _saveCsvText({
    required String suggestedName,
    required String csvText,
    required String successMessage,
  }) async {
    final csvGroup = XTypeGroup(label: 'csv', extensions: ['csv']);
    final csvFile = XFile.fromData(
      Uint8List.fromList(utf8.encode(csvText)),
      name: suggestedName,
      mimeType: 'text/csv',
    );

    try {
      String? savedPath;
      String? pickedPath;

      try {
        final saveLocation = await getSaveLocation(
          acceptedTypeGroups: [csvGroup],
          suggestedName: suggestedName,
        );
        pickedPath = saveLocation?.path;
      } catch (_) {
        // getSaveLocation is not implemented on some platforms (for example Android).
        pickedPath = null;
      }

      if (pickedPath != null) {
        await csvFile.saveTo(pickedPath);
        savedPath = pickedPath;
      } else {
        final externalDir = await getExternalStorageDirectory();
        final fallbackDir = externalDir ?? await getApplicationDocumentsDirectory();
        final fallbackPath = '${fallbackDir.path}/$suggestedName';
        await csvFile.saveTo(fallbackPath);
        savedPath = fallbackPath;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successMessage\n$savedPath')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t(context, 'CSV save failed', 'CSV محفوظ نہیں ہو سکی')}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _downloadAllRatesCsv(List<CropRateDto> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context, 'No rates available to export', 'برآمد کرنے کے لیے کوئی ریٹ موجود نہیں'))),
      );
      return;
    }

    final csv = await _api.downloadRatesCsv(
      crop: _selectedCrop,
      district: _selectedDistrict,
    );
    await _saveCsvText(
      suggestedName: 'official_rates.csv',
      csvText: csv,
      successMessage: _t(context, 'CSV downloaded successfully', 'CSV کامیابی سے ڈاؤن لوڈ ہو گئی'),
    );
  }

  Future<void> _downloadTemplateCsv() async {
    await _saveCsvText(
      suggestedName: 'official_rates_template.csv',
      csvText: _buildTemplateCsv(),
      successMessage: _t(context, 'Template downloaded successfully', 'ٹیمپلیٹ کامیابی سے ڈاؤن لوڈ ہو گئی'),
    );
  }

  Future<bool> _confirmCsvPreview({
    required List<_CsvRateRow> rows,
    required String fileName,
  }) async {
    final preview = rows.take(10).toList();
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: Text(_t(context, 'Review CSV before upload', 'اپ لوڈ سے پہلے CSV کا جائزہ لیں')),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_t(context, 'File', 'فائل')}: $fileName'),
                      const SizedBox(height: 4),
                      Text('${_t(context, 'Valid rows', 'درست قطاریں')}: ${rows.length}'),
                      const SizedBox(height: 12),
                      if (preview.isEmpty)
                        Text(
                          _t(context, 'No valid rows found in CSV.', 'CSV میں کوئی درست قطار نہیں ملی۔'),
                        )
                      else
                        DataTable(
                          columns: [
                            DataColumn(label: Text(_t(context, 'Crop', 'فصل'))),
                            DataColumn(label: Text(_t(context, 'District', 'ضلع'))),
                            DataColumn(label: Text(_t(context, 'Market', 'مارکیٹ'))),
                            DataColumn(label: Text(_t(context, 'Min', 'کم'))),
                            DataColumn(label: Text(_t(context, 'Max', 'زیادہ'))),
                          ],
                          rows:
                              preview
                                  .map(
                                    (r) => DataRow(
                                      cells: [
                                        DataCell(Text(r.cropName)),
                                        DataCell(Text(r.district)),
                                        DataCell(Text(r.marketName)),
                                        DataCell(Text(r.minPrice)),
                                        DataCell(Text(r.maxPrice)),
                                      ],
                                    ),
                                  )
                                  .toList(),
                        ),
                      if (rows.length > preview.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _t(
                              context,
                              'Showing first ${preview.length} rows only.',
                              'صرف پہلی ${preview.length} قطاریں دکھائی جا رہی ہیں۔',
                            ),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(_t(context, 'Cancel', 'منسوخ')),
                ),
                ElevatedButton(
                  onPressed: rows.isEmpty ? null : () => Navigator.of(ctx).pop(true),
                  child: Text(_t(context, 'Upload', 'اپ لوڈ کریں')),
                ),
              ],
            );
          },
        ) ??
        false;
    return accepted;
  }

  Future<void> _openAddRateScreen() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdminRateFormScreen(api: _api),
      ),
    );
    if (created == true) _reload();
  }

  Future<void> _openEditRateScreen(CropRateDto rate) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdminRateFormScreen(
          api: _api,
          initial: rate,
        ),
      ),
    );
    if (updated == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CropRateDto>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AsyncLoadingWidget(
            message: _t(context, 'Loading rates...', 'ریٹس لوڈ ہو رہے ہیں...'),
          );
        }
        if (snapshot.hasError) {
          return AsyncErrorWidget(
            error: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final rows = snapshot.data ?? const <CropRateDto>[];
        final cropOptions = _optionsFrom(rows.map((row) => row.cropName));
        final districtOptions = _optionsFrom(rows.map((row) => row.district));
        final selectedCropValue = cropOptions.contains(_selectedCrop) ? _selectedCrop : null;
        final selectedDistrictValue = districtOptions.contains(_selectedDistrict) ? _selectedDistrict : null;
        final filteredRows = _applyFilters(rows);
        final itemCount = filteredRows.isEmpty ? 3 : filteredRows.length + 2;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              if (index == 0) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, 'Add new market rate', 'نیا مارکیٹ ریٹ شامل کریں'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryMid,
                                side: const BorderSide(color: AppColors.primaryMid),
                                backgroundColor: AppColors.surface,
                              ),
                              icon: const Icon(Icons.description_outlined),
                              label: Text(_t(context, 'Template CSV', 'ٹیمپلیٹ CSV')),
                              onPressed: _downloadTemplateCsv,
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryMid,
                                side: const BorderSide(color: AppColors.primaryMid),
                                backgroundColor: AppColors.surface,
                              ),
                              icon: const Icon(Icons.download),
                              label: Text(_t(context, 'Download Filtered CSV', 'فلٹر شدہ CSV ڈاؤن لوڈ')),
                              onPressed: () => _downloadAllRatesCsv(rows),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryMid,
                                side: const BorderSide(color: AppColors.primaryMid),
                                backgroundColor: AppColors.surface,
                              ),
                              icon: const Icon(Icons.upload_file),
                              label: Text(_t(context, 'Bulk CSV', 'سی وی ایس اپ لوڈ')),
                              onPressed: () => _onBulkUploadPressed(),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryMid,
                                foregroundColor: AppColors.white,
                              ),
                              icon: const Icon(Icons.add),
                              label: Text(_t(context, 'Add', 'شامل کریں')),
                              onPressed: _openAddRateScreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (index == 1) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            labelText: _t(context, 'Search crop/market/district', 'فصل/مارکیٹ/ضلع تلاش کریں'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: selectedCropValue,
                                style: const TextStyle(color: AppColors.textPrimary),
                                dropdownColor: AppColors.surface,
                                iconEnabledColor: AppColors.textSecondary,
                                decoration: InputDecoration(
                                  labelText: _t(context, 'Crop', 'فصل'),
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      _t(context, 'All crops', 'تمام فصلیں'),
                                      style: const TextStyle(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  ...cropOptions.map(
                                    (c) => DropdownMenuItem<String?>(
                                      value: c,
                                      child: Text(c, style: const TextStyle(color: AppColors.textPrimary)),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  _selectedCrop = v;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: selectedDistrictValue,
                                style: const TextStyle(color: AppColors.textPrimary),
                                dropdownColor: AppColors.surface,
                                iconEnabledColor: AppColors.textSecondary,
                                decoration: InputDecoration(
                                  labelText: _t(context, 'District', 'ضلع'),
                                  border: const OutlineInputBorder(),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      _t(context, 'All districts', 'تمام اضلاع'),
                                      style: const TextStyle(color: AppColors.textPrimary),
                                    ),
                                  ),
                                  ...districtOptions.map(
                                    (d) => DropdownMenuItem<String?>(
                                      value: d,
                                      child: Text(d, style: const TextStyle(color: AppColors.textPrimary)),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  _selectedDistrict = v;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (filteredRows.isEmpty && index == 2) {
                return AsyncEmptyWidget(
                  message: _t(context, 'No rates match your filters', 'کوئی ریٹ فلٹر سے مطابقت نہیں رکھتا'),
                );
              }
              final row = filteredRows[index - 2];
              return Card(
                child: ListTile(
                  title: Text(
                    '${row.cropName} • ${row.marketName}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    '${row.district} • ${row.sourceName}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${row.minPrice.toStringAsFixed(0)}-${row.maxPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: _t(context, 'Edit rate', 'ریٹ ترمیم کریں'),
                        onPressed: () => _openEditRateScreen(row),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _onBulkUploadPressed() async {
    try {
      final XTypeGroup csvGroup = XTypeGroup(label: 'csv', extensions: ['csv']);
      final XFile? result = await openFile(acceptedTypeGroups: [csvGroup]);
      if (result == null) return;
      final path = result.path;
      if (path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t(context, 'Unable to access selected file', 'فائل تک رسائی ممکن نہیں'))));
        return;
      }

      final csvText = await result.readAsString();
      final parsedRows = _parseCsvRows(csvText);
      final confirmed = await _confirmCsvPreview(
        rows: parsedRows,
        fileName: result.name,
      );
      if (!confirmed) return;

      // show progress dialog
      showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

      final resp = await _api.uploadRatesCsv(path);

      Navigator.of(context).pop(); // dismiss progress

      final message = resp['message'] ?? 'Upload complete';
      final inserted = resp['inserted']?.toString() ?? '0';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$message ($inserted)')));
      _reload();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_t(context, 'Upload failed', 'اپ لوڈ ناکام')}: $e')));
    }
  }
}

class _AdminRateFormScreen extends StatefulWidget {
  const _AdminRateFormScreen({
    required this.api,
    this.initial,
  });

  final AdminApiService api;
  final CropRateDto? initial;

  @override
  State<_AdminRateFormScreen> createState() => _AdminRateFormScreenState();
}

class _AdminRateFormScreenState extends State<_AdminRateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cropController;
  late final TextEditingController _marketController;
  late final TextEditingController _districtController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final TextEditingController _unitController;
  late final TextEditingController _sourceController;

  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _cropController = TextEditingController(text: initial?.cropName ?? '');
    _marketController = TextEditingController(text: initial?.marketName ?? '');
    _districtController = TextEditingController(text: initial?.district ?? '');
    _minController = TextEditingController(
      text: initial != null ? initial.minPrice.toStringAsFixed(0) : '',
    );
    _maxController = TextEditingController(
      text: initial != null ? initial.maxPrice.toStringAsFixed(0) : '',
    );
    _unitController = TextEditingController(text: initial?.unit ?? '40kg');
    _sourceController = TextEditingController(text: initial?.sourceName ?? 'manual');
  }

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void dispose() {
    _cropController.dispose();
    _marketController.dispose();
    _districtController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _unitController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final min = double.parse(_minController.text.trim());
    final max = double.parse(_maxController.text.trim());
    if (max < min) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(context, 'Max must be >= min', 'زیادہ سے زیادہ کم سے بڑا ہونا چاہیے'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      if (_isEdit) {
        await widget.api.updateRate(
          id: widget.initial!.id,
          cropName: _cropController.text.trim(),
          marketName: _marketController.text.trim(),
          district: _districtController.text.trim(),
          minPrice: min,
          maxPrice: max,
          unit: _unitController.text.trim(),
          sourceName: _sourceController.text.trim(),
        );
      } else {
        await widget.api.createRate(
          cropName: _cropController.text.trim(),
          marketName: _marketController.text.trim(),
          district: _districtController.text.trim(),
          minPrice: min,
          maxPrice: max,
          unit: _unitController.text.trim(),
          sourceName: _sourceController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t(context, 'Save failed', 'محفوظ ناکام')}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  InputDecoration _decoration(BuildContext context, String labelEn, String labelUr) {
    return InputDecoration(
      labelText: _t(context, labelEn, labelUr),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryMid, width: 2),
      ),
      filled: true,
      fillColor: AppColors.surface,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t(
            context,
            _isEdit ? 'Edit Official Rate' : 'Add Official Rate',
            _isEdit ? 'سرکاری ریٹ ترمیم کریں' : 'سرکاری ریٹ شامل کریں',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _cropController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(context, 'Crop name', 'فصل کا نام'),
                  validator: (v) => (v ?? '').trim().isEmpty ? _t(context, 'Required', 'ضروری') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _marketController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(context, 'Market name', 'مارکیٹ کا نام'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _districtController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(context, 'District', 'ضلع'),
                  validator: (v) => (v ?? '').trim().isEmpty ? _t(context, 'Required', 'ضروری') : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: TextInputType.number,
                        decoration: _decoration(context, 'Min price', 'کم سے کم قیمت'),
                        validator: (v) => double.tryParse(v ?? '') == null ? _t(context, 'Invalid number', 'غلط نمبر') : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: TextInputType.number,
                        decoration: _decoration(context, 'Max price', 'زیادہ سے زیادہ قیمت'),
                        validator: (v) => double.tryParse(v ?? '') == null ? _t(context, 'Invalid number', 'غلط نمبر') : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unitController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(context, 'Unit', 'یونٹ'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sourceController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(context, 'Source name', 'ماخذ کا نام'),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _t(
                      context,
                      _saving
                          ? 'Saving...'
                          : (_isEdit ? 'Update Rate' : 'Save Rate'),
                      _saving
                          ? 'محفوظ ہو رہا ہے...'
                          : (_isEdit ? 'ریٹ اپڈیٹ کریں' : 'ریٹ محفوظ کریں'),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMid,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
