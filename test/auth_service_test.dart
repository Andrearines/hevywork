import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/domain/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_supabase.dart';

void main() {
  late AppDatabase db;
  late FakeGoTrue goTrue;
  late FakeSupabase supabase;
  late AuthService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    goTrue = FakeGoTrue();
    supabase = FakeSupabase(goTrue);
    service = AuthService(supabase, db);
  });

  tearDown(() => db.close());

  group('hasSession', () {
    test('es false sin sesión', () {
      expect(service.hasSession, isFalse);
    });

    test('es true tras iniciar sesión con correo', () async {
      await service.signInWithEmail(email: 'a@b.co', password: 'clave');
      expect(service.hasSession, isTrue);
    });
  });

  group('signInWithEmail', () {
    test('ejecuta claim_local_data con el local_user_id y abre sesión',
        () async {
      final response = await service.signInWithEmail(
        email: '  atleta@hevywork.app  ',
        password: 'clave-secreta',
      );

      expect(goTrue.lastEmail, 'atleta@hevywork.app');
      expect(goTrue.lastPassword, 'clave-secreta');
      expect(response.user?.id, 'user-test');
      expect(service.hasSession, isTrue);

      final call = supabase.rpcCalls.single;
      expect(call.fn, 'claim_local_data');
      expect(call.params?['p_local_user_id'], isNotEmpty);
    });

    test('propaga credenciales inválidas con el error traducido', () async {
      goTrue.signInError = const AuthException('Invalid login credentials');

      await expectLater(
        service.signInWithEmail(email: 'a@b.co', password: 'mala'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Correo o contraseña incorrectos.',
          ),
        ),
      );
      expect(service.hasSession, isFalse);
    });

    test('traduce un error de red a sin conexión', () async {
      goTrue.signInError = Exception('socket falló');

      await expectLater(
        service.signInWithEmail(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Sin conexión. Revisa tu conexión a internet.',
          ),
        ),
      );
    });
  });

  group('signUpWithEmail', () {
    test('con sesión (confirmación desactivada) ejecuta el claim', () async {
      final response = await service.signUpWithEmail(
        email: 'nuevo@hevywork.app',
        password: 'clave-larga',
      );

      expect(response.session, isNotNull);
      expect(supabase.rpcCalls.single.fn, 'claim_local_data');
    });

    test('sin sesión (confirmación de correo) no ejecuta el claim', () async {
      goTrue.signUpWithoutSession = true;

      final response = await service.signUpWithEmail(
        email: 'nuevo@hevywork.app',
        password: 'clave-larga',
      );

      expect(response.session, isNull);
      expect(response.user, isNotNull);
      expect(supabase.rpcCalls, isEmpty);
      expect(service.hasSession, isFalse);
    });

    test('propaga correo ya registrado con el error traducido', () async {
      goTrue.signUpError = const AuthException('User already registered');

      await expectLater(
        service.signUpWithEmail(email: 'a@b.co', password: 'clave-larga'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Ese correo ya está registrado.',
          ),
        ),
      );
    });
  });

  group('authErrorMessage', () {
    test('traduce los errores habituales de Supabase Auth', () {
      expect(
        AuthService.authErrorMessage(
          const AuthException('Invalid login credentials'),
        ),
        'Correo o contraseña incorrectos.',
      );
      expect(
        AuthService.authErrorMessage(
          const AuthException('User already registered'),
        ),
        'Ese correo ya está registrado.',
      );
      expect(
        AuthService.authErrorMessage(
          const AuthException('Password should be at least 6 characters'),
        ),
        'La contraseña debe tener al menos 6 caracteres.',
      );
      expect(
        AuthService.authErrorMessage(
          const AuthException('Email not confirmed'),
        ),
        'Confirma tu correo antes de entrar.',
      );
      expect(
        AuthService.authErrorMessage(
          const AuthException('For security purposes, try again later'),
        ),
        'Demasiados intentos. Espera unos minutos.',
      );
    });

    test('usa un mensaje genérico para errores de Auth desconocidos', () {
      expect(
        AuthService.authErrorMessage(const AuthException('algo raro')),
        'No se pudo completar la operación. Inténtalo de nuevo.',
      );
    });

    test('usa sin conexión para errores que no son de Auth', () {
      expect(
        AuthService.authErrorMessage(Exception('timeout')),
        'Sin conexión. Revisa tu conexión a internet.',
      );
    });
  });
}
