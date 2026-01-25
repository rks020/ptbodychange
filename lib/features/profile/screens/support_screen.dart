import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _emailController.text = user.email ?? '';
          if (user.userMetadata != null) {
            final firstName = user.userMetadata!['first_name'] ?? '';
            final lastName = user.userMetadata!['last_name'] ?? '';
            if (firstName.isNotEmpty) {
              _nameController.text = '$firstName $lastName'.trim();
            } else if (user.userMetadata!['full_name'] != null) {
              _nameController.text = user.userMetadata!['full_name'];
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final message = _messageController.text.trim();

      // 1. Save to Database
      await Supabase.instance.client.from('contact_messages').insert({
        'full_name': name,
        'email': email,
        'message': message,
      });

      // 2. Invoke Edge Function for Email
      // Note: We don't await this to keep UI responsive, or we assume DB success is enough for user
      // But to be safe lets await it or fire and forget.
      // Since web version awaits it, we will too to catch potential errors.
      try {
        await Supabase.instance.client.functions.invoke(
          'send-contact-email',
          body: {
            'full_name': name,
            'email': email,
            'message': message,
          },
        );
      } catch (e) {
        debugPrint('Email sending failed: $e');
        // We don't block success UI for email failure if DB saved ok
      }

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Mesajınız başarıyla iletildi.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Bir hata oluştu: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Yardım ve Destek',
          style: AppTextStyles.title1.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bize Ulaşın',
                          style: AppTextStyles.headline.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryYellow,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sorularınız, önerileriniz veya yaşadığınız sorunlar için aşağıdaki formu doldurabilirsiniz.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        CustomTextField(
                          label: 'Adınız Soyadınız',
                          controller: _nameController,
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen adınızı giriniz';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'E-Posta Adresiniz',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen e-posta adresinizi giriniz';
                            }
                            if (!value.contains('@')) {
                              return 'Geçerli bir e-posta giriniz';
                            }
                            // Basic logic from web
                            final invalidDomains = ['test.com', 'example.com', 'deneme.com', 'mail.com'];
                            final invalidUsers = ['test', 'admin', 'user', 'deneme', 'asd', '123'];
                            final parts = value.split('@');
                            if (parts.length == 2) {
                              final userPart = parts[0];
                              final domainPart = parts[1];
                              if (invalidDomains.contains(domainPart) || 
                                  invalidUsers.contains(userPart) || 
                                  userPart.length < 3 || 
                                  !domainPart.contains('.')) {
                                return 'Geçerli bir e-posta giriniz';
                              }
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                         CustomTextField(
                          label: 'Mesajınız',
                          controller: _messageController,
                          maxLines: 5,
                          hint: 'Mesajınızı buraya yazın...',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lütfen mesajınızı giriniz';
                            }
                            if (value.length < 10) {
                              return 'Mesajınız çok kısa';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Gönder',
                    onPressed: _submitForm, // CustomButton handles disabling when isLoading is true
                    isLoading: _isLoading,
                    icon: Icons.send_rounded,
                    backgroundColor: AppColors.primaryYellow,
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
