import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/widgets/async_state_widgets.dart';

import '../services/market_api_service.dart';
import '../utils/error_presenter.dart';
import '../utils/form_validators.dart';
import 'listing_location_picker.dart';

class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _service = MarketApiService();
  final _formKey = GlobalKey<FormState>();

  final _cropController = TextEditingController();
  final _districtController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController(text: '40kg');
  final _gradeController = TextEditingController(text: 'A');
  final _descriptionController = TextEditingController();
  
  final List<XFile> _selectedImages = [];
  bool _submitting = false;
  double? _selectedLatitude;
  double? _selectedLongitude;

  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  @override
  void dispose() {
    _cropController.dispose();
    _districtController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _gradeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(limit: 5);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _selectedImages
        ..clear()
        ..addAll(picked);
    });
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const ListingLocationPicker()),
    );
    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
      });
    }
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please select at least one image', 'براہ کرم کم از کم ایک تصویر منتخب کریں'))),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final imageUrls = <String>[];
      for (final image in _selectedImages) {
        imageUrls.add(await _service.uploadListingImage(image.path));
      }

      await _service.createListing(
        cropName: _cropController.text.trim(),
        district: _districtController.text.trim(),
        quantity: double.tryParse(_qtyController.text.trim()) ?? 0.0,
        askingPrice: double.tryParse(_priceController.text.trim()) ?? 0.0,
        qualityGrade: _gradeController.text.trim().isEmpty ? 'A' : _gradeController.text.trim(),
        unit: _unitController.text.trim().isEmpty ? '40kg' : _unitController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Listing created successfully', 'لسٹنگ کامیابی سے بن گئی'))),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorPresenter.present(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Create New Listing', 'نئی لسٹنگ بنائیں')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Upload Section
                Text(
                  _t('Product Images', 'پروڈکٹ تصاویر'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.green.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.green.shade50,
                    ),
                    child: _selectedImages.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 40,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _t('Tap to upload images', 'تصاویر اپ لوڈ کریں'),
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _t('(Max 5 images)', '(زیادہ سے زیادہ 5 تصاویر)'),
                                style: TextStyle(
                                  color: Colors.green.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _selectedImages.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(
                                            File(_selectedImages[index].path),
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade600,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Crop Name
                Text(
                  _t('Product Details', 'پروڈکٹ کی تفصیلات'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cropController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorColor: AppColors.primaryMid,
                  decoration: InputDecoration(
                    labelText: _t('Crop Name', 'فصل کا نام'),
                    prefixIcon: Icon(Icons.agriculture, color: Colors.green.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) =>
                      FormValidators.validateCropName(v?.trim() ?? ''),
                ),
                const SizedBox(height: 12),

                // Quantity Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _qtyController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        cursorColor: AppColors.primaryMid,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _t('Quantity', 'مقدار'),
                          prefixIcon: Icon(Icons.scale, color: Colors.green.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (v) =>
                            FormValidators.validateQuantity(v?.trim() ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _unitController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        cursorColor: AppColors.primaryMid,
                        decoration: InputDecoration(
                          labelText: _t('Unit', 'یونٹ'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? _t('Unit is required', 'یونٹ ضروری ہے')
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Grade and Price Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _gradeController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        cursorColor: AppColors.primaryMid,
                        decoration: InputDecoration(
                          labelText: _t('Quality Grade', 'معیار کی جماعت'),
                          prefixIcon: Icon(Icons.star, color: Colors.green.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? _t('Grade is required', 'گریڈ ضروری ہے')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        cursorColor: AppColors.primaryMid,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _t('Price (PKR)', 'قیمت (پاکستانی روپے)'),
                          prefixIcon: Icon(Icons.currency_rupee, color: Colors.green.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (v) =>
                            FormValidators.validatePrice(v?.trim() ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Location Section
                Text(
                  _t('Location', 'مقام'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _districtController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorColor: AppColors.primaryMid,
                  readOnly: true,
                  onTap: _pickLocation,
                  decoration: InputDecoration(
                    labelText: _t('District', 'ضلع'),
                    prefixIcon: Icon(Icons.location_on, color: Colors.green.shade600),
                    suffixIcon: Icon(Icons.arrow_forward, color: Colors.green.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) =>
                      FormValidators.validateDistrict(v?.trim() ?? ''),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  _t('Description', 'تفصیل'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorColor: AppColors.primaryMid,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: _t('Add description (optional)', 'تفصیل شامل کریں (اختیاری)'),
                    prefixIcon: Icon(Icons.description, color: Colors.green.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitListing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _t('Create Listing', 'لسٹنگ بنائیں'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
