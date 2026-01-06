import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/measurement.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/measurement_repository.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_card.dart';

class AddMeasurementScreen extends StatefulWidget {
  final Member member;

  const AddMeasurementScreen({
    super.key,
    required this.member,
  });

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = MeasurementRepository();
  bool _isLoading = false;

  // Controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _boneMassController = TextEditingController();
  final _waterPercentageController = TextEditingController();
  final _metabolicAgeController = TextEditingController();
  final _visceralFatController = TextEditingController();
  final _bmrController = TextEditingController();
  
  // Circumference Controllers
  final _chestController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipsController = TextEditingController();
  final _leftArmController = TextEditingController();
  final _rightArmController = TextEditingController();
  final _leftThighController = TextEditingController();
  final _rightThighController = TextEditingController();
  // Calves removed
  
  final _notesController = TextEditingController();
  
  // Date
  DateTime _selectedDate = DateTime.now();

  // Photos
  File? _frontPhoto;
  File? _sidePhoto;
  File? _backPhoto;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _bodyFatController.dispose();
    _boneMassController.dispose();
    _waterPercentageController.dispose();
    _metabolicAgeController.dispose();
    _visceralFatController.dispose();
    _bmrController.dispose();
    _chestController.dispose();
    _waistController.dispose();
    _hipsController.dispose();
    _leftArmController.dispose();
    _rightArmController.dispose();
    _leftThighController.dispose();
    _rightThighController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String position) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          switch (position) {
            case 'front':
              _frontPhoto = File(image.path);
              break;
            case 'side':
              _sidePhoto = File(image.path);
              break;
            case 'back':
              _backPhoto = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      CustomSnackBar.showError(context, 'Fotoğraf seçilirken hata oluştu: $e');
    }
  }

  Future<void> _saveMeasurement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Create measurement object without photos first
      var measurement = Measurement(
        memberId: widget.member.id,
        date: _selectedDate,
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
        age: _ageController.text.isNotEmpty ? int.parse(_ageController.text) : null, // Added Age
        bodyFatPercentage: _bodyFatController.text.isNotEmpty 
            ? double.parse(_bodyFatController.text) : null,
        boneMass: _boneMassController.text.isNotEmpty ? double.parse(_boneMassController.text) : null,
        waterPercentage: _waterPercentageController.text.isNotEmpty ? double.parse(_waterPercentageController.text) : null,
        metabolicAge: _metabolicAgeController.text.isNotEmpty ? int.parse(_metabolicAgeController.text) : null,
        visceralFatRating: _visceralFatController.text.isNotEmpty ? double.parse(_visceralFatController.text) : null,
        basalMetabolicRate: _bmrController.text.isNotEmpty ? int.parse(_bmrController.text) : null,
        chest: _chestController.text.isNotEmpty ? double.parse(_chestController.text) : null,
        waist: _waistController.text.isNotEmpty ? double.parse(_waistController.text) : null,
        hips: _hipsController.text.isNotEmpty ? double.parse(_hipsController.text) : null,
        leftArm: _leftArmController.text.isNotEmpty ? double.parse(_leftArmController.text) : null,
        rightArm: _rightArmController.text.isNotEmpty ? double.parse(_rightArmController.text) : null,
        leftThigh: _leftThighController.text.isNotEmpty ? double.parse(_leftThighController.text) : null,
        rightThigh: _rightThighController.text.isNotEmpty ? double.parse(_rightThighController.text) : null,
        // Calves removed
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // 2. Save to DB to get ID
      measurement = await _repository.create(measurement);

      // 3. Upload photos if selected
      String? frontUrl;
      String? sideUrl;
      String? backUrl;

      if (_frontPhoto != null) {
        frontUrl = await _repository.uploadPhoto(
          widget.member.id, 
          measurement.id!, 
          _frontPhoto!,
          'front',
        );
      }
      
      if (_sidePhoto != null) {
        sideUrl = await _repository.uploadPhoto(
          widget.member.id, 
          measurement.id!, 
          _sidePhoto!,
          'side',
        );
      }
      
      if (_backPhoto != null) {
        backUrl = await _repository.uploadPhoto(
          widget.member.id, 
          measurement.id!, 
          _backPhoto!,
          'back',
        );
      }

      // 4. Update measurement with photo URLs if any uploaded
      if (frontUrl != null || sideUrl != null || backUrl != null) {
        final updatedMeasurement = Measurement(
          id: measurement.id,
          memberId: measurement.memberId,
          date: measurement.date,
          weight: measurement.weight,
          height: measurement.height,
          bodyFatPercentage: measurement.bodyFatPercentage,
          chest: measurement.chest,
          waist: measurement.waist,
          hips: measurement.hips,
          leftArm: measurement.leftArm,
          rightArm: measurement.rightArm,
          leftThigh: measurement.leftThigh,
          rightThigh: measurement.rightThigh,
          frontPhotoUrl: frontUrl ?? measurement.frontPhotoUrl,
          sidePhotoUrl: sideUrl ?? measurement.sidePhotoUrl,
          backPhotoUrl: backUrl ?? measurement.backPhotoUrl,
          notes: measurement.notes,
        );
        
        await _repository.update(updatedMeasurement);
      }

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Ölçüm başarıyla kaydedildi');
        Navigator.pop(context, true); // Return true to refresh list
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryYellow,
              onPrimary: Colors.black,
              surface: AppColors.surfaceDark,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.surfaceDark,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member.name),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Tarih'),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: AppTextStyles.body,
                        ),
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primaryYellow),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Temel Ölçümler'),
                GlassCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildNumberInput(_weightController, 'Kilo (kg)', required: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildNumberInput(_heightController, 'Boy (cm)', required: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildNumberInput(_ageController, 'Yaş', isInteger: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildNumberInput(_bodyFatController, 'Yağ Oranı (%)')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildNumberInput(_waterPercentageController, 'Su (%)')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildNumberInput(_boneMassController, 'Kemik (kg)')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildNumberInput(_visceralFatController, 'Visceral Yağ')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildNumberInput(_metabolicAgeController, 'Metabolik Yaş', isInteger: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildNumberInput(_bmrController, 'Metabolizma Hızı (kcal)', isInteger: true),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Çevre Ölçümleri (cm)'),
                GlassCard(
                  child: Column(
                    children: [
                      _buildNumberInput(_chestController, 'Göğüs'),
                      const SizedBox(height: 12),
                      _buildNumberInput(_waistController, 'Bel'),
                      const SizedBox(height: 12),
                      _buildNumberInput(_hipsController, 'Kalça'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildNumberInput(_leftArmController, 'Sol Kol')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildNumberInput(_rightArmController, 'Sağ Kol')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildNumberInput(_leftThighController, 'Sol Bacak')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildNumberInput(_rightThighController, 'Sağ Bacak')),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Fotoğraflar'),
                Row(
                  children: [
                    Expanded(child: _buildPhotoPicker('Ön', _frontPhoto, 'front')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPhotoPicker('Yan', _sidePhoto, 'side')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPhotoPicker('Arka', _backPhoto, 'back')),
                  ],
                ),

                const SizedBox(height: 24),
                _buildSectionTitle('Notlar'),
                CustomTextField(
                  controller: _notesController,
                  label: 'Notlar',
                  hint: 'Eklemek istediğiniz notlar...',
                  maxLines: 3,
                ),

                const SizedBox(height: 32),
                CustomButton(
                  text: 'Kaydet',
                  onPressed: _saveMeasurement,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: AppTextStyles.headline.copyWith(
          color: AppColors.primaryYellow,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNumberInput(TextEditingController controller, String label, {bool required = false, bool isInteger = false}) {
    return CustomTextField(
      controller: controller,
      label: label,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      validator: required 
          ? (v) => v?.isEmpty == true ? 'Zorunlu alan' : null 
          : null,
    );
  }

  Widget _buildPhotoPicker(String label, File? photo, String position) {
    return GestureDetector(
      onTap: () => _pickImage(position),
      child: AspectRatio(
        aspectRatio: 3/4,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: photo != null ? AppColors.primaryYellow : AppColors.glassBorder,
              width: photo != null ? 2 : 1,
            ),
            image: photo != null ? DecorationImage(
              image: FileImage(photo),
              fit: BoxFit.cover,
            ) : null,
          ),
          child: photo == null ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_rounded, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              Text(label, style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary)),
            ],
          ) : Stack(
            children: [
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      switch (position) {
                        case 'front': _frontPhoto = null; break;
                        case 'side': _sidePhoto = null; break;
                        case 'back': _backPhoto = null; break;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
