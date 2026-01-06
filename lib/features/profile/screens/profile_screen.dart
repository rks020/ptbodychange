import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../auth/screens/login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = ProfileRepository();
  Profile? _profile;
  bool _isLoading = true;

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fallback to auth metadata if profile is not yet created
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = _profile?.firstName != null 
        ? '${_profile!.firstName} ${_profile!.lastName ?? ''}'
        : (user?.userMetadata?['username'] ?? 'PT User');
    
    String initials = 'PT';
    if (displayName.isNotEmpty) {
      final names = displayName.trim().split(' ').where((String s) => s.isNotEmpty).toList();
      if (names.length >= 2) {
        initials = '${names.first[0]}${names.last[0]}'.toUpperCase();
      } else if (names.isNotEmpty) {
        initials = names.first.substring(0, names.first.length > 1 ? 2 : 1).toUpperCase();
      }
    }

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profil',
                            style: AppTextStyles.largeTitle.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      
                      // Profile Avatar
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
                      const SizedBox(height: 16),
                      
                      // Name & Profession
                      Text(
                        displayName,
                        style: AppTextStyles.title1.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_profile?.profession != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _profile!.profession!,
                          style: AppTextStyles.subheadline.copyWith(
                            color: AppColors.primaryYellow,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
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
                            _ProfileOption(
                              icon: Icons.settings_rounded,
                              title: 'Ayarlar',
                              onTap: () {},
                            ),
                            Divider(color: AppColors.glassBorder, height: 1),
                            _ProfileOption(
                              icon: Icons.help_rounded,
                              title: 'Yardım',
                              onTap: () {},
                            ),
                          ],
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
    );
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
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.onTap,
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
              color: AppColors.primaryYellow,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body,
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
