import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_config.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize Firebase (for Notifications)
  try {
    await Firebase.initializeApp();
    // Start Notification Service
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  await initializeDateFormatting('tr_TR', null);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const PTBodyChangeApp());
}

class PTBodyChangeApp extends StatelessWidget {
  const PTBodyChangeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PT Body Change',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Supabase.instance.client.auth.currentSession != null
          ? const DashboardScreen()
          : const LoginScreen(),
    );
  }
}
