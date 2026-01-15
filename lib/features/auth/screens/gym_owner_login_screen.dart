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
import '../../../core/constants/turkey_cities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_pending_screen.dart';
import '../../profile/screens/change_password_screen.dart';

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
  String? _selectedCity;
  String? _selectedDistrict;
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
      if (_gymNameController.text.isEmpty || _selectedCity == null || _selectedDistrict == null) {
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
    debugPrint('Attempting Register with Email: "$email" (Length: ${email.length})');
    email.runes.forEach((int rune) {
       var character = String.fromCharCode(rune);
       debugPrint('Char: $character Code: $rune');
    });

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
             'city': _selectedCity ?? '',
             'district': _selectedDistrict ?? '',
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
      
        if (mounted && response.session != null) {
          // Check if user has completed invitation (changed password)
          // If password_changed is null, assume true (legacy user or standard signup)
          // Block only if explicitly set to false (invited user who hasn't accepted yet)
          final userMetadata = response.session!.user.userMetadata;
          final passwordChanged = userMetadata?['password_changed'];

          if (passwordChanged == false) {
             // User needs to change temporary password
             Navigator.of(context).pushAndRemoveUntil(
               MaterialPageRoute(builder: (context) => const ChangePasswordScreen(isFirstLogin: true)),
               (route) => false,
             );
             return;
          }

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      }

    } on AuthException catch (e) {
      if (mounted) {
        if (isRegister) {
           // Registration specific errors
           if (e.message.contains('User already registered') || e.code == 'user_already_exists') {
             CustomSnackBar.showError(context, 'Bu e-posta adresi zaten kayıtlı.');
           } else {
             CustomSnackBar.showError(context, '${ErrorMessageTranslator.translateAuthError(e)}\n(${e.message})');
           }
        } else {
           // Login specific errors
           if (e.message.contains('Invalid login credentials') || e.statusCode == '400') {
             CustomSnackBar.showError(
               context, 
               'Giriş bilgileri hatalı. Geçici şifre ile giriyorsanız salon sahibinden aldığınız şifreyi kontrol edin.'
             );
           } else {
             CustomSnackBar.showError(context, ErrorMessageTranslator.translateAuthError(e));
           }
        }
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Beklenmeyen bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _handleGoogleSignIn() async {
     setState(() => _isLoading = true);
     try {
       // 1. Web Client ID (from Supabase Auth Settings -> Google)
       // 2. iOS Client ID (from Google Cloud Console)
       const webClientId = '763178042993-oogl3ur576s2nqt2q4qilvre6ettftu5.apps.googleusercontent.com';
       const iosClientId = '763178042993-j0ni4gerolse2h9nt0uidvnku14nlscg.apps.googleusercontent.com';

       final GoogleSignIn googleSignIn = GoogleSignIn(
         serverClientId: webClientId,
         clientId: iosClientId,
       );

       final googleUser = await googleSignIn.signIn();
       final googleAuth = await googleUser?.authentication;

       if (googleAuth == null) {
         throw 'Google girişi iptal edildi.';
       }

       final accessToken = googleAuth.accessToken;
       final idToken = googleAuth.idToken;

       if (idToken == null) {
         throw 'Google ID Token bulunamadı.';
       }

       final response = await _supabase.auth.signInWithIdToken(
         provider: OAuthProvider.google,
         idToken: idToken,
         accessToken: accessToken,
       );

       if (response.session != null) {
         // Check if user is authorized (has a profile and organization)
         final userId = response.user!.id;
         final profileData = await _supabase
             .from('profiles')
             .select()
             .eq('id', userId)
             .maybeSingle();

         if (profileData == null || profileData['organization_id'] == null) {
           // Unauthorized User - Delete/SignOut
           await _supabase.auth.signOut();
           if (mounted) {
             _showUnauthorizedDialog(context);
           }
           return;
         }

          // Check if user has completed invitation (changed password)
          // We use profileData because session metadata might be unreliable during OAuth/Google Sign-In
          final passwordChanged = profileData['password_changed'];

          if (passwordChanged == false) {
             await _supabase.auth.signOut();
             if (mounted) {
               CustomSnackBar.showError(
                 context, 
                 'Lütfen önce salon sahibinden aldığınız geçici şifre ile normal giriş yaparak şifrenizi belirleyin. Daha sonra Google ile giriş yapabilirsiniz.'
               );
             }
             return;
          }

         if (mounted) {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const DashboardScreen()),
             (route) => false,
           );
         }
       }

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
              'Salon Kayıt',
              style: AppTextStyles.title2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: CustomTextField(
                  controller: _firstNameController, 
                  label: 'Salon Sahibi Adı', 
                  prefixIcon: const Icon(Icons.person, color: AppColors.primaryYellow)
                )),
                const SizedBox(width: 12),
                Expanded(child: CustomTextField(
                  controller: _lastNameController, 
                  label: 'Salon Sahibi Soyadı', 
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
                // City Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'İl',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.location_city, color: AppColors.primaryYellow),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryYellow),
                      ),
                    ),
                    dropdownColor: AppColors.cardBackground,
                    style: AppTextStyles.body,
                    items: TurkeyCities.cityNames.map((String city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCity = newValue;
                        _selectedDistrict = null; // Reset district when city changes
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // District Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    decoration: InputDecoration(
                      labelText: 'İlçe',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.location_on, color: AppColors.primaryYellow),
                      filled: true,
                      fillColor: AppColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryYellow),
                      ),
                    ),
                    dropdownColor: AppColors.cardBackground,
                    style: AppTextStyles.body,
                    items: _selectedCity == null 
                      ? [] 
                      : TurkeyCities.getDistricts(_selectedCity!).map((String district) {
                          return DropdownMenuItem<String>(
                            value: district,
                            child: Text(district),
                          );
                        }).toList(),
                    onChanged: _selectedCity == null 
                      ? null 
                      : (String? newValue) {
                          setState(() {
                            _selectedDistrict = newValue;
                          });
                        },
                  ),
                ),
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
  void _showUnauthorizedDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.primaryYellow, width: 1)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Text('Yetkisiz Giriş', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Bu sisteme giriş yapabilmek için davet edilmiş olmanız gerekmektedir.\n\nLütfen salon sahibi ile iletişime geçin.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam', style: TextStyle(color: AppColors.primaryYellow)),
          ),
        ],
      ),
    );
  }
}
