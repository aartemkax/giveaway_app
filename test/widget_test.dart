import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giveaway_app/main.dart';

void main() {
  setUp(() {
    dotenv.testLoad(
      fileInput: 'API_BASE_URL=http://localhost:8080\n',
    );
  });

  testWidgets('MyApp shows startup loading shell while auth state is resolving',
      (WidgetTester tester) async {
    final pendingAuth = Completer<AuthState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => pendingAuth.future),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('LOCAL'), findsOneWidget);
  });
}
