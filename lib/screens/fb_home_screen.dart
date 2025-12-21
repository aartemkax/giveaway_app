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
      final r = await ApiClient().dio.get('/api/debug_session');
      final m = (r.data is Map) ? Map<String, dynamic>.from(r.data as Map) : {};
      final ok = m['fb_user_token_present'] == true;

      if (!ok) {
        await _logout();
        return;
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
