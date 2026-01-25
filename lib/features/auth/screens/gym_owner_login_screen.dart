
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
import 'package:fitflow/core/constants/legal_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_pending_screen.dart';
import '../../profile/screens/change_password_screen.dart';

class GymOwnerLoginScreen extends StatefulWidget {
  const GymOwnerLoginScreen({super.key});

  @override
  State<GymOwnerLoginScreen> createState() => _GymOwnerLoginScreenState();
}

class _GymOwnerLoginScreenState extends State<GymOwnerLoginScreen> {
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
  bool _isKvkkAccepted = false;
  
  // New State for View Switching
  bool _isLoginView = true;
  
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _gymNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  bool _validatePassword(String password) {
    if (password.length < 6) {
      CustomSnackBar.showError(context, 'Şifre en az 6 karakter olmalıdır');
      return false;
    }
    // Check for special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      CustomSnackBar.showError(context, 'Şifre en az bir özel karakter içermelidir (!@#\$%^&*...)');
      return false;
    }
    return true;
  }

  Future<void> _completeOwnerRegistration() async {
    try {
      await _supabase.rpc('complete_owner_registration', params: {
          'gym_name': _gymNameController.text.trim(),
          'city': _selectedCity ?? '',
          'district': _selectedDistrict ?? '',
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
      });
      
      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Kayıt başarıyla tamamlandı!');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (rpcError) {
        debugPrint('Owner registration completion failed: $rpcError');
        if (mounted) CustomSnackBar.showError(context, 'Kayıt tamamlanırken bir hata oluştu: $rpcError');
    }
  }

  Future<void> _handleAuth({bool isRegister = false}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      CustomSnackBar.showError(context, 'Lütfen email ve şifre girin');
      return;
    }

    if (isRegister) {
      if (!_isKvkkAccepted) {
        CustomSnackBar.showError(context, 'Lütfen KVKK Aydınlatma Metnini onaylayın.');
        return;
      }
      if (!_validatePassword(password)) return;    

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

    // Check if we are already authenticated (e.g. via Google but incomplete)
    final currentUser = _supabase.auth.currentUser;
    // Check if email matches current user (to ensure we are completing the CORRECT user)
    // If currentUser is anonymous or different email, ignore.
    if (currentUser != null && currentUser.email != null && currentUser.email == email) {
       // We are ALREADY logged in (Google User completing registration)
       if (isRegister) {
          await _completeOwnerRegistration();
          setState(() => _isLoading = false);
          return;
       }
    }

    debugPrint('Attempting Register with Email: "$email" (Length: ${email.length})');
    email.runes.forEach((int rune) {
       var character = String.fromCharCode(rune);
       debugPrint('Char: $character Code: $rune');
    });

    try {
      AuthResponse response;
      
      // Check if we already have a user (e.g. from Google Sign In) who is completing registration
      final currentUser = _supabase.auth.currentUser;
      
      if (isRegister && currentUser != null) {
         // Verify Email match (security check)
         if (currentUser.email != email) {
            throw 'Giriş yapılan hesap ile formdaki email uyuşmuyor.';
         }
         
         // Update Metadata
         await _supabase.auth.updateUser(
           UserAttributes(
             data: {
               'first_name': _firstNameController.text.trim(),
               'last_name': _lastNameController.text.trim(),
               'role': 'owner',
               'gym_name': _gymNameController.text.trim(),
               'city': _selectedCity ?? '',
               'district': _selectedDistrict ?? '',
               'password_changed': true,
             }
           )
         );
         
         // Complete Registration (Create Org)
         // This assumes the user is already signed in, so we just need to run the RPC
         await _completeOwnerRegistration();
         
         if (mounted) {
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const DashboardScreen()),
             (route) => false,
           );
         }
         return;
      }

      if (isRegister) {
        response = await _supabase.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: 'io.supabase.fitflow://login-callback',
          data: {
             'first_name': _firstNameController.text.trim(),
             'last_name': _lastNameController.text.trim(),
             'role': 'owner',
             'gym_name': _gymNameController.text.trim(),
             'city': _selectedCity ?? '',
             'district': _selectedDistrict ?? '',
             'password_changed': true, // Owners set their own password, no need to change
          }
        );

        if (response.session != null) {
           await _completeOwnerRegistration();

          // Check if user is already verified (e.g. Google User)
          // If so, skip the dialog and go straight to dashboard
          final user = response.user;
          if (user != null && user.emailConfirmedAt != null) {
             if (mounted) {
               Navigator.of(context).pushAndRemoveUntil(
                 MaterialPageRoute(builder: (context) => const DashboardScreen()),
                 (route) => false,
               );
             }
             return;
          }
        }

        // For email verification flow (Unverified users):
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
                    setState(() => _isLoginView = true); // Switch to Login view
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
          // Check Role
          final userId = response.session!.user.id;
          final profileData = await _supabase
              .from('profiles')
              .select('role')
              .eq('id', userId)
              .maybeSingle();
              
          if (profileData == null || profileData['role'] != 'owner') {
             await _supabase.auth.signOut();
             if (mounted) {
               CustomSnackBar.showError(context, 'Antrenörler antrenör girişinden girmelidir.');
             }
             return;
          }
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
             CustomSnackBar.showError(context, ErrorMessageTranslator.translateAuthError(e));
           }
        } else {
           // Login specific errors
           if (e.message.contains('Email not confirmed')) {
             CustomSnackBar.showError(context, 'Lütfen mailinizden hesabınızı onaylayın');
           } else if (e.message.contains('Invalid login credentials') || e.statusCode == '400') {
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
       // This MUST match the "Web client ID" in Google Cloud Console
       const webClientId = '431063576237-npfq2tnlukv1hv7cit6lig9mktvmq8pl.apps.googleusercontent.com';

       final GoogleSignIn googleSignIn = GoogleSignIn(
         serverClientId: webClientId,
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

          final role = profileData?['role'];
          
          // If user is definitely a member or trainer, block them from Owner App
          if (role == 'member' || role == 'trainer') {
             await _supabase.auth.signOut();
             if (mounted) {
               CustomSnackBar.showError(context, 'Bu hesap bir üye veya antrenör hesabıdır. Lütfen ilgili uygulamayı kullanın.');
             }
             return;
          }

          // If role is null (new) or owner, but no org -> Incomplete Registration
          if (profileData == null || profileData['organization_id'] == null) {
              // Ask for confirmation before assuming they want to create a gym
              if (mounted) {
                 await _showRegistrationConfirmDialog(response.user);
              }
              setState(() => _isLoading = false);
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

  // Confirm Dialog for Google Users to register new Gym
  Future<void> _showRegistrationConfirmDialog(User? user) async {
     return showDialog(
       context: context,
       barrierDismissible: false, 
       builder: (BuildContext context) {
         return AlertDialog(
           backgroundColor: AppColors.surface,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           title: const Text('Yeni Salon Kaydı', style: TextStyle(color: Colors.white)),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Text(
                 'Bu Google hesabı ile FitFlow\'a kayıtlı bir salon bulunamadı.',
                 style: TextStyle(color: Colors.grey),
               ),
               const SizedBox(height: 12),
               const Text(
                 'Yeni bir salon kaydı oluşturmak istiyor musunuz?',
                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
               ),
             ],
           ),
           actions: [
             TextButton(
               child: const Text('İptal', style: TextStyle(color: Colors.red)),
               onPressed: () async {
                 await _supabase.auth.signOut();
                 Navigator.of(context).pop();
               },
             ),
             TextButton(
               child: const Text('Devam Et', style: TextStyle(color: AppColors.primaryYellow)),
               onPressed: () {
                 Navigator.of(context).pop();
                 setState(() {
                    _isLoginView = false; // Switch to Register View
                 });
                 // Pre-fill fields if available
                 if (user?.email != null) {
                    _emailController.text = user!.email!;
                    // Extract name parts if available (basic logic)
                    if (user.userMetadata != null && user.userMetadata?['full_name'] != null) {
                       String fullName = user.userMetadata!['full_name'];
                       List<String> parts = fullName.split(' ');
                       if (parts.isNotEmpty) {
                          _firstNameController.text = parts.first;
                          if (parts.length > 1) {
                             _lastNameController.text = parts.sublist(1).join(' ');
                          }
                       }
                    }
                 }
                 CustomSnackBar.showInfo(context, 'Lütfen salon bilgilerinizi tamamlayın.');
               },
             ),
           ],
         );
       },
     );
  }

  void _showKvkkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'KVKK Aydınlatma Metni',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                  LegalConstants.kvkkText,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomButton(
                text: 'Okudum, Anladım',
                onPressed: () {
                   setState(() => _isKvkkAccepted = true);
                   Navigator.pop(context);
                },
                backgroundColor: AppColors.primaryYellow,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Handled by AmbientBackground
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Salon Sahibi Paneli', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: _isLoginView ? _buildLoginForm() : _buildRegisterForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        GlassCard(
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
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => setState(() => _isLoginView = false),
          child: RichText(
            text: TextSpan(
              text: 'Hesabınız yok mu? ',
              style: TextStyle(color: Colors.grey[400]),
              children: [
                TextSpan(
                  text: 'Kayıt Ol',
                  style: TextStyle(
                    color: AppColors.primaryYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        GlassCard(
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
              CustomTextField(
                controller: _firstNameController, 
                label: 'Adı',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _lastNameController, 
                label: 'Soyadı',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _gymNameController, 
                label: 'Salon Adı', 
                prefixIcon: const Icon(Icons.fitness_center, color: AppColors.primaryYellow)
              ),
              const SizedBox(height: 16),
              // City Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: InputDecoration(
                  labelText: 'İl',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.location_city, color: AppColors.primaryYellow),
                  filled: true,
                  fillColor: AppColors.surfaceDark,
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
                dropdownColor: AppColors.surfaceDark,
                style: AppTextStyles.body,
                menuMaxHeight: 300,
                // FIX: Use cityNames static getter
                items: TurkeyCities.cityNames.map((city) {
                  return DropdownMenuItem(value: city, child: Text(city));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCity = value;
                    _selectedDistrict = null; // Reset district
                  });
                },
              ),
              const SizedBox(height: 16),
              // District Dropdown
               DropdownButtonFormField<String>(
                value: _selectedDistrict,
                decoration: InputDecoration(
                  labelText: 'İlçe',
                   labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.map, color: AppColors.primaryYellow),
                  filled: true,
                   fillColor: AppColors.surfaceDark,
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
                 dropdownColor: AppColors.surfaceDark,
                 style: AppTextStyles.body,
                 menuMaxHeight: 300,
                // FIX: Use getDistricts method
                items: _selectedCity == null
                    ? []
                    : TurkeyCities.getDistricts(_selectedCity!).map((district) {
                        return DropdownMenuItem(value: district, child: Text(district));
                      }).toList(),
                onChanged: _selectedCity == null ? null : (value) => setState(() => _selectedDistrict = value),
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
                  icon: Icon(_isRegisterPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                  onPressed: () => setState(() => _isRegisterPasswordVisible = !_isRegisterPasswordVisible),
                ),
              ),
              const SizedBox(height: 16),
              
              // KVKK Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   Checkbox(
                    value: _isKvkkAccepted, 
                    activeColor: AppColors.primaryYellow,
                    checkColor: Colors.black,
                    side: const BorderSide(color: Colors.grey),
                    onChanged: (val) => setState(() => _isKvkkAccepted = val ?? false),
                   ),
                   Expanded(
                     child: GestureDetector(
                       onTap: _showKvkkDialog,
                       child: RichText(
                         text: TextSpan(
                           style: const TextStyle(color: Colors.grey, fontSize: 13),
                           children: [
                             TextSpan(
                               text: 'KVKK Aydınlatma Metni',
                               style: TextStyle(
                                 color: AppColors.primaryYellow,
                                 decoration: TextDecoration.underline,
                               ),
                             ),
                             const TextSpan(text: '\'ni okudum ve kabul ediyorum.'),
                           ],
                         ),
                       ),
                     ),
                   ),
                ],
              ),

              const SizedBox(height: 24),
              CustomButton(
                text: 'Kayıt Ol',
                onPressed: () => _handleAuth(isRegister: true),
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
                label: const Text('Google ile Devam Et'), // Google Sign In stays for Owner
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
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => setState(() => _isLoginView = true),
          child: RichText(
            text: TextSpan(
              text: 'Zaten hesabınız var mı? ',
              style: TextStyle(color: Colors.grey[400]),
              children: [
                TextSpan(
                  text: 'Giriş Yap',
                  style: TextStyle(
                    color: AppColors.primaryYellow,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
