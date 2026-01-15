import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/colors.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../core/utils/error_translator.dart';
import '../../shared/widgets/custom_snackbar.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      if (user == null) {
        // Should not happen if this screen is only shown when session exists
        return; 
      }

      // Fetch Profile to check integrity
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
         // Profile missing entirely
         await _handleInvalidUser('Profil bulunamadı.');
         return;
      }

      final organizationId = response['organization_id'];
      if (organizationId == null) {
         // Incomplete Registration (Dummy User)
         await _handleInvalidUser('Kaydınız tamamlanmamış. Lütfen tekrar giriş yapın.');
         return;
      }

      // Valid User -> Navigate to Dashboard
      // We use pushReplacement to remove this check screen from stack
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );

    } catch (e) {
      if (mounted) {
         // In case of error (network etc), log out to be safe or retry?
         // For now, let's sign out to prevent stuck state
         await _handleInvalidUser('Kullanıcı durumu kontrol edilemedi: $e');
      }
    }
  }

  Future<void> _handleInvalidUser(String message) async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
       CustomSnackBar.showError(context, message);
       // The StreamBuilder in main.dart will automatically handle the redirect to WelcomeScreen
       // because auth state changes to null.
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             // You can replace this with your app logo
             Icon(Icons.fitness_center, size: 60, color: AppColors.primaryYellow),
             SizedBox(height: 24),
             CircularProgressIndicator(color: AppColors.primaryYellow),
             SizedBox(height: 16),
             Text('Kullanıcı bilgileri kontrol ediliyor...', 
               style: TextStyle(color: Colors.white70),
             ),
          ],
        ),
      ),
    );
  }
}
