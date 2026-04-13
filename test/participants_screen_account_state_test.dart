import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/models/participant.dart';
import 'package:giveaway_app/screens/login/participants_screen.dart';
import 'package:giveaway_app/services/appapi/app_participants_service.dart';

class _FakeParticipantsService extends ParticipantsService {
  final ActiveAccountState? accountState;
  bool fetchCalled = false;

  _FakeParticipantsService(this.accountState) : super.withDio(Dio());

  @override
  Future<ActiveAccountState?> getActiveAccountState() async => accountState;

  @override
  Future<List<Participant>> fetchParticipants(
    String postUrl, {
    BuildContext? context,
  }) async {
    fetchCalled = true;
    return const [];
  }
}

Widget _wrapForTest({
  required ParticipantsService service,
}) {
  return MaterialApp(
    locale: const Locale('uk'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      '/login': (_) => const Scaffold(body: Text('LOGIN_SCREEN')),
    },
    home: ParticipantsScreen(
      onLocaleChanged: (_) {},
      participantsService: service,
      showDecorations: false,
    ),
  );
}

void main() {
  testWidgets(
    'participants screen shows blocked account banner and disables draw action',
    (tester) async {
      final service = _FakeParticipantsService(
        const ActiveAccountState(
          accountId: 'acc_1',
          instagramUsername: 'blocked_user',
          status: 'challenge',
          challengeReason: 'worker_media_fetch_challenge',
        ),
      );

      await tester.pumpWidget(_wrapForTest(service: service));
      await tester.pumpAndSettle();

      expect(find.text('Акаунт потребує підтвердження в Instagram'), findsOneWidget);
      expect(find.text('blocked_user'), findsOneWidget);

      final drawButtonFinder = find.byWidgetPredicate(
        (widget) => widget is ElevatedButton,
      );
      expect(drawButtonFinder, findsOneWidget);

      final drawButton = tester.widget<ElevatedButton>(drawButtonFinder);
      expect(drawButton.onPressed, isNull);
      expect(service.fetchCalled, isFalse);
    },
  );

  testWidgets(
    'participants screen navigates to login from blocked account banner',
    (tester) async {
      final service = _FakeParticipantsService(
        const ActiveAccountState(
          accountId: 'acc_2',
          instagramUsername: 'blocked_user',
          status: 'unverified',
        ),
      );

      await tester.pumpWidget(_wrapForTest(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Перейти до входу'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_SCREEN'), findsOneWidget);
    },
  );
}
