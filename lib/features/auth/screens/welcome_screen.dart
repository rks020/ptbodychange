import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fitflow/core/theme/colors.dart';
import 'package:fitflow/core/theme/text_styles.dart';
import 'package:fitflow/features/auth/screens/gym_owner_login_screen.dart';
import 'package:fitflow/features/auth/screens/member_login_screen.dart';
import 'package:fitflow/shared/widgets/custom_button.dart';
import 'package:fitflow/shared/widgets/ambient_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // App Icon
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryYellow.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Fit',
                        style: AppTextStyles.largeTitle.copyWith(
                          fontSize: 40,
                          letterSpacing: 1.5,
                          color: AppColors.primaryYellow,
                        ),
                      ),
                      TextSpan(
                        text: 'Flow',
                        style: AppTextStyles.largeTitle.copyWith(
                          fontSize: 40,
                          letterSpacing: 1.5,
                          color: AppColors.neonCyan,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Profesyonel Antrenör ve\nÜye Takip Sistemi',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                
                // Gym Owner Entry
                _buildGlassButton(
                  context,
                  title: 'Salon Sahibi / PT Girişi',
                  subtitle: 'Salonunuzu yönetin ve üye ekleyin',
                  icon: Icons.business_center_outlined,
                  accentColor: AppColors.primaryYellow, // Gold
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GymOwnerLoginScreen()),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Member Entry
                _buildGlassButton(
                  context,
                  title: 'Üye Girişi',
                  subtitle: 'Programlarınızı ve gelişiminizi takip edin',
                  icon: Icons.person_outline,
                  accentColor: AppColors.neonCyan, // Cyan
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MemberLoginScreen()),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), // Ultra transparent
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  // Icon without background circle, floating on glass
                  Icon(
                    icon,
                    color: accentColor,
                    size: 32,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.title3.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: AppTextStyles.caption1.copyWith(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
