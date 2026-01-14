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

class ChangePasswordScreen extends StatefulWidget {
  final bool isFirstLogin;
  
  const ChangePasswordScreen({super.key, this.isFirstLogin = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      CustomSnackBar.showError(context, 'Lütfen yeni şifrenizi girin');
      return;
    }
    if (password.length < 6) {
      CustomSnackBar.showError(context, 'Şifre en az 6 karakter olmalıdır');
      return;
    }
    if (password != confirmPassword) {
      CustomSnackBar.showError(context, 'Şifreler eşleşmiyor');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      
      // Update password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      
      // Mark password as changed in profiles table
      if (userId != null) {
        await Supabase.instance.client
          .from('profiles')
          .update({'password_changed': true})
          .eq('id', userId);
      }
      
      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Şifreniz başarıyla güncellendi');
        
        if (widget.isFirstLogin) {
          // First login: navigate to DashboardScreen
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          // Regular password change: just pop
          Navigator.pop(context);
        }
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
        title: Text(
          widget.isFirstLogin ? 'Şifre Belirleme' : 'Şifre Değiştir', 
          style: AppTextStyles.headline
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: !widget.isFirstLogin, // No back button on first login
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(
                    widget.isFirstLogin 
                      ? 'İlk girişiniz! Lütfen kendi şifrenizi belirleyin.'
                      : 'Yeni şifrenizi belirleyin',
                    style: AppTextStyles.body.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Yeni Şifre',
                    hint: '******',
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryYellow),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Yeni Şifre (Tekrar)',
                    hint: '******',
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_reset, color: AppColors.primaryYellow),
                  ),
                  const SizedBox(height: 32),
                  CustomButton(
                    text: 'Şifreyi Güncelle',
                    onPressed: _updatePassword,
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
    );
  }
}
