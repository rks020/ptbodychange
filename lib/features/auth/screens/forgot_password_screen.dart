import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../shared/widgets/ambient_background.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/utils/error_translator.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      CustomSnackBar.showError(context, 'Lütfen email adresinizi girin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Check if email exists in the system (Security Definer RPC)
      final bool emailExists = await Supabase.instance.client.rpc('check_email_exists', params: {'email_to_check': email});

      if (!emailExists) {
        if (mounted) CustomSnackBar.showError(context, 'Bu e-posta adresi sistemde kayıtlı değil.');
        return;
      }

      // 2. Sends a password reset email to the user
      // CRITICAL: Must use 'redirectTo' for Deep Linking to work (open the app)
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.fitflow://login-callback',
      );
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF222222),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Email Gönderildi', style: TextStyle(color: Colors.white)),
            content: Text(
              '$email adresine şifre sıfırlama bağlantısı gönderildi. Lütfen gelen kutunuzu (ve spam klasörünü) kontrol edin.\n\nGelen linke tıkladığınızda UYGULAMA açılacaktır.',
              style: const TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to Login
                },
                child: const Text('Tamam', style: TextStyle(color: AppColors.primaryYellow)),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) CustomSnackBar.showError(context, ErrorMessageTranslator.translateAuthError(e));
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
      appBar: AppBar(
        title: Text('Şifremi Unuttum', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      size: 64,
                      color: AppColors.primaryYellow,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hesabınıza erişmek için şifre sıfırlama bağlantısı gönderilecektir.',
                      style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'ornek@email.com',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryYellow),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Sıfırlama Bağlantısı Gönder',
                      onPressed: _resetPassword,
                      isLoading: _isLoading,
                      backgroundColor: AppColors.primaryYellow,
                      foregroundColor: Colors.black,
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
