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

class MemberLoginScreen extends StatefulWidget {
  const MemberLoginScreen({super.key});

  @override
  State<MemberLoginScreen> createState() => _MemberLoginScreenState();
}

class _MemberLoginScreenState extends State<MemberLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
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

    if (email.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      
      if (response.session != null) {
        // TODO: Check if change_password_required is true
        // If true, navigate to ChangePasswordScreen
        
        if (mounted) {
           Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false, 
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message;
        if (e.message.contains('invalid_credentials') || e.message.contains('Invalid login credentials')) {
          message = 'Hatalı email veya şifre';
        } else {
          message = 'Giriş yapılamadı: ${e.message}';
        }
        CustomSnackBar.showError(context, message);
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Beklenmeyen bir hata oluştu');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Handled by AmbientBackground
      appBar: AppBar(
        title: Text('Üye Girişi', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center( // Center the login card
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Shrink to fit content
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.secondaryBlue.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.person, size: 60, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hoşgeldiniz',
                      style: AppTextStyles.title2.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Eğitmeninizin size verdiği bilgilerle giriş yapın',
                      style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email Adresiniz',
                      hint: 'Email',
                      prefixIcon: const Icon(Icons.email, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Geçici Şifreniz',
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock, color: AppColors.secondaryBlue),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Giriş Yap',
                      backgroundColor: AppColors.secondaryBlue, // Cyan
                      foregroundColor: Colors.white,
                      onPressed: _handleLogin,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hesabınız yok mu?\nLütfen eğitmeninizle iletişime geçin.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption1.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
