// lib/screens/fb_home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:giveaway_app/services/api_client.dart';

class FbHomeScreen extends StatefulWidget {
  const FbHomeScreen({super.key});

  @override
  State<FbHomeScreen> createState() => _FbHomeScreenState();
}

class _FbHomeScreenState extends State<FbHomeScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _logout() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // чистимо серверну сесію
      await ApiClient().dio.post('/api/logout');
    } catch (_) {
      // ігноруємо: logout має бути best-effort
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('auth_method');

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _checkSessionOrLogout() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;

      // 1) Перевіряємо чи є FB token у server session
      final dbg1 = await dio.get('/api/debug_session');
      final m1 =
          (dbg1.data is Map) ? Map<String, dynamic>.from(dbg1.data as Map) : {};

      final fbOk = m1['fb_user_token_present'] == true;
      final igOk = m1['ig_settings_present'] == true;

      if (!fbOk) {
        await _logout();
        return;
      }

      // 2) Якщо IG settings ще не збережені — ініціалізуємо їх
      if (!igOk) {
        await dio.get('/api/ig/accounts');

        final dbg2 = await dio.get('/api/debug_session');
        final m2 = (dbg2.data is Map)
            ? Map<String, dynamic>.from(dbg2.data as Map)
            : {};

        final igOk2 = m2['ig_settings_present'] == true;
        if (!igOk2) {
          _error = 'FB OAuth OK, але IG не знайдено/не прив’язано.\n'
              'Перевір: FB Page + прив’язаний IG business/creator + права доступу.\n'
              'Ендпоінт /api/ig/accounts повернув 0 або не зберіг ig_settings в session.';
        }
      }
    } catch (e) {
      _error = e.toString();
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    _checkSessionOrLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facebook flow'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _logout,
            child: const Text('Logout'),
          ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Text(
                _error ??
                    'FB OAuth OK. Далі роби запити в /api/ig/* (accounts/media/comments).',
                textAlign: TextAlign.center,
              ),
      ),
    );
  }
}
