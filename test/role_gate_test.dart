// Locks in the role-gate behaviour on the shared AuthBloc: a freshly
// logged-in user whose roles don't match the app's filter is forced
// back out with a tailored error message. Mirrors what the Sales App
// wires in main.dart (`sales_rep | sales_manager | super_admin`).
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ion_sales_app/shared.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthUser(
      id: '', employeeId: '', fullName: '', email: '', phone: '', active: true,
    ));
  });

  // Helper to assemble a session with arbitrary roles.
  AuthSession sessionWithRoles(List<String> roles) => AuthSession(
        user: const AuthUser(
          id: 'u1', employeeId: 'e1', fullName: 'Tester', email: 't@x',
          phone: '0', active: true,
        ),
        roles: roles,
        permissions: const [],
      );

  group('AuthBloc role gate', () {
    late _MockRepo repo;
    setUp(() {
      repo = _MockRepo();
      when(() => repo.logout()).thenAnswer((_) async {});
    });

    final salesFilter = (AuthSession s) =>
        s.hasRole('super_admin') ||
        s.hasRole('sales_rep') ||
        s.hasRole('sales_manager');

    blocTest<AuthBloc, AuthState>(
      'login with sales_rep passes',
      build: () {
        when(() => repo.login(email: any(named: 'email'), password: any(named: 'password')))
            .thenAnswer((_) async => sessionWithRoles(['sales_rep']));
        return AuthBloc(repo, roleFilter: salesFilter);
      },
      act: (b) => b.add(const AuthLoginRequested(email: 'a', password: 'b')),
      expect: () => [
        isA<AuthState>().having((s) => s.status, 'status', AuthStatus.authenticating),
        isA<AuthState>().having((s) => s.status, 'status', AuthStatus.authenticated),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'login with technician fails the filter, gets logged out + error',
      build: () {
        when(() => repo.login(email: any(named: 'email'), password: any(named: 'password')))
            .thenAnswer((_) async => sessionWithRoles(['technician']));
        return AuthBloc(repo,
            roleFilter: salesFilter,
            roleFilterErrorMessage: 'sales reps only');
      },
      act: (b) => b.add(const AuthLoginRequested(email: 'a', password: 'b')),
      expect: () => [
        isA<AuthState>().having((s) => s.status, 'status', AuthStatus.authenticating),
        isA<AuthState>()
            .having((s) => s.status, 'status', AuthStatus.error)
            .having((s) => s.errorMessage, 'message', contains('sales reps only')),
      ],
      verify: (_) => verify(() => repo.logout()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'restore with mismatched roles also fails closed',
      build: () {
        when(() => repo.restore())
            .thenAnswer((_) async => sessionWithRoles(['technician']));
        return AuthBloc(repo, roleFilter: salesFilter);
      },
      act: (b) => b.add(const AuthRestoreRequested()),
      expect: () => [
        isA<AuthState>().having((s) => s.status, 'status', AuthStatus.error),
      ],
      verify: (_) => verify(() => repo.logout()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'no filter wired = any role passes',
      build: () {
        when(() => repo.login(email: any(named: 'email'), password: any(named: 'password')))
            .thenAnswer((_) async => sessionWithRoles(['random_role']));
        return AuthBloc(repo); // no roleFilter
      },
      act: (b) => b.add(const AuthLoginRequested(email: 'a', password: 'b')),
      expect: () => [
        isA<AuthState>().having((s) => s.status, 'status', AuthStatus.authenticating),
        isA<AuthState>().having((s) => s.status, 'status', AuthStatus.authenticated),
      ],
    );
  });
}
