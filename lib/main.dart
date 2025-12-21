// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/services/api_client.dart';

import 'screens/login/app_login_screen.dart';
import 'screens/login/participants_screen.dart';
import 'screens/password_login_screen.dart';
import 'screens/login/fb_oauth_screen.dart';
import 'screens/fb_home_screen.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('uk'));

typedef AuthState = ({bool isLoggedIn, String authMethod});

final authStateProvider = FutureProvider<AuthState>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return (
    isLoggedIn: prefs.getBool('isLoggedIn') ?? false,
    authMethod: (prefs.getString('auth_method') ?? '').trim(),
  );
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // спочатку .env (apiBaseUrl читає dotenv)
  await dotenv.load(fileName: '.env');

  // потім init Dio + cookie jar
  await ApiClient().init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Init error: $e'))),
      ),
      data: (st) {
        final Widget home = !st.isLoggedIn
            ? AppLoginScreen(
                onLocaleChanged: (l) =>
                    ref.read(localeProvider.notifier).state = l,
              )
            : (st.authMethod == 'fb'
                ? const FbHomeScreen()
                : ParticipantsScreen(
                    onLocaleChanged: (l) =>
                        ref.read(localeProvider.notifier).state = l,
                  ));

        return MaterialApp(
          title: 'Giveaway App',
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: home,
          routes: {
            '/login': (_) => AppLoginScreen(
                  onLocaleChanged: (l) =>
                      ref.read(localeProvider.notifier).state = l,
                ),
            '/participants': (_) => ParticipantsScreen(
                  onLocaleChanged: (l) =>
                      ref.read(localeProvider.notifier).state = l,
                ),
            '/password_login': (_) => PasswordLoginScreen(
                  onLocaleChanged: (l) =>
                      ref.read(localeProvider.notifier).state = l,
                ),
            '/fb_oauth': (_) => const FbOAuthScreen(),
            '/fb_home': (_) => const FbHomeScreen(),
          },
        );
      },
    );
  }
}
