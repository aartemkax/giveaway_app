// lib/screens/home_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import '../models/participant.dart';
import '../utils/api_exception.dart';
import '../widgets/participant_card.dart';
import '../services/appapi/app_participants_service.dart';
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

  final _participantsService = ParticipantsService();

  List<Participant> _winners = [];
  bool _loading = false;

  Future<void> _refreshAndChoose() async {
    // Фіксуємо контекст і локалізації на старті
    final ctx = context;
    final loc = AppLocalizations.of(ctx)!;

    setState(() => _loading = true);

    // 1) Валідація кількості переможців
    final n = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (n < 1) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(loc.error_invalid_winner_count)),
      );
      setState(() => _loading = false);
      return;
    }

    try {
      // 2) Тягаємо учасників з бекенду
      final unique = (await _participantsService.fetchParticipants(
        _urlCtrl.text.trim(),
        context: ctx, // використовуємо збережений ctx
      ))
          .toSet()
          .toList();

      unique.shuffle(Random());

      if (!mounted) return;
      setState(() {
        final take = n.clamp(1, unique.length);
        _winners = unique.take(take).toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;

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
          if (e.detail == 'session_expired') {
            message = loc.error_session_expired;
            Future.microtask(
                () => Navigator.of(ctx).pushReplacementNamed('/login'));
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

      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(loc.error_internal_error)),
      );
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
