// lib/screens/home_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import '../models/participant.dart';
import '../utils/api_exception.dart';
import '../widgets/participant_card.dart';

// Потрібний імпорт для ParticipantsService
import '../services/participants_service.dart';
// Імпорт шляхів до ассетів
import 'package:giveaway_app/utils/asset_paths.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlCtrl = TextEditingController(
    text: 'https://www.instagram.com/p/DJC7uo4APmr/',
  );
  final _countCtrl = TextEditingController(text: '1');

  // Створюємо сервіс
  final _participantsService = ParticipantsService();

  List<Participant> _winners = [];
  bool _loading = false;

  Future<void> _refreshAndChoose() async {
    // Беремо локалізації один раз на початку (уникаємо use_build_context_synchronously)
    final ctx = context;
    final loc = AppLocalizations.of(ctx)!;

    setState(() => _loading = true);

    // 1) Перевіряємо, щоб вводили ≥ 1
    final n = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (n < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.error_invalid_winner_count)),
      );
      setState(() => _loading = false);
      return;
    }

    try {
      // 2) Тягнемо учасників з бекенду
      final unique = (await _participantsService.fetchParticipants(
        _urlCtrl.text.trim(),
        context: context,
      ))
          .toSet()
          .toList();

      final rnd = Random();
      unique.shuffle(rnd);

      if (!mounted) return;
      setState(() {
        final take = n.clamp(1, unique.length);
        _winners = unique.take(take).toList();
      });
    } on ApiException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid_post_url':
          message = loc.error_invalid_post_url;
          break;
        case 'post_unavailable':
          message = loc.error_post_unavailable;
          break;
        case 'rate_limited':
          message = loc.error_rate_limited;
          break;
        case 'proxy_blocked':
          message = loc.error_proxy_blocked;
          break;

        case 'login_required':
          // спеціальна гілка для detail=session_expired
          if (e.detail == 'session_expired') {
            message = loc.error_session_expired;
            if (mounted) {
              // опційно: одразу перекинути на логін
              Future.microtask(
                () => Navigator.of(context).pushReplacementNamed('/login'),
              );
            }
          } else {
            message = loc.error_login_required;
          }
          break;

        case 'invalid_credentials':
          message = loc.error_invalid_credentials;
          break;
        case 'internal_error':
          message = loc.error_internal_error;
          break;

        default:
          message = loc.error_generic(e.code);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.error_internal_error)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.home_title),
        // якщо хочеш напівпрозору шапку на фоні:
        // backgroundColor: Colors.black.withOpacity(0.4),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AssetPaths.homeBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _urlCtrl,
                          decoration: InputDecoration(
                            labelText: loc.post_url_label,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _countCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: loc.winners_count_label,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _refreshAndChoose,
                          icon: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(loc.refresh_and_choose),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        ),
                        const SizedBox(height: 20),
                        for (final w in _winners) ParticipantCard(w),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
