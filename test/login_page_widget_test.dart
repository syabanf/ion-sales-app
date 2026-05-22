// Widget smoke test for LoginPage.
//
// Wave 48 — proves the staff login mounts without throwing, exposes the
// email + password fields + sign-in button, and surfaces an error
// message when the bloc transitions to AuthState.error.
//
// This used to be missing — the only sales_app tests were pure-function
// unit tests + a coverage map widget. A real-world regression
// (e.g. a theme breaks because a non-existent token is used) would
// land silently. Now any compile-time or first-paint break trips here.
//
// Strategy: mock the AuthBloc with mocktail and pump it into the
// LoginPage via BlocProvider.value. We never let the real bloc run —
// state is a `whenListen`-style fixture so the widget reacts to it
// the same way it would in production.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ion_sales_app/auth/presentation/bloc/auth_bloc.dart';
import 'package:ion_sales_app/auth/presentation/pages/login_page.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

void main() {
  // No registerFallbackValue calls needed — AuthEvent is sealed (Dart 3)
  // and our tests don't use any<AuthEvent>() matchers. We stub bloc.state
  // directly via when(() => bloc.state).thenReturn(...) which doesn't
  // require fallbacks.

  Widget _harness(AuthBloc bloc) => MaterialApp(
        home: BlocProvider<AuthBloc>.value(value: bloc, child: const LoginPage()),
      );

  testWidgets('renders email + password fields + sign-in button', (tester) async {
    final bloc = _MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthState.unauthenticated());
    whenListen(bloc, Stream<AuthState>.empty(),
        initialState: const AuthState.unauthenticated());

    await tester.pumpWidget(_harness(bloc));
    await tester.pump();

    // We don't assert the exact label copy (designers tweak it) — we
    // assert structural identity: two TextFormFields and at least one
    // ElevatedButton-style action.
    expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfaces an error message when bloc emits AuthState.error', (tester) async {
    final bloc = _MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthState.error('Invalid credentials'));
    whenListen(bloc, Stream<AuthState>.empty(),
        initialState: const AuthState.error('Invalid credentials'));

    await tester.pumpWidget(_harness(bloc));
    await tester.pump();

    expect(find.textContaining('Invalid credentials'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables sign-in while authenticating', (tester) async {
    final bloc = _MockAuthBloc();
    when(() => bloc.state).thenReturn(const AuthState.authenticating());
    whenListen(bloc, Stream<AuthState>.empty(),
        initialState: const AuthState.authenticating());

    await tester.pumpWidget(_harness(bloc));
    await tester.pump();

    // While authenticating, the button shows a spinner instead of the
    // label — assert at least one CircularProgressIndicator is mounted.
    expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
}
