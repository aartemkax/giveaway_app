// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/participants_screen.dart';
import 'package:giveaway_app/services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // важливо: підключити PersistCookieJar до Dio
  await ApiClient().initCookies();

  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(initialRoute: isLoggedIn ? '/participants' : '/login'));
}

class MyApp extends StatefulWidget {
  final String initialRoute;
  const MyApp({required this.initialRoute, super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('uk');

  void _switchLocale(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.app_name,
      initialRoute: widget.initialRoute,
      routes: {
        '/': (ctx) => LoginScreen(onLocaleChanged: _switchLocale),
        '/login': (ctx) => LoginScreen(onLocaleChanged: _switchLocale),
        '/participants': (ctx) =>
            ParticipantsScreen(onLocaleChanged: _switchLocale),
      },
    );
  }
}
