// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'screens/login/app_login_screen.dart'; // якщо клас у тебе LoginScreen — заміни назву нижче
import 'screens/login/participants_screen.dart';
import 'screens/password_login_screen.dart';
import 'screens/login/fb_oauth_screen.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('uk'));

final initialRouteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('isLoggedIn') ?? false;
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locState = ref.watch(localeProvider);
    final isLoggedInAsync = ref.watch(initialRouteProvider);

    return isLoggedInAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Init error: $e'))),
      ),
      data: (isLoggedIn) {
        final home = isLoggedIn
            ? ParticipantsScreen(
                onLocaleChanged: (l) =>
                    ref.read(localeProvider.notifier).state = l,
              )
            : AppLoginScreen(
                onLocaleChanged: (l) =>
                    ref.read(localeProvider.notifier).state = l,
              );

        return MaterialApp(
          title: 'Giveaway App',
          locale: locState,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: home, // <-- головний екран без initialRoute
          routes: {
            '/login': (ctx) => AppLoginScreen(
                  onLocaleChanged: (l) =>
                      ref.read(localeProvider.notifier).state = l,
                ),
            '/participants': (ctx) => ParticipantsScreen(
                  onLocaleChanged: (l) =>
                      ref.read(localeProvider.notifier).state = l,
                ),
            '/password_login': (ctx) => PasswordLoginScreen(
                  onLocaleChanged: (l) =>
                      ref.read(localeProvider.notifier).state = l,
                ),
            '/fb_oauth': (ctx) => const FbOAuthScreen(),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (_) => AppLoginScreen(
              onLocaleChanged: (l) =>
                  ref.read(localeProvider.notifier).state = l,
            ),
          ),
        );
      },
    );
  }
}
