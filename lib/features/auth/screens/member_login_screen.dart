import 'package:flutter/material.dart';

import 'package:fitflow/core/theme/colors.dart';
import 'package:fitflow/core/theme/text_styles.dart';
import 'package:fitflow/shared/widgets/custom_button.dart';
import 'package:fitflow/shared/widgets/custom_snackbar.dart';
import 'package:fitflow/shared/widgets/custom_text_field.dart';
import 'package:fitflow/shared/widgets/glass_card.dart';
import 'package:fitflow/shared/widgets/ambient_background.dart';
import 'package:fitflow/features/dashboard/screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/screens/change_password_screen.dart';
import 'forgot_password_screen.dart';

class MemberLoginScreen extends StatefulWidget {
  final bool isTrainer;

  const MemberLoginScreen({
    super.key,
    this.isTrainer = false,
  });

  @override
  State<MemberLoginScreen> createState() => _MemberLoginScreenState();
}

class _MemberLoginScreenState extends State<MemberLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      CustomSnackBar.showError(context, 'E-posta ve şifre boş bırakılamaz');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _supabase.auth
          .signInWithPassword(email: email, password: password);

      if (response.session != null) {
        // Enforce Role Check
        final userId = response.session!.user.id;
        final profileData = await _supabase
            .from('profiles')
            .select('role, password_changed')
            .eq('id', userId)
            .maybeSingle();

        final role = profileData?['role'];
        final bool passwordChanged = profileData?['password_changed'] ?? true;
        
        // 1. If screen is for TRAINER but user is NOT trainer
        if (widget.isTrainer && role != 'trainer') {
           await _supabase.auth.signOut();
           if (mounted) {
             if (role == 'owner') {
                CustomSnackBar.showError(context, 'Salon sahipleri salon sahibi panelinden girmelidir.');
             } else {
                CustomSnackBar.showError(context, 'Bu alandan sadece antrenörler giriş yapabilir.');
             }
           }
           setState(() => _isLoading = false);
           return;
        }

        // 2. If screen is for MEMBER but user is NOT member
        if (!widget.isTrainer && role != 'member') {
           await _supabase.auth.signOut();
           if (mounted) {
             if (role == 'owner') {
                CustomSnackBar.showError(context, 'Salon sahipleri salon sahibi panelinden girmelidir.');
             } else if (role == 'trainer') {
                CustomSnackBar.showError(context, 'Antrenörler antrenör girişinden girmelidir.');
             } else {
                CustomSnackBar.showError(context, 'Bu alandan sadece üyeler giriş yapabilir.');
             }
           }
           setState(() => _isLoading = false);
           return;
        }
        
        // Navigate based on password status
        
        // Navigate based on password status
        if (mounted) {
          if (passwordChanged == false) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) =>
                      const ChangePasswordScreen(isFirstLogin: true)),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
              (route) => false,
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message;
        if (e.message.contains('invalid_credentials') ||
            e.message.contains('Invalid login credentials')) {
          message =
              'Hatalı email veya şifre. Salon sahibinden aldığınız geçici şifreyi kontrol edin.';
        } else {
          message = 'Giriş yapılamadı: ${e.message}';
        }
        CustomSnackBar.showError(context, message);
      }
    } catch (e) {
      if (mounted)
        CustomSnackBar.showError(context, 'Beklenmeyen bir hata oluştu');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  void _showUnauthorizedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.secondaryBlue, width: 1)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Text('Yetkisiz Giriş', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Bu sisteme giriş yapabilmek için davet edilmiş olmanız gerekmektedir.\n\nLütfen eğitmeniniz ile iletişime geçin.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam',
                style: TextStyle(color: AppColors.secondaryBlue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Handled by AmbientBackground
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    widget.isTrainer ? 'Antrenör Girişi' : 'Üye Girişi',
                    style: AppTextStyles.largeTitle.copyWith(
                      color: widget.isTrainer
                          ? AppColors.accentOrange
                          : AppColors.neonCyan,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isTrainer
                        ? 'Takımınızla buluşmaya hazır mısınız?'
                        : 'Gelişiminizi takip etmek için giriş yapın',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _emailController,
                          label: 'E-posta',
                          hint: 'ornek@email.com',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icon(
                            Icons.email_outlined, 
                            color: widget.isTrainer ? AppColors.accentOrange : AppColors.neonCyan
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          label: 'Şifre',
                          hint: '******',
                          obscureText: !_isPasswordVisible,
                          prefixIcon: Icon(
                            Icons.lock_outline, 
                            color: widget.isTrainer ? AppColors.accentOrange : AppColors.neonCyan
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Şifremi Unuttum',
                              style: AppTextStyles.caption1.copyWith(
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        CustomButton(
                          text: 'Giriş Yap',
                          onPressed: _handleLogin,
                          isLoading: _isLoading,
                          backgroundColor: widget.isTrainer
                              ? AppColors.accentOrange
                              : AppColors.neonCyan,
                          foregroundColor: Colors.white,
                        ),
                      ],
                    ),
                  ),


                  // Footer Text
                  const SizedBox(height: 40),
                  Text(
                    widget.isTrainer
                        ? 'Hesabınız yok mu? Bağlı olduğunuz salon sahibi ile iletişime geçin.'
                        : 'Hesabınız yok mu? Antrenörünüz ile iletişime geçin.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption1.copyWith(
                      color: Colors.grey[500],
                    ),
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
