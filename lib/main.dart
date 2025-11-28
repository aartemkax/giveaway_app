import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:giveaway_app/l10n/app_localizations.dart';
import 'screens/login/app_login_screen.dart';
import 'screens/participants_screen.dart'; // ← виправлено шлях
import 'screens/password_login_screen.dart';
import 'screens/login/fb_oauth_screen.dart';

// Riverpod: провайдер локалі
final localeProvider = StateProvider<Locale>((ref) => const Locale('uk'));

// Riverpod: провайдер початкового роута
final initialRouteProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  return isLoggedIn ? '/participants' : '/login';
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
    final initialRouteAsync = ref.watch(initialRouteProvider);

    return initialRouteAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Init error: $e'))),
      ),
      data: (initialRoute) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locState,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.app_name,
          initialRoute: initialRoute,
          routes: {
            '/': (ctx) => AppLoginScreen(
                onLocaleChanged: (l) =>
                    ref.read(localeProvider.notifier).state = l),
            '/login': (ctx) => AppLoginScreen(
                onLocaleChanged: (l) =>
                    ref.read(localeProvider.notifier).state = l),
            '/participants': (ctx) => ParticipantsScreen(
                onLocaleChanged: (l) =>
                    ref.read(localeProvider.notifier).state = l),
            '/password_login': (ctx) => PasswordLoginScreen(
                onLocaleChanged: (l) =>
                    ref.read(localeProvider.notifier).state = l),
            '/fb_oauth': (ctx) => const FbOAuthScreen(),
          },
        );
      },
    );
  }
}
