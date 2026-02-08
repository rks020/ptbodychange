import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_repository.dart';

import 'edit_profile_screen.dart';
import 'signature_log_screen.dart';
import 'trainer_schedule_screen.dart';
import 'change_password_screen.dart';
import 'upgrade_to_pro_screen.dart';
import 'support_screen.dart';

import 'package:fitflow/features/auth/screens/welcome_screen.dart';
import 'package:fitflow/shared/widgets/ambient_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = ProfileRepository();
  Profile? _profile;
  bool _isLoading = true;
  int _memberCount = 0;
  int _trainerCount = 0;
  String _subscriptionTier = 'FREE';
  String? _subscriptionType;
  DateTime? _trialEndDate;
  DateTime? _subscriptionEndDate;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
        });
      }
      await _loadSubscriptionInfo();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadSubscriptionInfo() async {
    if (_profile?.organizationId == null) return;
    
    try {
      // Get member count from members table
      final membersResponse = await Supabase.instance.client
          .from('members')
          .select()
          .eq('organization_id', _profile!.organizationId!);
      
      // Get trainer count from profiles table
      final trainersResponse = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('organization_id', _profile!.organizationId!)
          .eq('role', 'trainer');
      
      // Get subscription info from organization
      final orgResponse = await Supabase.instance.client
          .from('organizations')
          .select('subscription_tier, subscription_type, trial_end_date, subscription_end_date')
          .eq('id', _profile!.organizationId!)
          .single();
      
      if (mounted) {
        setState(() {
          _memberCount = (membersResponse as List).length;
          _trainerCount = (trainersResponse as List).length;
          _subscriptionTier = (orgResponse['subscription_tier'] ?? 'free').toString().toUpperCase();
          _subscriptionType = orgResponse['subscription_type'];
          if (orgResponse['trial_end_date'] != null) {
            _trialEndDate = DateTime.parse(orgResponse['trial_end_date']);
          }
          if (orgResponse['subscription_end_date'] != null) {
            _subscriptionEndDate = DateTime.parse(orgResponse['subscription_end_date']);
          }
        });
        debugPrint('Subscription loaded: Members=$_memberCount, Trainers=$_trainerCount, Tier=$_subscriptionTier');
      }
    } catch (e) {
      debugPrint('Error loading subscription info: $e');
    }
  }

  int _getTrialDaysLeft() {
    if (_trialEndDate == null) return 30;
    final now = DateTime.now();
    final difference = _trialEndDate!.difference(now);
    return difference.inDays.clamp(0, 30);
  }

  int _getSubscriptionDaysLeft() {
    if (_subscriptionEndDate == null) return 0;
    final now = DateTime.now();
    final difference = _subscriptionEndDate!.difference(now);
    return difference.inDays.clamp(0, 999);
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const WelcomeScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fallback to auth metadata if profile is not yet created
    final user = Supabase.instance.client.auth.currentUser;
    // Priority: Profile Name > User Metadata Name > Fallback
    String displayName = 'Kullanıcı';
    if (_profile?.firstName != null && _profile!.firstName!.isNotEmpty) {
      displayName = '${_profile!.firstName} ${_profile!.lastName ?? ''}'.trim();
    } else if (user?.userMetadata?['first_name'] != null) {
      displayName = '${user!.userMetadata!['first_name']} ${user!.userMetadata!['last_name'] ?? ''}'.trim();
    } else if (user?.userMetadata?['full_name'] != null) {
      displayName = user!.userMetadata!['full_name'];
    }

    String initials = 'PT';
    if (displayName.isNotEmpty && displayName != 'Kullanıcı') {
      final names = displayName.trim().split(' ').where((String s) => s.isNotEmpty).toList();
      if (names.length >= 2) {
        initials = '${names.first[0]}${names.last[0]}'.toUpperCase();
      } else if (names.isNotEmpty) {
        initials = names.first.substring(0, names.first.length > 1 ? 2 : 1).toUpperCase();
      }
    }

    // Role Label
    String roleLabel = 'Kullanıcı';
    if (_profile?.role == 'owner' || _profile?.role == 'admin') {
      roleLabel = 'Salon Sahibi';
    } else if (_profile?.role == 'trainer') {
      roleLabel = 'Eğitmen';
    }


    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _profile?.role == 'owner'
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Profil',
                style: AppTextStyles.title1.copyWith(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: _subscriptionTier == 'PRO'
                        ? LinearGradient(
                            colors: [AppColors.primaryYellow, AppColors.accentBlue],
                          )
                        : null,
                    color: _subscriptionTier == 'PRO' ? null : AppColors.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _subscriptionTier == 'PRO' ? AppColors.primaryYellow : AppColors.accentBlue,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _subscriptionTier == 'PRO' ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined,
                    color: _subscriptionTier == 'PRO' ? Colors.black : AppColors.accentBlue,
                    size: 24,
                  ),
                ),
              ],
            )
          : null,
      body: AmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                    children: [
                      // Profile Avatar
                      GestureDetector(
                        onTap: _showAvatarOptions,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.primaryYellow.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryYellow,
                                  width: 3,
                                ),
                                image: _profile?.avatarUrl != null
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(_profile!.avatarUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _profile?.avatarUrl == null
                                  ? Center(
                                      child: Text(
                                        initials,
                                        style: AppTextStyles.largeTitle.copyWith(
                                          color: AppColors.primaryYellow,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 36,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryYellow,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Name
                      Text(
                        displayName,
                        style: AppTextStyles.title1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 8),

                      // Organization Name
                      if (_profile?.organizationName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.accentBlue.withOpacity(0.5)),
                            ),
                            child: Text(
                              _profile!.organizationName!,
                              style: AppTextStyles.caption1.copyWith(
                                color: AppColors.accentBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Role Badge (always show role, not profession)
                      Text(
                        roleLabel, // Show role-based label ("Salon Sahibi", "Eğitmen", etc.)
                        style: AppTextStyles.subheadline.copyWith(
                          color: AppColors.primaryYellow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: AppTextStyles.caption1.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                      if (_profile != null) ...[
                        const SizedBox(height: 24),
                        // Additional Info Card
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(Icons.cake_outlined, 'Yaş', '${_profile?.age ?? "-"}'),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1, color: AppColors.glassBorder),
                              ),
                              _buildInfoRow(Icons.sports_tennis_rounded, 'Hobiler', _profile?.hobbies ?? "-"),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 40),
                      
                      // Subscription Tier Card (Owner Only)
                      if (_profile?.role == 'owner') ...[
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _subscriptionTier == 'PRO' ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined,
                                        color: _subscriptionTier == 'PRO' ? AppColors.primaryYellow : AppColors.accentBlue,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _subscriptionTier == 'PRO' ? 'Pro Paket' : 'Ücretsiz Paket',
                                            style: AppTextStyles.headline.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_subscriptionTier == 'PRO')
                                            Text(
                                              _subscriptionType == 'yearly' 
                                                ? 'Yıllık abonelik - kalan gün: ${_getSubscriptionDaysLeft()}'
                                                : 'Aylık abonelik - kalan gün: ${_getSubscriptionDaysLeft()}',
                                              style: AppTextStyles.caption1.copyWith(
                                                color: AppColors.primaryYellow,
                                              ),
                                            )
                                          else if (_trialEndDate != null)
                                            Text(
                                              'Deneme ${_getTrialDaysLeft()} gün sonra bitiyor',
                                              style: AppTextStyles.caption1.copyWith(
                                                color: _getTrialDaysLeft() <= 7 ? AppColors.accentRed : AppColors.textSecondary,
                                              ),
                                            )
                                          else
                                            Text(
                                              '1 ay deneme',
                                              style: AppTextStyles.caption1.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (_subscriptionTier == 'PRO')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [AppColors.primaryYellow, AppColors.accentBlue],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '⭐ AKTİF',
                                        style: AppTextStyles.caption2.copyWith(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1, color: AppColors.glassBorder),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.people_outline_rounded,
                                      label: 'Üye',
                                      value: '$_memberCount',
                                      limit: _subscriptionTier == 'FREE' ? ' / 10' : ' / ∞',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.fitness_center_rounded,
                                      label: 'Antrenör',
                                      value: '$_trainerCount',
                                      limit: _subscriptionTier == 'FREE' ? ' / 2' : ' / ∞',
                                    ),
                                  ),
                                ],
                              ),
                              if (_subscriptionTier == 'FREE') ...[
                                const SizedBox(height: 16),
                                CustomButton(
                                  text: 'Pro\'ya Yükselt',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const UpgradeToProScreen(),
                                      ),
                                    );
                                  },
                                  icon: Icons.upgrade_rounded,
                                  backgroundColor: AppColors.primaryYellow,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Profile Options
                      GlassCard(
                        child: Column(
                          children: [
                            _ProfileOption(
                              icon: Icons.edit_note_rounded,
                              title: 'Profili Düzenle',
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditProfileScreen(initialProfile: _profile),
                                  ),
                                );
                                if (result == true) {
                                  _loadProfile();
                                }
                              },
                            ),
                            Divider(color: AppColors.glassBorder, height: 1),
                            // Changed Settings to Change Password per requirement, or just added it
                            _ProfileOption(
                              icon: Icons.lock_reset_rounded,
                              title: 'Şifre Değiştir',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ChangePasswordScreen(),
                                  ),
                                );
                              },
                            ),
                            Divider(color: AppColors.glassBorder, height: 1),
                            _ProfileOption(
                              icon: Icons.help_rounded,
                              title: 'Yardım / Destek',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SupportScreen(),
                                  ),
                                );
                              },
                            ),
                            // Delete Organization (Owner Only)
                            if (_profile?.role == 'owner') ...[
                              Divider(color: AppColors.glassBorder, height: 1),
                              _ProfileOption(
                                icon: Icons.delete_forever_rounded,
                                title: 'Salonu ve Hesabımı Sil',
                                iconColor: AppColors.accentRed,
                                textColor: AppColors.accentRed,
                                onTap: _showDeleteOrganizationDialog,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      const SizedBox(height: 16),

                      // Trainer Schedule Entry
                      GlassCard(
                        child: _ProfileOption(
                          icon: Icons.calendar_month_rounded,
                          title: 'Eğitmen Programı',
                          onTap: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => const TrainerScheduleScreen(),
                               ),
                             );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Signature Log Entry
                      GlassCard(
                        child: _ProfileOption(
                          icon: Icons.history_edu_rounded,
                          title: 'Ders Kaydı Defteri',
                          onTap: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => const SignatureLogScreen(),
                               ),
                             );
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Logout Button
                      CustomButton(
                        text: 'Çıkış Yap',
                        onPressed: _logout,
                        icon: Icons.logout_rounded,
                        backgroundColor: AppColors.accentRed,
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Future<void> _showAvatarOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profil Fotoğrafı',
              style: AppTextStyles.headline.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: const Text('Galeriden Seç', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: const Text('Fotoğraf Çek', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_profile?.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.accentRed),
                title: const Text('Fotoğrafı Kaldır', style: TextStyle(color: AppColors.accentRed)),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 70);
      
      if (picked != null) {
        setState(() => _isLoading = true);
        final file = File(picked.path);
        final url = await _repository.uploadAvatar(file);
        
        if (url != null) {
          await _updateAvatarUrl(url);
        }
      }
    } catch (e) {
      debugPrint('Avatar selection error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _isLoading = true);
    await _updateAvatarUrl(null);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateAvatarUrl(String? url) async {
    if (_profile == null) return;
    
    // Manual copy with new avatarUrl
    final newProfile = Profile(
      id: _profile!.id,
      firstName: _profile!.firstName,
      lastName: _profile!.lastName,
      profession: _profile!.profession,
      age: _profile!.age,
      hobbies: _profile!.hobbies,
      avatarUrl: url,
      role: _profile!.role,
      organizationId: _profile!.organizationId,
      specialty: _profile!.specialty,
      passwordChanged: _profile!.passwordChanged,
      isOnline: _profile!.isOnline,
      updatedAt: DateTime.now(),
    );
    
    await _repository.updateProfile(newProfile);
    await _loadProfile();
  }

  Future<void> _showDeleteOrganizationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Salonu ve Hesabımı Sil', style: TextStyle(color: AppColors.accentRed)),
        content: const Text(
          'DİKKAT! Bu işlem geri alınamaz.\n\n'
          'Salonunuz, tüm üyeleriniz, eğitmenleriniz ve tüm verileriniz KALICI OLARAK SİLİNECEKTİR.\n\n'
          'Devam etmek istiyor musunuz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('EVET, SİL', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeDeleteOrganization();
    }
  }

  Future<void> _executeDeleteOrganization() async {
     setState(() => _isLoading = true);
     try {
       await Supabase.instance.client.functions.invoke(
          'delete-user',
          body: { 
            'delete_organization': true,
            'user_id': _profile?.id ?? Supabase.instance.client.auth.currentUser?.id,
          }
       );
       
       if (mounted) {
         CustomSnackBar.showSuccess(context, 'Salon ve hesap başarıyla silindi.');
       }
       
       // Başarılı ise çıkış yap
       await _logout();
     } catch (e) {
       if (mounted) {
         setState(() => _isLoading = false);
         CustomSnackBar.showError(context, 'Hata: $e');
         // Edge Function deploy edilmemişse hata verir
         debugPrint('Delete Organization Error: $e');
       }
     }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({required IconData icon, required String label, required String value, required String limit}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.glassBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryYellow, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption2.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: AppTextStyles.headline.copyWith(fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: limit,
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor ?? AppColors.primaryYellow,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(
                  color: textColor ?? Colors.white,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
