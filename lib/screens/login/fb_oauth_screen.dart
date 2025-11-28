import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:giveaway_app/services/api_client.dart';

class FbOAuthScreen extends StatefulWidget {
  const FbOAuthScreen({super.key});
  @override
  State<FbOAuthScreen> createState() => _FbOAuthScreenState();
}

class _FbOAuthScreenState extends State<FbOAuthScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final dio = ApiClient().dio;
      final r = await dio.get('/api/ig/login_url');
      if (r.statusCode == 200 &&
          r.data is Map &&
          r.data['login_url'] is String) {
        final url = Uri.parse(r.data['login_url'] as String);
        final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!ok) {
          setState(() {
            _error = 'Не вдалося відкрити браузер для авторизації.';
            _loading = false;
          });
          return;
        }
      } else {
        setState(() => _error = 'Сервер не повернув login_url.');
      }
    } catch (e) {
      setState(() => _error = 'Помилка: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facebook OAuth')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  )
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Після успішного логіну через браузер поверніться в додаток.\n'
                      'Сесію збережено у кукі, можна переходити до вибору переможця.',
                      textAlign: TextAlign.center,
                    ),
                  ),
      ),
    );
  }
}
