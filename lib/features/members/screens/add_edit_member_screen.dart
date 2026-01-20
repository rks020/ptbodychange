import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/member.dart';
import '../../../data/models/profile.dart'; // Added
import '../../../data/repositories/member_repository.dart';
import '../../../data/repositories/profile_repository.dart'; // Added
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/subscription_limit_dialog.dart';

class AddEditMemberScreen extends StatefulWidget {
  final Member? member;

  const AddEditMemberScreen({super.key, this.member});

  @override
  State<AddEditMemberScreen> createState() => _AddEditMemberScreenState();
}

class _AddEditMemberScreenState extends State<AddEditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  final _notesController = TextEditingController();
  final _sessionCountController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String? _selectedPackage;
  final List<String> _packages = ['Standard (8 Ders)', 'Pro (10 Ders)'];

  bool _isActive = true;
  bool _isLoading = false;

  // Trainer Selection
  List<Profile> _trainers = [];
  String? _selectedTrainerId;
  bool _canAssignTrainer = false;
  final _profileRepository = ProfileRepository();
  bool _isLoadingTrainers = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadTrainers();
    
    if (widget.member != null) {
      _nameController.text = widget.member!.name;
      _emailController.text = widget.member!.email;
      _phoneController.text = widget.member!.phone;
      _emergencyContactController.text = widget.member!.emergencyContact ?? '';
      _emergencyPhoneController.text = widget.member!.emergencyPhone ?? '';
      _notesController.text = widget.member!.notes ?? '';
      _selectedPackage = widget.member!.subscriptionPackage;
      _sessionCountController.text = widget.member!.sessionCount?.toString() ?? '';
      _selectedTrainerId = widget.member!.trainerId; // Set initial trainer
      
      // Auto-fill session count if missing but package is selected
      if (_sessionCountController.text.isEmpty && _selectedPackage != null) {
         final match = RegExp(r'\((\d+)\s+Ders\)').firstMatch(_selectedPackage!);
         if (match != null) {
            _sessionCountController.text = match.group(1)!;
         }
      }

      _isActive = widget.member!.isActive;
    }
  }

  Future<void> _checkPermissionsAndLoadTrainers() async {
    final profile = await _profileRepository.getProfile();
    if (profile?.role == 'admin' || profile?.role == 'owner') {
      if (mounted) {
        setState(() {
          _canAssignTrainer = true;
          _isLoadingTrainers = true;
        });
      }
      await _loadTrainers();
    }
  }

  Future<void> _loadTrainers() async {
    try {
      final supabase = Supabase.instance.client;
      // Fetch all profiles in org (RLS allows owner to see them)
      final response = await supabase.from('profiles').select().order('first_name');
      final trainers = (response as List).map((e) => Profile.fromSupabase(e)).toList();
      
      if (mounted) {
        setState(() {
          _trainers = trainers;
          _isLoadingTrainers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trainers: $e');
      if (mounted) setState(() => _isLoadingTrainers = false);
    }
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    // Check subscription limits before creating new member
    if (widget.member == null) {
      final currentProfile = await _profileRepository.getProfile();
      final orgId = currentProfile?.organizationId;
      
      if (orgId != null) {
        // Get organization subscription tier
        final orgResponse = await Supabase.instance.client
            .from('organizations')
            .select('subscription_tier')
            .eq('id', orgId)
            .single();
        
        final tier = (orgResponse['subscription_tier'] ?? 'free').toString().toUpperCase();
        
        // Check member count for FREE tier
        if (tier == 'FREE') {
          final membersResponse = await Supabase.instance.client
              .from('members')
              .select()
              .eq('organization_id', orgId);
          
          final currentCount = (membersResponse as List).length;
          
          if (currentCount >= 10) {
            // Show limit dialog
            if (mounted) {
              await showDialog(
                context: context,
                builder: (context) => const SubscriptionLimitDialog(
                  limitType: 'member',
                  currentCount: 10,
                  maxCount: 10,
                ),
              );
              return; // Don't proceed with member creation
            }
          }
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String memberId;

      if (widget.member == null) {
        // Create New Member with Password
        final nameParts = _nameController.text.trim().split(' ');
        final firstName = nameParts.first;
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        final email = _emailController.text.trim();
        final phone = _phoneController.text.trim();

        // Check if email is empty
        if (email.isEmpty) throw Exception('Yeni üye için e-posta zorunludur.');
        
        // Check if email already exists
        final repository = MemberRepository();
        final emailExists = await repository.isEmailTaken(email);
        if (emailExists) {
          throw Exception('Bu e-posta adresi zaten kullanılıyor. Lütfen farklı bir e-posta girin.');
        }
        
        // Create user with temporary password set by admin
        final tempPassword = _passwordController.text.trim();
        
        if (tempPassword.isEmpty || tempPassword.length < 6) {
          throw Exception('Geçici şifre en az 6 karakter olmalıdır');
        }
        
        final supabase = Supabase.instance.client;
        
        // Get current organization_id
        final currentProfile = await _profileRepository.getProfile();
        final orgId = currentProfile?.organizationId;
        
        if (orgId == null) {
          throw Exception('Organizasyon bulunamadı');
        }
        
        // Create user via Edge Function
        final authResponse = await supabase.functions.invoke(
          'create-member',
          body: {
            'email': email,
            'password': tempPassword,
            'first_name': firstName,
            'last_name': lastName,
            'organization_id': orgId,
          },
        );

        if (authResponse.status != 200) {
          throw Exception(authResponse.data['error'] ?? 'Kullanıcı oluşturulamadı');
        }

        final responseData = authResponse.data;
        if (responseData == null || responseData['user'] == null) {
          throw Exception('Kullanıcı oluşturulamadı');
        }

        memberId = responseData['user']['id'];

        // Display info to admin
        if (mounted) {
          CustomSnackBar.showSuccess(
            context, 
            'Üye oluşturuldu! İlk girişte şifre değiştirilecek.'
          );
        }

      } else {
        memberId = widget.member!.id;
      }

      final member = Member(
        id: memberId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        isActive: _isActive,
        joinDate: widget.member?.joinDate ?? DateTime.now(),
        emergencyContact: _emergencyContactController.text.trim().isEmpty
            ? null
            : _emergencyContactController.text.trim(),
        emergencyPhone: _emergencyPhoneController.text.trim().isEmpty
            ? null
            : _emergencyPhoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        subscriptionPackage: _selectedPackage,
        sessionCount: int.tryParse(_sessionCountController.text.trim()),
        trainerId: _selectedTrainerId, 
      );

      final repository = MemberRepository();
      
      // Check if email already exists (for both create and update)
      final emailTaken = await repository.isEmailTaken(
        _emailController.text.trim(),
        excludeMemberId: widget.member?.id,
      );
      if (emailTaken) {
        throw Exception('Bu e-posta adresi zaten kullanılıyor. Lütfen farklı bir e-posta girin.');
      }
      if (widget.member == null) {
        await repository.create(member);
      } else {
        await repository.update(member);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.member == null 
                ? 'Üye davet edildi ve kaydedildi' 
                : 'Başarıyla güncellendi'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.member == null ? 'Üye Ekle' : 'Üye Düzenle'),
        backgroundColor: Colors.transparent,
      ),
      body: AmbientBackground(
        child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: kToolbarHeight + 10),
              CustomTextField(
                label: 'Ad Soyad *',
                hint: 'Ahmet Yılmaz',
                controller: _nameController,
                prefixIcon: const Icon(Icons.person_rounded),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ad soyad gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
                CustomTextField(
                label: 'E-posta',
                hint: 'ahmet@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_rounded),
                validator: (value) {
                  if (value != null && value.isNotEmpty && !value.contains('@')) {
                    return 'Geçerli bir e-posta girin';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Password field - only for new members
              if (widget.member == null)
                CustomTextField(
                  label: 'Geçici Şifre (min 6 karakter)',
                  hint: 'Üyenin ilk girişte kullanacağı şifre',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_rounded),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Geçici şifre gerekli';
                    }
                    if (value.length < 6) {
                      return 'Şifre en az 6 karakter olmalı';
                    }
                    return null;
                  },
                ),
              if (widget.member == null)
                const SizedBox(height: 20),
              CustomTextField(
                label: 'Telefon',
                hint: '0555 555 55 55',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_rounded),
                validator: null, // Phone is optional now
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedPackage,
                dropdownColor: AppColors.surfaceDark,
                style: AppTextStyles.body,
                decoration: InputDecoration(
                  labelText: 'Üyelik Paketi',
                  labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.card_membership_rounded, color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryYellow),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
                ),
                items: _packages.map((package) {
                  return DropdownMenuItem(
                    value: package,
                    child: Text(package),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPackage = value;
                    if (value != null) {
                      // Extract number from package string e.g "Standard (8 Ders)" -> 8
                      final match = RegExp(r'\((\d+)\s+Ders\)').firstMatch(value);
                      if (match != null) {
                         _sessionCountController.text = match.group(1)!;
                      }
                    }
                  });
                },

              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Kalan Ders Hakkı',
                hint: '10',
                controller: _sessionCountController,
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.confirmation_number_rounded),
              ),
              const SizedBox(height: 24),
              Text(
                'Acil Durum Bilgileri',
                style: AppTextStyles.title3,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Acil Durum Kişisi',
                hint: 'Ayşe Yılmaz',
                controller: _emergencyContactController,
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                label: 'Acil Durum Telefonu',
                hint: '0555 555 55 55',
                controller: _emergencyPhoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Notlar',
                hint: 'Ek bilgiler...',
                controller: _notesController,
                maxLines: 4,
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Aktif Üyelik', style: AppTextStyles.headline),
                    Switch(
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                      activeColor: AppColors.primaryYellow,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Trainer Selection Dropdown (Only for Admin/Owner)
              if (_canAssignTrainer)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _isLoadingTrainers 
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: _selectedTrainerId,
                          dropdownColor: AppColors.surfaceDark,
                          style: AppTextStyles.body,
                          decoration: InputDecoration(
                            labelText: 'Eğitmen Ata',
                            labelStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                            prefixIcon: const Icon(Icons.person_pin_circle_rounded, color: AppColors.textSecondary),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.glassBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primaryYellow),
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceDark,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Eğitmen Yok (Boşa Çıkar)', style: TextStyle(color: Colors.white70)),
                            ),
                            ..._trainers.map((trainer) {
                              final name = '${trainer.firstName ?? ''} ${trainer.lastName ?? ''}'.trim();
                              return DropdownMenuItem<String>(
                                value: trainer.id,
                                child: Text(name.isEmpty ? 'İsimsiz Eğitmen' : name),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedTrainerId = value;
                            });
                          },
                        ),
                ),

              CustomButton(
                text: widget.member == null ? 'Üye Ekle' : 'Kaydet',
                onPressed: _saveMember,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _notesController.dispose();
    _sessionCountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
