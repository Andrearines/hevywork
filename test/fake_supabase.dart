import 'package:supabase_flutter/supabase_flutter.dart';

class FakeGoTrue extends GoTrueClient {
  FakeGoTrue()
      : super(
          url: 'http://localhost:54321/auth/v1',
          autoRefreshToken: false,
        );

  Session? session;
  Object? signInError;
  Object? signUpError;
  bool signUpWithoutSession = false;
  String? lastEmail;
  String? lastPassword;

  @override
  Session? get currentSession => session;

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    required String password,
    String? captchaToken,
  }) async {
    lastEmail = email;
    lastPassword = password;
    final error = signInError;
    if (error != null) throw error;
    final user = _user();
    session = _sessionOf(user);
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    required String password,
    String? emailRedirectTo,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {
    lastEmail = email;
    lastPassword = password;
    final error = signUpError;
    if (error != null) throw error;
    final user = _user();
    if (signUpWithoutSession) {
      return AuthResponse(user: user);
    }
    session = _sessionOf(user);
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    session = null;
  }

  User _user() => const User(
        id: 'user-test',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      );

  Session _sessionOf(User user) => Session(
        accessToken: 'access-token',
        tokenType: 'bearer',
        user: user,
      );
}

class FakeSupabase extends SupabaseClient {
  FakeSupabase(this.goTrue)
      : super(
          'http://localhost:54321',
          'anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );

  final FakeGoTrue goTrue;
  final List<({String fn, Map<String, dynamic>? params})> rpcCalls = [];

  @override
  GoTrueClient get auth => goTrue;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    rpcCalls.add((fn: fn, params: params));
    throw StateError('rpc no disponible en tests: $fn');
  }
}
