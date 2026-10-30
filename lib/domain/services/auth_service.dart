import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import '../../data/local/database.dart';
class AuthService {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // En producción se requiere el clientId para iOS y Web
    // clientId: 'AQUÍ_TU_CLIENT_ID',
  );

  AuthService(this._supabase, this._db);

  /// Inicia sesión con Google usando el SDK nativo
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // El usuario canceló
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw 'No se pudo obtener el ID Token de Google';
      }

      final authResponse = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Migrar datos locales al nuevo usuario si es necesario
      await _claimLocalData(authResponse.user!.id);

      return authResponse;
    } catch (e) {
      debugPrint('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  bool get hasSession => _supabase.auth.currentSession != null;

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (response.session != null && user != null) {
        await _claimLocalData(user.id);
      }
      return response;
    } catch (e) {
      throw AuthException(authErrorMessage(e));
    }
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (response.session != null && user != null) {
        await _claimLocalData(user.id);
      }
      return response;
    } catch (e) {
      throw AuthException(authErrorMessage(e));
    }
  }

  static String authErrorMessage(Object error) {
    if (error is! AuthException) {
      return 'Sin conexión. Revisa tu conexión a internet.';
    }
    final message = error.message;
    if (message.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (message.contains('already registered') ||
        message.contains('user_already_exists')) {
      return 'Ese correo ya está registrado.';
    }
    if (message.contains('Password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Confirma tu correo antes de entrar.';
    }
    if (message.contains('For security purposes') ||
        message.toLowerCase().contains('rate limit')) {
      return 'Demasiados intentos. Espera unos minutos.';
    }
    if (message.toLowerCase().contains('invalid email') ||
        message.toLowerCase().contains('invalid format') ||
        message.contains('Unable to validate email')) {
      return 'El correo no tiene un formato válido.';
    }
    return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }

  /// Llama a la RPC claim_local_data para asignar la data huérfana al nuevo usuario
  Future<void> _claimLocalData(String userId) async {
    try {
      // Obtenemos el local_user_id temporal de drift
      final localProfile = await _db.select(_db.localProfiles).getSingle();
      final localUserId = localProfile.localUserId;

      // Invocamos la RPC en Supabase
      await _supabase.rpc('claim_local_data', params: {
        'p_local_user_id': localUserId,
      });

      // Actualizamos el auth_user_id en drift
      await _db.update(_db.localProfiles).replace(
        localProfile.copyWith(authUserId: Value(userId)),
      );
      debugPrint('Datos locales migrados al usuario $userId');
    } catch (e) {
      debugPrint('Error en _claimLocalData: $e');
      // No rethrow para no romper el flujo de login si falla por red
    }
  }

  /// Cierra sesión
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }
}
