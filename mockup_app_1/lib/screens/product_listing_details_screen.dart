import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockup_app/config/app_theme.dart';
import 'package:mockup_app/utils/form_validators.dart';
import '../services/market_api_service.dart';
import '../utils/error_presenter.dart';
import 'listing_location_picker.dart';

class ProductListingDetailsScreen extends StatefulWidget {
  const ProductListingDetailsScreen({Key? key}) : super(key: key);

  @override
  State<ProductListingDetailsScreen> createState() =>
      _ProductListingDetailsScreenState();
}

class _ProductListingDetailsScreenState
    extends State<ProductListingDetailsScreen> {
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
  String? _selectedLocationName;

  String _t(String en, String ur) =>
      Localizations.localeOf(context).languageCode == 'ur' ? ur : en;

  InputDecoration _fieldDecoration(
    String label,
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
      ),
      prefixIcon: Icon(icon),
    );
  }

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
        _selectedLocationName = result['locationName'];
        // Auto-populate district field if available
        if (result['district'] != null && result['district'].isNotEmpty) {
          _districtController.text = result['district'];
        }
      });
    }
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t(
            'Please select at least one image',
            'براہ کرم کم از کم ایک تصویر منتخب کریں',
          )),
        ),
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
        qualityGrade:
            _gradeController.text.trim().isEmpty
                ? 'A'
                : _gradeController.text.trim(),
        unit:
            _unitController.text.trim().isEmpty
                ? '40kg'
                : _unitController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrls: imageUrls,
        latitude: _selectedLatitude,
        longitude: _selectedLongitude,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Listing created successfully', 'لسٹنگ کامیابی سے بن گئی'),
          ),
        ),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_t('Create Product Listing', 'پروڈکٹ لسٹنگ بنائیں')),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== IMAGES SECTION =====
              Text(
                _t('Product Images', 'پروڈکٹ تصاویر'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_selectedImages.isEmpty)
                      Column(
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _t('No images selected', 'کوئی تصویر منتخب نہیں'),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int i = 0; i < _selectedImages.length; i++)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_selectedImages[i].path),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(i),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
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
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        _t('Select Images (up to 5)', 'تصاویر منتخب کریں (زیادہ سے زیادہ 5)'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ===== CROP DETAILS SECTION =====
              Text(
                _t('Crop Details', 'فصل کی تفصیلات'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cropController,
                style: const TextStyle(color: Colors.black87),
                cursorColor: Colors.green,
                decoration: _fieldDecoration(
                  _t('Crop Name *', 'فصل کا نام *'),
                  _t('e.g., Wheat, Rice', 'مثلاً گندم، چاول'),
                  Icons.grass_outlined,
                ),
                validator: (v) {
                  if ((v?.trim() ?? '').isEmpty) {
                    return _t('Unit is required', 'یونٹ ضروری ہے');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _districtController,
                style: const TextStyle(color: Colors.black87),
                cursorColor: Colors.green,
                decoration: _fieldDecoration(
                  _t('District *', 'ضلع *'),
                  _t('e.g., Punjab', 'مثلاً پنجاب'),
                  Icons.location_on_outlined,
                ),
                validator: (v) =>
                    FormValidators.validateDistrict(v?.trim() ?? ''),
              ),
              const SizedBox(height: 24),

              // ===== QUANTITY & PRICING SECTION =====
              Text(
                _t('Quantity & Pricing', 'مقدار اور قیمت'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                        style: const TextStyle(color: Colors.black87),
                        cursorColor: Colors.green,
                      keyboardType: TextInputType.number,
                        decoration: _fieldDecoration(
                          _t('Quantity *', 'مقدار *'),
                          '',
                          Icons.inventory_outlined,
                        ),
                      validator: (v) =>
                          FormValidators.validateQuantity(v?.trim() ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _unitController,
                        style: const TextStyle(color: Colors.black87),
                        cursorColor: Colors.green,
                        decoration: _fieldDecoration(
                          _t('Unit *', 'یونٹ *'),
                          '40kg',
                          Icons.scale_outlined,
                        ),
                      validator: (v) {
                          if ((v?.trim() ?? '').isEmpty) {
                          return _t('Unit is required', 'یونٹ ضروری ہے');
                          }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                style: const TextStyle(color: Colors.black87),
                cursorColor: Colors.green,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration(
                  _t('Asking Price (per unit) *', 'مانگی گئی قیمت (فی یونٹ) *'),
                  '',
                  Icons.attach_money_outlined,
                ),
                validator: (v) =>
                    FormValidators.validatePrice(v?.trim() ?? ''),
              ),
              const SizedBox(height: 24),

              // ===== QUALITY SECTION =====
              Text(
                _t('Quality Grade', 'معیار کی درجہ بندی'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _gradeController,
                style: const TextStyle(color: Colors.black87),
                cursorColor: Colors.green,
                decoration: _fieldDecoration(
                  _t('Grade *', 'درجہ *'),
                  'A',
                  Icons.stars_outlined,
                ).copyWith(
                  helperText: _t('e.g., A, B, C', 'مثلاً A، B، C'),
                ),
                validator: (v) {
                  if ((v?.trim() ?? '').isEmpty) {
                    return _t('Grade is required', 'درجہ ضروری ہے');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ===== DESCRIPTION SECTION =====
              Text(
                _t('Description', 'تفصیل'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.black87),
                cursorColor: Colors.green,
                decoration: _fieldDecoration(
                  _t('Product Details', 'پروڈکٹ کی تفصیلات'),
                  _t(
                    'Describe the condition, variety, storage info, etc.',
                    'حالت، اقسام، اسٹوریج کی معلومات وغیرہ بیان کریں',
                  ),
                  Icons.description_outlined,
                ),
              ),
              const SizedBox(height: 24),

              // ===== LOCATION SECTION =====
              Text(
                _t('Location', 'مقام'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (_selectedLatitude != null && _selectedLongitude != null)
                      Column(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: Colors.blue.shade700,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          if (_selectedLocationName != null &&
                              _selectedLocationName!.isNotEmpty)
                            Column(
                              children: [
                                Text(
                                  _selectedLocationName!,
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          Text(
                            _t('Location selected', 'مقام منتخب ہو گیا'),
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedLatitude!.toStringAsFixed(4)}, ${_selectedLongitude!.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            color: Colors.grey.shade400,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t('No location selected', 'کوئی مقام منتخب نہیں'),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        _t(
                          'Pick Location on Map',
                          'نقشے پر مقام منتخب کریں',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ===== SUBMIT BUTTON =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitListing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _submitting
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Text(
                        _t('Create Listing', 'لسٹنگ بنائیں'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
