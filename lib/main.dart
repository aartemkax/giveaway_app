// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/participants_screen.dart';
import 'services/auth_service.dart';
import 'utils/api_exception.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('uk');
  void _switchLocale(Locale l) => setState(() => _locale = l);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.app_name,
      initialRoute: '/gate',
      routes: {
        '/gate': (_) => _Gate(onLocaleChanged: _switchLocale),
        '/login': (_) => LoginScreen(onLocaleChanged: _switchLocale),
        '/participants': (_) =>
            ParticipantsScreen(onLocaleChanged: _switchLocale),
      },
    );
  }
}

class _Gate extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const _Gate({required this.onLocaleChanged});
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final m = await AuthService().debugSession();
      final ok = m['ig_settings_present'] == true;
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacementNamed(ok ? '/participants' : '/login');
    } on ApiException {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            // Можна додати логотип/текст, але не обов'язково
          ],
        ),
      ),
    );
  }
}
