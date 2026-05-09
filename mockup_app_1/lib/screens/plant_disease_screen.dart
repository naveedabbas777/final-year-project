import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/providers/plant_disease_provider.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';
import 'package:provider/provider.dart';

class PlantDiseaseScreen extends StatefulWidget {
  const PlantDiseaseScreen({super.key});

  @override
  State<PlantDiseaseScreen> createState() => _PlantDiseaseScreenState();
}

class _PlantDiseaseScreenState extends State<PlantDiseaseScreen> {
  Uint8List? _pickedImage;

  String _t(String en, String ur) {
    return Localizations.localeOf(context).languageCode == 'ur' ? ur : en;
  }

  Future<void> _pickAndClassify() async {
    if (kIsWeb) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _pickedImage = bytes);
    await context.read<PlantDiseaseProvider>().classifyBytes(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantDiseaseProvider>();
    final unsupportedText =
        kIsWeb
            ? _t(
                'Plant disease detection is not supported on web. Please run on Android/iOS.',
                'ویب پر پودوں کی بیماری کی شناخت دستیاب نہیں۔ براہ کرم Android/iOS پر چلائیں۔',
              )
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Plant Disease Detector', 'پودوں کی بیماری معلوم کرنے والا')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unsupportedText != null)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    unsupportedText,
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              ),
            if (_pickedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pickedImage!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: provider.isLoading || kIsWeb ? null : _pickAndClassify,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_t('Pick image from gallery', 'گیلری سے تصویر منتخب کریں')),
            ),
            const SizedBox(height: 16),
            if (provider.isLoading)
              const AsyncLoadingWidget()
            else if (provider.error != null)
              Text(provider.error!, style: const TextStyle(color: AppColors.red))
            else if (provider.predictions.isEmpty)
              Text(_t('Pick an image to get disease prediction.', 'بیماری کی پیش گوئی کے لیے تصویر منتخب کریں۔'))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: provider.predictions.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final p = provider.predictions[index];
                    final score = (p.score * 100)
                        .clamp(0, 100)
                        .toStringAsFixed(1);
                    return ListTile(
                      title: Text(p.label),
                      trailing: Text('$score%'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
