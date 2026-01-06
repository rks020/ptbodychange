import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      CustomSnackBar.showError(context, 'Şifreler eşleşmiyor');
      return;
    }

    setState(() {
      _isLoading = true;
    });


    try {
      // Use username-based email format for authentication
      // Clean username: remove special chars that are invalid in email local part
      final cleanUsername = _usernameController.text
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''); // Only allow alphanumeric
      
      final authEmail = '$cleanUsername@ptbodychange.app';
      
      final response = await Supabase.instance.client.auth.signUp(
        email: authEmail,
        password: _passwordController.text,
        data: {
          'username': _usernameController.text.trim(),
          'display_name': _usernameController.text.trim(),
        },
      );

      if (mounted) {
        if (response.user != null) {
          CustomSnackBar.showSuccess(
            context,
            'Kayıt başarılı! Kullanıcı adınız ile giriş yapabilirsiniz.',
          );
          
          // Wait a bit for user to see the success message
          await Future.delayed(const Duration(seconds: 1));
          
          // Navigate back to login
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        // Debug: Print full error details
        print('Signup AuthException: ${e.message}');
        print('Signup AuthException statusCode: ${e.statusCode}');
        
        String errorMessage = 'Kayıt başarısız';
        
        if (e.message.contains('User already registered')) {
          errorMessage = 'Bu kullanıcı adı zaten kullanılıyor';
        } else if (e.message.contains('Password should be at least')) {
          errorMessage = 'Şifre en az 6 karakter olmalı';
        } else if (e.message.contains('Invalid email')) {
          errorMessage = 'Geçersiz kullanıcı adı';
        } else if (e.message.contains('Email rate limit exceeded')) {
          errorMessage = 'Çok fazla deneme yaptınız. Lütfen biraz bekleyin.';
        } else {
          // Show the actual error message for debugging
          errorMessage = 'Hata: ${e.message}';
        }

        CustomSnackBar.showError(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        print('Signup General Exception: $e');
        CustomSnackBar.showError(context, 'Bir hata oluştu. Lütfen tekrar deneyin.');
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.asset(
                      'assets/images/pt_logo.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Hesap Oluştur',
                    style: AppTextStyles.largeTitle.copyWith(
                      color: AppColors.primaryYellow,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yeni hesap oluşturun',
                    style: AppTextStyles.subheadline,
                  ),
                  const SizedBox(height: 40),
                  // Signup Form
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CustomTextField(
                            label: 'Kullanıcı Adı',
                            hint: 'kullanıcıadı',
                            controller: _usernameController,
                            keyboardType: TextInputType.text,
                            prefixIcon: const Icon(Icons.person_rounded),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Kullanıcı adı gerekli';
                              }
                              if (value.length < 3) {
                                return 'En az 3 karakter olmalı';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Şifre',
                            hint: '••••••••',
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Şifre gerekli';
                              }
                              if (value.length < 6) {
                                return 'En az 6 karakter olmalı';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            label: 'Şifre Tekrar',
                            hint: '••••••••',
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: const Icon(Icons.lock_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Şifre tekrarı gerekli';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          CustomButton(
                            text: 'Kayıt Ol',
                            onPressed: _signUp,
                            isLoading: _isLoading,
                            icon: Icons.person_add_rounded,
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'Zaten hesabınız var mı? Giriş Yapın',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.primaryYellow,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
