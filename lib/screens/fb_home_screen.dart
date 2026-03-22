// Active screen: Facebook flow landing screen used after successful FB auth.
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
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _checkSessionOrLogout();
  }

  Future<void> _logout() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiClient().dio.post('/api/logout');
    } catch (_) {}

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
      _accounts = [];
    });

    try {
      final dio = ApiClient().dio;

      // 1) Перевіряємо чи є FB token у server session
      final dbg1 = await dio.get('/api/debug_session');
      final m1 =
          (dbg1.data is Map) ? Map<String, dynamic>.from(dbg1.data as Map) : {};
      final fbOk = m1['fb_user_token_present'] == true;

      if (!fbOk) {
        await _logout();
        return;
      }

      // 2) Тягнемо IG accounts через Graph. Успіх = accounts не пустий.
      final acc = await dio.get('/api/ig/accounts');
      final data =
          (acc.data is Map) ? Map<String, dynamic>.from(acc.data as Map) : {};

      final accounts = (data['accounts'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (accounts.isEmpty) {
        _error = 'FB OAuth OK, але /api/ig/accounts повернув пусто.\n'
            'Перевір: FB Page + прив’язаний IG business/creator + права доступу.';
      } else {
        _accounts = accounts;
      }
    } catch (e) {
      _error = e.toString();
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Facebook flow')),
        body: Center(child: Text(_error!, textAlign: TextAlign.center)),
      );
    }

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
      body: ListView.separated(
        itemCount: _accounts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final a = _accounts[i];
          final pageName = (a['page_name'] ?? '').toString();
          final igUsername = (a['ig_username'] ?? '').toString();

          return ListTile(
            title: Text(pageName),
            subtitle: Text(igUsername),
            onTap: () {
              Navigator.pushNamed(
                context,
                '/ig_media',
                arguments: {
                  'ig_user_id': a['ig_user_id'],
                  'page_id': a['page_id'],
                  'ig_username': igUsername,
                  'page_name': pageName,
                },
              );
            },
          );
        },
      ),
    );
  }
}
