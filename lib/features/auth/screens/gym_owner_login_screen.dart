import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fitflow/core/theme/colors.dart';
import 'package:fitflow/core/theme/text_styles.dart';
import 'package:fitflow/shared/widgets/custom_button.dart';
import 'package:fitflow/shared/widgets/custom_snackbar.dart';
import 'package:fitflow/shared/widgets/custom_text_field.dart';
import 'package:fitflow/shared/widgets/glass_card.dart';
import 'package:fitflow/shared/widgets/ambient_background.dart';
import 'package:fitflow/features/dashboard/screens/dashboard_screen.dart';
import 'package:fitflow/features/auth/screens/forgot_password_screen.dart';
import '../../../core/utils/error_translator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GymOwnerLoginScreen extends StatefulWidget {
  const GymOwnerLoginScreen({super.key});

  @override
  State<GymOwnerLoginScreen> createState() => _GymOwnerLoginScreenState();
}

class _GymOwnerLoginScreenState extends State<GymOwnerLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Registration extras
  final _gymNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoading = false;
  bool _isLoginPasswordVisible = false;
  bool _isRegisterPasswordVisible = false;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _gymNameController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth({bool isRegister = false}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      CustomSnackBar.showError(context, 'Lütfen email ve şifre girin');
      return;
    }

    if (isRegister) {
      if (_gymNameController.text.isEmpty || _cityController.text.isEmpty || _districtController.text.isEmpty) {
         CustomSnackBar.showError(context, 'Lütfen salon bilgilerini eksiksiz girin');
         return;
      }

      // Check Organization Name Uniqueness
      try {
        final isAvailable = await _supabase.rpc('check_organization_name_availability', params: {
          'org_name': _gymNameController.text.trim(),
        });
        
        if (isAvailable == false) {
           CustomSnackBar.showError(context, 'Bu salon adı zaten kullanımda. Lütfen başka bir ad seçin.');
           setState(() => _isLoading = false);
           return;
        }
      } catch (e) {
        // Fallback or ignore if RPC doesn't exist yet (dev mode), but ideally we block.
        debugPrint('Uniqueness check failed: $e');
      }
    }

    setState(() => _isLoading = true);

    try {
      AuthResponse response;
      if (isRegister) {
        response = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {
             'first_name': _firstNameController.text.trim(),
             'last_name': _lastNameController.text.trim(),
             'role': 'owner',
             'gym_name': _gymNameController.text.trim(),
             'city': _cityController.text.trim(),
             'district': _districtController.text.trim(),
          }
        );

        // For email verification flow:
        // logic is handled by Database Trigger (on_auth_user_created)
        
        if (mounted) {
           // Show verification dialog
           showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Kayıt Başarılı', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Lütfen hesabınızı aktif hale getirmek için email adresinize gönderilen onay linkine tıklayın.',
                style: TextStyle(color: Colors.grey),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _tabController.animateTo(0); // Switch to Login tab
                  },
                  child: const Text('Tamam', style: TextStyle(color: AppColors.primaryYellow)),
                ),
              ],
            ),
           );
           return; // Stop here, don't navigate to dashboard
        }

      } else {
        response = await _supabase.auth.signInWithPassword(email: email, password: password);
      
        // Navigation (Only for Login)
        if (mounted && response.session != null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      }

    } on AuthException catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, ErrorMessageTranslator.translateAuthError(e));
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Beklenmeyen bir hata oluştu');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _handleGoogleSignIn() async {
     setState(() => _isLoading = true);
     try {
       // Setup Google Sign In logic here (requires configured Google Cloud Console)
       // For now, placeholder
       await Future.delayed(const Duration(seconds: 1));
       CustomSnackBar.showError(context, 'Google Sign-In henüz yapılandırılmadı (geliştirme aşamasında)');
     } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Google Giriş Hatası: $e');
     } finally {
        if (mounted) setState(() => _isLoading = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allow background to show through AppBar
      backgroundColor: Colors.transparent, // Handled by AmbientBackground
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Salon Sahibi / PT Paneli', style: AppTextStyles.headline),
        iconTheme: const IconThemeData(color: Colors.white), // Ensure back arrow is white
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: GlassCard(
             margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
             padding: const EdgeInsets.all(4),
             borderRadius: BorderRadius.circular(12),
             backgroundColor: Colors.white.withOpacity(0.1),
             child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: AppColors.primaryYellow,
              unselectedLabelColor: Colors.grey[300],
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Giriş Yap'),
                Tab(text: 'Kayıt Ol'),
              ],
            ),
          ),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Login Tab
              _buildLoginForm(),
              // Register Tab
              _buildRegisterForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Tekrar Hoşgeldiniz',
              style: AppTextStyles.title2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Hesabınıza giriş yapın',
              style: AppTextStyles.body.copyWith(color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'ornek@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryYellow),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController,
              label: 'Şifre',
              hint: '******',
              obscureText: !_isLoginPasswordVisible,
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryYellow),
              suffixIcon: IconButton(
                icon: Icon(
                  _isLoginPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _isLoginPasswordVisible = !_isLoginPasswordVisible),
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
                  style: AppTextStyles.caption1.copyWith(color: Colors.grey[400]),
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Giriş Yap',
              onPressed: () => _handleAuth(isRegister: false),
              isLoading: _isLoading,
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: Colors.black,
            ),
            const SizedBox(height: 24),
            Row(children: [
              const Expanded(child: Divider(color: Colors.grey)), 
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                child: Text('veya', style: TextStyle(color: Colors.grey[400]))
              ), 
              const Expanded(child: Divider(color: Colors.grey))
            ]),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              icon: const Icon(Icons.g_mobiledata, size: 28),
              label: const Text('Google ile Devam Et'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.grey[700]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Yeni Kayıt',
              style: AppTextStyles.title2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: CustomTextField(
                  controller: _firstNameController, 
                  label: 'Ad', 
                  prefixIcon: const Icon(Icons.person, color: AppColors.primaryYellow)
                )),
                const SizedBox(width: 12),
                Expanded(child: CustomTextField(
                  controller: _lastNameController, 
                  label: 'Soyad', 
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryYellow)
                )),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _gymNameController, 
              label: 'Salon Adı', 
              prefixIcon: const Icon(Icons.fitness_center, color: AppColors.primaryYellow)
            ),
            const SizedBox(height: 16),
             Row(
              children: [
                Expanded(child: CustomTextField(
                  controller: _cityController, 
                  label: 'İl', 
                  prefixIcon: const Icon(Icons.location_city, color: AppColors.primaryYellow)
                )),
                const SizedBox(width: 12),
                Expanded(child: CustomTextField(
                  controller: _districtController, 
                  label: 'İlçe', 
                  prefixIcon: const Icon(Icons.location_on, color: AppColors.primaryYellow)
                )),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _emailController, 
              label: 'Email', 
              hint: 'ornek@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryYellow)
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _passwordController, 
              label: 'Şifre', 
              hint: '******',
              obscureText: !_isRegisterPasswordVisible, 
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryYellow),
              suffixIcon: IconButton(
                icon: Icon(
                  _isRegisterPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _isRegisterPasswordVisible = !_isRegisterPasswordVisible),
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Hesap ve Salon Oluştur',
              onPressed: () => _handleAuth(isRegister: true),
              isLoading: _isLoading,
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
