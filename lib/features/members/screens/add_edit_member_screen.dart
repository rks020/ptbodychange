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
  List<String> _packages = ['8 Ders Paketi', '12 Ders Paketi', 'Manuel'];

  bool _isActive = true;
  bool _isMultisport = false;
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
      
      // DEBUG: Check password_changed value
      print('DEBUG: Member passwordChanged = ${widget.member!.passwordChanged}');
      print('DEBUG: Member email = ${widget.member!.email}');
      print('DEBUG: Member id = ${widget.member!.id}');
      
      // If current package is not in the list (legacy or removed), default to 'Manuel'
      if (_selectedPackage != null && !_packages.contains(_selectedPackage)) {
        _selectedPackage = 'Manuel';
      }
      
      // Auto-fill session count if missing but package is selected
      if (_sessionCountController.text.isEmpty && _selectedPackage != null) {
         final match = RegExp(r'^(\d+)\s+Ders').firstMatch(_selectedPackage!);
         if (match != null) {
            _sessionCountController.text = match.group(1)!;
         }
      }

      _isActive = widget.member!.isActive;
      _isMultisport = widget.member!.isMultisport;
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
      // Fetch all profiles in org (RLS allows owner to see them)
      final response = await supabase
          .from('profiles')
          .select()
          .or('role.eq.trainer,role.eq.admin,role.eq.owner,role.eq.manager') // Filter by role
          .order('first_name');
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
      final repository = MemberRepository();
      
      if (widget.member == null) {
        // --- CREATE NEW MEMBER FLOW ---
        
        final nameParts = _nameController.text.trim().split(' ');
        final firstName = nameParts.first;
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
        final email = _emailController.text.trim();
        final phone = _phoneController.text.trim();

        // 1. Initial Validation
        if (email.isEmpty) throw Exception('Yeni üye için e-posta zorunludur.');
        
        // 2. Check if email exists (Before creating Auth user)
        final emailExists = await repository.isEmailTaken(email);
        if (emailExists) {
          throw Exception('Bu e-posta adresi zaten kullanılıyor. Lütfen farklı bir e-posta girin.');
        }
        
        final tempPassword = _passwordController.text.trim();
        if (tempPassword.isEmpty || tempPassword.length < 6) {
          throw Exception('Geçici şifre en az 6 karakter olmalıdır');
        }
        
        // 3. Create Auth User via Edge Function
        final currentProfile = await _profileRepository.getProfile();
        final orgId = currentProfile?.organizationId;
        
        if (orgId == null) throw Exception('Organizasyon bulunamadı');
        
        final authResponse = await Supabase.instance.client.functions.invoke(
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

        final memberId = responseData['user']['id'];

        // 4. Create Member Record in DB
        // We DO NOT check isEmailTaken here because we just created the user above!
        
        final newMember = Member(
          id: memberId,
          name: _nameController.text.trim(),
          email: email,
          phone: phone,
          isActive: _isActive,
          joinDate: DateTime.now(),
          emergencyContact: _emergencyContactController.text.trim().isNotEmpty ? _emergencyContactController.text.trim() : null,
          emergencyPhone: _emergencyPhoneController.text.trim().isNotEmpty ? _emergencyPhoneController.text.trim() : null,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          subscriptionPackage: _selectedPackage,
          sessionCount: int.tryParse(_sessionCountController.text.trim()),
          trainerId: _selectedTrainerId, 
          isMultisport: _isMultisport,
        );

        try {
          await repository.create(newMember);
          
          if (mounted) {
            CustomSnackBar.showSuccess(
              context, 
              'Üye oluşturuldu! İlk girişte şifre değiştirilecek.'
            );
          }
        } catch (createError) {
          // If DB insertion fails, try to cleanup Auth user
          try {
             await Supabase.instance.client.rpc('delete_orphaned_user', params: {'target_user_id': memberId});
          } catch (cleanupError) {
             debugPrint('Cleanup failed: $cleanupError');
          }
          rethrow;
        }

      } else {
        // --- UPDATE MEMBER FLOW ---
        
        // 1. Check if email taken by OTHER user
        final emailTaken = await repository.isEmailTaken(
          _emailController.text.trim(),
          excludeMemberId: widget.member!.id,
        );
        if (emailTaken) {
          throw Exception('Bu e-posta adresi zaten kullanılıyor. Lütfen farklı bir e-posta girin.');
        }

        final updatedMember = Member(
          id: widget.member!.id,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          isActive: _isActive,
          joinDate: widget.member!.joinDate,
          emergencyContact: _emergencyContactController.text.trim().isNotEmpty ? _emergencyContactController.text.trim() : null,
          emergencyPhone: _emergencyPhoneController.text.trim().isNotEmpty ? _emergencyPhoneController.text.trim() : null,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          subscriptionPackage: _selectedPackage,
          sessionCount: int.tryParse(_sessionCountController.text.trim()),
          trainerId: _selectedTrainerId,
          isMultisport: _isMultisport,
        );

        await repository.update(updatedMember);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Başarıyla güncellendi'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('already been registered') || errorMessage.contains('already used')) {
        errorMessage = 'Bu e-posta adresi sistemde zaten kayıtlıdır.';
      } else {
        errorMessage = errorMessage.replaceAll('Exception: ', '').replaceAll('FunctionException: ', '');
      }
      
      if (mounted) {
        CustomSnackBar.showError(context, errorMessage);
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
              if (widget.member == null) ...[
                const SizedBox(height: 20),
                CustomTextField(
                  label: 'Geçici Şifre *',
                  hint: 'En az 6 karakter',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_rounded),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Geçici şifre gereklidir';
                    }
                    if (value.length < 6) {
                      return 'En az 6 karakter olmalıdır';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ]
              else
                 Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryYellow.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_reset_rounded, color: AppColors.primaryYellow),
                          const SizedBox(width: 8),
                          Text(
                            'Giriş Bilgileri',
                            style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Üyenin giriş sorunu yaşaması durumunda buradan yeni bir geçici şifre atayabilirsiniz.',
                        style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Yeni Geçici Şifre Belirle',
                        foregroundColor: Colors.black,
                        backgroundColor: AppColors.primaryYellow,
                        onPressed: () {
                          _showResetPasswordDialog(context);
                        },
                      ),
                    ],
                  ),
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
                    if (value == 'Manuel') {
                       _sessionCountController.clear();
                    } else if (value != null) {
                      // Extract number from package string e.g "8 Ders Paketi" -> 8
                      final match = RegExp(r'^(\d+)\s+Ders').firstMatch(value);
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
              const SizedBox(height: 16),
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
                    Text('Multisport Üyesi', style: AppTextStyles.headline),
                    Switch(
                      value: _isMultisport,
                      onChanged: (value) {
                        setState(() {
                          _isMultisport = value;
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

  void _showResetPasswordDialog(BuildContext context) {
    final passController = TextEditingController();
    bool isDialogLoading = false;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while loading
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Yeni Geçici Şifre', style: AppTextStyles.headline),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'En az 6 karakter olmalıdır.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: passController,
                  label: 'Yeni Şifre',
                  hint: '******',
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryYellow),
                ),
                if (isDialogLoading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: AppColors.primaryYellow),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDialogLoading ? null : () => Navigator.pop(context),
                child: Text(
                  'İptal', 
                  style: AppTextStyles.callout.copyWith(
                    color: isDialogLoading ? AppColors.textSecondary : Colors.white
                  )
                ),
              ),
              TextButton(
                onPressed: isDialogLoading ? null : () async {
                  final newPass = passController.text.trim();
                  if (newPass.length < 6) {
                    CustomSnackBar.showError(context, 'Şifre en az 6 karakter olmalıdır');
                    return;
                  }
                  
                  // Show loading inside dialog
                  setDialogState(() => isDialogLoading = true);
                  
                  try {
                    final response = await Supabase.instance.client.functions.invoke(
                      'update-user-password',
                      body: {
                        'userId': widget.member!.id,
                        'newPassword': newPass,
                      },
                    );

                    if (response.status != 200) {
                      throw Exception(response.data['error'] ?? 'Güncelleme başarısız');
                    }
                    
                    if (mounted) {
                      Navigator.pop(context); // Close dialog first
                      // Then show success message on parent screen
                      CustomSnackBar.showSuccess(this.context, 'Geçici şifre başarıyla güncellendi ve kaydedildi');
                    }
                  } catch (e) {
                    if (mounted) {
                      setDialogState(() => isDialogLoading = false); // Stop loading to allow retry
                      CustomSnackBar.showError(context, 'Hata: $e');
                    }
                  }
                },
                child: Text(
                  'Güncelle ve Kaydet', 
                  style: AppTextStyles.callout.copyWith(
                    color: isDialogLoading ? AppColors.textSecondary : AppColors.primaryYellow
                  ),
                ),
              ),
            ],
          );
        }
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
