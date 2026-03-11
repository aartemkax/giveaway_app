// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:giveaway_app/services/api_client.dart';
import 'package:giveaway_app/services/auth_service.dart';

import 'screens/login/app_login_screen.dart';
import 'screens/login/participants_screen.dart';
import 'screens/password_login_screen.dart';
import 'screens/login/fb_oauth_screen.dart';
import 'screens/fb_home_screen.dart';
import 'screens/ig_media_screen.dart';
import 'screens/ig_comments_screen.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('uk'));

typedef AuthState = ({bool isLoggedIn, String authMethod});

class StartupGate extends ConsumerWidget {
  final ValueChanged<Locale> onLocaleChanged;

  const StartupGate({
    required this.onLocaleChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => AppLoginScreen(
        onLocaleChanged: onLocaleChanged,
      ),
      data: (state) {
        if (!state.isLoggedIn) {
          return AppLoginScreen(
            onLocaleChanged: onLocaleChanged,
          );
        }

        if (state.authMethod == 'fb') {
          return const FbHomeScreen();
        }

        return ParticipantsScreen(
          onLocaleChanged: onLocaleChanged,
        );
      },
    );
  }
}

final authStateProvider = FutureProvider<AuthState>((ref) async {
  await ApiClient().init();

  final prefs = await SharedPreferences.getInstance();
  final authMethod = (prefs.getString('auth_method') ?? '').trim();

  if (authMethod.isEmpty) {
    return (isLoggedIn: false, authMethod: '');
  }

  try {
    if (authMethod == 'fb') {
      final data = await AuthService().debugSession();
      final ok = data['fb_user_token_present'] == true;
      if (ok) {
        return (isLoggedIn: true, authMethod: 'fb');
      }
    }

    if (authMethod == 'ig') {
      final ok = await AuthService().hasValidSession();
      if (ok) {
        return (isLoggedIn: true, authMethod: 'ig');
      }
    }
  } catch (_) {
    // бек недоступний або помилка перевірки
  }

  await prefs.remove('auth_method');
  await ApiClient().clearCookies();

  return (isLoggedIn: false, authMethod: '');
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await ApiClient().init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Giveaway App',
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      initialRoute: '/',
      routes: {
        '/': (_) => StartupGate(
              onLocaleChanged: (l) =>
                  ref.read(localeProvider.notifier).state = l,
            ),
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
        '/ig_media': (_) => const IgMediaScreen(),
        '/ig_comments': (_) => const IgCommentsScreen(),
      },
    );
  }
}
