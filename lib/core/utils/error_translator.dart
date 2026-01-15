import 'package:supabase_flutter/supabase_flutter.dart';

/// Utility class to translate Supabase error messages to Turkish
class ErrorMessageTranslator {
  /// Translates Supabase AuthException messages to Turkish
  static String translateAuthError(AuthException exception) {
    final message = exception.message.toLowerCase();
    
    // Password-related errors
    if (message.contains('new password should be different')) {
      return 'Yeni şifre eski şifreden farklı olmalıdır';
    }
    if (message.contains('password') && message.contains('same')) {
      return 'Yeni şifre eski şifreden farklı olmalıdır';
    }
    if (message.contains('password') && message.contains('weak')) {
      return 'Şifre çok zayıf, daha güçlü bir şifre seçin';
    }
    if (message.contains('password') && message.contains('short')) {
      return 'Şifre en az 6 karakter olmalıdır';
    }
    if (message.contains('password') && message.contains('character')) {
      return 'Şifre en az bir özel karakter içermelidir (!@#\$%^&*...)';
    }
    if (message.contains('invalid') && message.contains('password')) {
      return 'Geçersiz şifre';
    }
    
    // Email-related errors
    if (message.contains('email') && message.contains('invalid')) {
      return 'Geçersiz e-posta adresi';
    }
    if (message.contains('validate email') && message.contains('invalid format')) {
      return 'Lütfen geçerli bir e-posta adresi girin';
    }
    if (message.contains('email') && message.contains('already')) {
      return 'Bu e-posta adresi zaten kullanılıyor';
    }
    if (message.contains('email') && message.contains('not found')) {
      return 'Bu e-posta adresi kayıtlı değil';
    }
    
    // Login errors
    if (message.contains('invalid') && message.contains('credentials')) {
      return 'E-posta veya şifre hatalı';
    }
    if (message.contains('email not confirmed')) {
      return 'E-posta adresi doğrulanmamış';
    }
    
    // Token/Link errors
    if (message.contains('expired')) {
      return 'Bağlantı süresi dolmuş';
    }
    if (message.contains('invalid') && message.contains('token')) {
      return 'Geçersiz doğrulama bağlantısı';
    }
    
    // Rate limiting
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Çok fazla deneme yaptınız, lütfen bir süre bekleyin';
    }
    
    // Network errors
    if (message.contains('network')) {
      return 'Bağlantı hatası, lütfen internet bağlantınızı kontrol edin';
    }
    
    // Generic fallback
    return 'Bir hata oluştu: ${exception.message}';
  }
  
  /// Translates general exceptions to Turkish
  static String translateError(Object error) {
    if (error is AuthException) {
      return translateAuthError(error);
    }
    
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('socket')) {
      return 'Bağlantı hatası';
    }
    if (errorString.contains('timeout')) {
      return 'İstek zaman aşımına uğradı';
    }
    
    return 'Beklenmeyen bir hata oluştu';
  }
}
