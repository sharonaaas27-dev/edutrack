// EduTrack Stage 1 widget tests (Stage 6: app boots through splash).

import 'package:edutrack/core/utils/validators.dart';
import 'package:edutrack/main.dart';
import 'package:edutrack/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('email validator rejects empty and invalid input', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('student@edutrack.com'), isNull);
    });

    test('password validator enforces required + min length', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('123'), isNotNull);
      expect(Validators.password('student123'), isNull);
    });
  });

  testWidgets('Login screen renders form fields', (tester) async {
    await tester.pumpWidget(EduTrackApp(tokenStorage: InMemoryTokenStorage()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Empty form shows validation errors', (tester) async {
    await tester.pumpWidget(EduTrackApp(tokenStorage: InMemoryTokenStorage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });
}
