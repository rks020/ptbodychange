import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  final Profile? initialProfile;

  const EditProfileScreen({super.key, this.initialProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _repository = ProfileRepository();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _professionController = TextEditingController();
  final _ageController = TextEditingController();
  final _hobbiesController = TextEditingController();
  
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _firstNameController.text = widget.initialProfile!.firstName ?? '';
      _lastNameController.text = widget.initialProfile!.lastName ?? '';
      _professionController.text = widget.initialProfile!.profession ?? '';
      _ageController.text = widget.initialProfile!.age?.toString() ?? '';
      _hobbiesController.text = widget.initialProfile!.hobbies ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _professionController.dispose();
    _ageController.dispose();
    _hobbiesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilirken bir hata oluştu: $e')),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryYellow),
              title: Text('Kamera', style: AppTextStyles.body),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryYellow),
              title: Text('Galeri', style: AppTextStyles.body),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      String? avatarUrl = widget.initialProfile?.avatarUrl;

      // Upload new avatar if selected
      if (_selectedImage != null) {
        final uploadedUrl = await _repository.uploadAvatar(_selectedImage!);
        if (uploadedUrl != null) {
          avatarUrl = uploadedUrl;
        }
      }

      final profile = Profile(
        id: '', // ID will be handled by repository based on current user
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        profession: _professionController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        hobbies: _hobbiesController.text.trim(),
        avatarUrl: avatarUrl,
      );

      await _repository.updateProfile(profile);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil kaydedilirken bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profili Düzenle', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar Selector
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryYellow, width: 2),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : (widget.initialProfile?.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.initialProfile!.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
                ),
                child: (_selectedImage == null && widget.initialProfile?.avatarUrl == null)
                    ? const Icon(Icons.camera_alt_rounded, size: 40, color: AppColors.textSecondary)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fotoğrafı Değiştir',
              style: AppTextStyles.caption1.copyWith(color: AppColors.primaryYellow),
            ),
            const SizedBox(height: 32),

            // Form Fields
            CustomTextField(
              controller: _firstNameController,
              label: 'Ad',
              hint: 'Adınız',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            const SizedBox(height: 16),
             CustomTextField(
              controller: _lastNameController,
              label: 'Soyad',
              hint: 'Soyadınız',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _professionController,
              label: 'Meslek',
              hint: 'Mesleğiniz',
              prefixIcon: const Icon(Icons.work_outline),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _ageController,
              label: 'Yaş',
              hint: 'Yaşınız',
              prefixIcon: const Icon(Icons.cake_outlined),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _hobbiesController,
              label: 'Hobiler',
              hint: 'Hobileriniz (virgülle ayırın)',
              prefixIcon: const Icon(Icons.sports_tennis_rounded),
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            CustomButton(
              text: 'Kaydet',
              onPressed: _saveProfile,
              isLoading: _isLoading,
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
