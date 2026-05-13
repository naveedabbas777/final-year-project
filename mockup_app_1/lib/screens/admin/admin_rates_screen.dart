import 'package:flutter/material.dart';
import 'package:mockup_app/services/admin_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/services/market_api_service.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

class AdminRatesScreen extends StatefulWidget {
  const AdminRatesScreen({super.key});

  @override
  State<AdminRatesScreen> createState() => _AdminRatesScreenState();
}

class _AdminRatesScreenState extends State<AdminRatesScreen> {
  final _api = AdminApiService();
  Future<List<CropRateDto>>? _future;

  String _t(BuildContext context, String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _future = _api.fetchRates(limit: 200));
  }

  Future<void> _showEditDialog(BuildContext context, CropRateDto? initial) async {
    final cropController = TextEditingController(text: initial?.cropName ?? '');
    final marketController = TextEditingController(text: initial?.marketName ?? '');
    final districtController = TextEditingController(text: initial?.district ?? '');
    final minController = TextEditingController(text: initial != null ? initial.minPrice.toStringAsFixed(0) : '');
    final maxController = TextEditingController(text: initial != null ? initial.maxPrice.toStringAsFixed(0) : '');
    final unitController = TextEditingController(text: initial?.unit ?? '40kg');
    final sourceController = TextEditingController(text: initial?.sourceName ?? 'manual');

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(context, initial == null ? 'Add rate' : 'Edit rate', initial == null ? 'ریٹ شامل کریں' : 'ریٹ ترمیم کریں')),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(decoration: InputDecoration(labelText: _t(context, 'Crop name', 'فصل کا نام')), controller: cropController, validator: (v) => (v ?? '').trim().isEmpty ? _t(context, 'Required', 'ضروری') : null),
                TextFormField(decoration: InputDecoration(labelText: _t(context, 'Market name', 'مارکیٹ')), controller: marketController),
                TextFormField(decoration: InputDecoration(labelText: _t(context, 'District', 'ضلع')), controller: districtController),
                Row(children: [Expanded(child: TextFormField(decoration: InputDecoration(labelText: _t(context, 'Min price', 'کم سے کم قیمت')), keyboardType: TextInputType.number, controller: minController, validator: (v) => double.tryParse(v ?? '') == null ? _t(context, 'Invalid number', 'غلط نمبر') : null)), const SizedBox(width: 8), Expanded(child: TextFormField(decoration: InputDecoration(labelText: _t(context, 'Max price', 'زیادہ سے زیادہ قیمت')), keyboardType: TextInputType.number, controller: maxController, validator: (v) => double.tryParse(v ?? '') == null ? _t(context, 'Invalid number', 'غلط نمبر') : null))]),
                TextFormField(decoration: InputDecoration(labelText: _t(context, 'Unit', 'یونٹ')), controller: unitController),
                TextFormField(decoration: InputDecoration(labelText: _t(context, 'Source name', 'ماخذ کا نام')), controller: sourceController),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_t(context, 'Cancel', 'منسوخ'))),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final min = double.parse(minController.text.trim());
              final max = double.parse(maxController.text.trim());
              if (max < min) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t(context, 'Max must be >= min', 'زیادہ سے زیادہ کم سے بڑا ہونا چاہیے'))));
                return;
              }
              try {
                if (initial == null) {
                  await _api.createRate(
                    cropName: cropController.text.trim(),
                    marketName: marketController.text.trim(),
                    district: districtController.text.trim(),
                    minPrice: min,
                    maxPrice: max,
                    unit: unitController.text.trim(),
                    sourceName: sourceController.text.trim(),
                  );
                } else {
                  await _api.updateRate(
                    id: initial.id,
                    cropName: cropController.text.trim(),
                    marketName: marketController.text.trim(),
                    district: districtController.text.trim(),
                    minPrice: min,
                    maxPrice: max,
                    unit: unitController.text.trim(),
                    sourceName: sourceController.text.trim(),
                  );
                }
                Navigator.of(ctx).pop(true);
              } catch (e) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(SnackBar(content: Text('${_t(context, 'Save failed', 'محفوظ ناکام')}: $e')));
              }
            },
            child: Text(_t(context, 'Save', 'محفوظ کریں')),
          ),
        ],
      ),
    );

    if (result == true) _reload();
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
        if (rows.isEmpty) {
          return AsyncEmptyWidget(
            message: _t(context, 'No rates found', 'کوئی ریٹ نہیں ملا'),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              if (index == 0) {
                return Card(
                  child: ListTile(
                    title: Text(_t(context, 'Add new market rate', 'نیا مارکیٹ ریٹ شامل کریں'), style: const TextStyle(color: AppColors.textPrimary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file),
                            label: Text(_t(context, 'Bulk CSV', 'سی وی ایس اپ لوڈ')),
                            onPressed: () => _onBulkUploadPressed(),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text(_t(context, 'Add', 'شامل کریں')),
                            onPressed: () => _showEditDialog(context, null),
                          ),
                        ],
                      ),
                  ),
                );
              }
              final row = rows[index - 1];
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
                        onPressed: () => _showEditDialog(context, row),
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Select CSV file',
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final path = file.path;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t(context, 'Unable to access selected file', 'فائل تک رسائی ممکن نہیں'))));
        return;
      }

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
