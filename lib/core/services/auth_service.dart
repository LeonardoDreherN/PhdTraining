import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static User? get currentUser => _supabase.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  static Future<AuthResponse> cadastrarPersonal({
    required String email,
    required String password,
    required String nome,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'nome': nome, 'role': 'personal'},
    );
  }

  static Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }
}
