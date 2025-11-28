// lib/screens/participants_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:lottie/lottie.dart';
import '../utils/api_exception.dart';
import '../services/participants_service.dart';
import '../models/participant.dart';
import '../widgets/participant_card.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:giveaway_app/services/api_client.dart';
import 'package:giveaway_app/utils/error_messages.dart';

class ParticipantsScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const ParticipantsScreen({required this.onLocaleChanged, super.key});

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _countCtrl = TextEditingController(text: '1');

  final _participantsService = ParticipantsService();

  bool _loading = false;
  List<Participant> _participants = [];
  bool _showCelebration = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final ctx = context; // зберігаємо ДО асинхронних викликів

    try {
      await ApiClient().dio.post('/api/logout');
    } catch (_) {}
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (_) {}
    try {
      await ApiClient().clearCookies();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  Future<void> _refreshAndChoose() async {
    final ctx = context; // фіксуємо BuildContext
    final loc = AppLocalizations.of(ctx)!;

    final n = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (n < 1) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(loc.error_invalid_winner_count)));
      return;
    }

    setState(() => _loading = true);

    try {
      final unique = (await _participantsService
              .fetchParticipants(_urlCtrl.text.trim(), context: ctx))
          .toSet()
          .toList();

      unique.shuffle(Random());

      if (unique.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text(loc.no_participants)));
        setState(() {
          _participants = [];
          _showCelebration = false;
        });
        return;
      }

      final limit = n.clamp(1, unique.length);
      final winners = unique.take(limit).toList();

      setState(() {
        _participants = winners;
        _showCelebration = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = humanizeApiError(ctx, e);
      if (e.code == 'login_required' || e.code == 'invalid_credentials') {
        Navigator.of(ctx).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text(message)));
      }
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(loc.participants_title),
        centerTitle: true,
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            onSelected: widget.onLocaleChanged,
            itemBuilder: (_) {
              return AppLocalizations.supportedLocales.map((locale) {
                final code = locale.languageCode;
                String label;
                if (code == 'uk') {
                  label = 'Українська';
                } else if (code == 'fr') {
                  label = 'Français';
                } else {
                  label = 'English';
                }
                return PopupMenuItem<Locale>(
                  value: locale,
                  child: Text(label),
                );
              }).toList();
            },
          ),
          IconButton(
            tooltip: 'Вийти',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Фон
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AssetPaths.homeBackground),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _urlCtrl,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color.fromRGBO(255, 255, 255, 0.8),
                          labelText: loc.post_url_label,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _countCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color.fromRGBO(255, 255, 255, 0.8),
                          labelText: loc.winners_count_label,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _refreshAndChoose,
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _participants.isEmpty
                      ? Center(
                          child: Text(
                            loc.no_participants,
                            style: const TextStyle(
                                fontSize: 18, color: Colors.white),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: _participants.length,
                          itemBuilder: (_, i) =>
                              ParticipantCard(_participants[i]),
                        ),
                ),
              ],
            ),
          ),

          if (_loading)
            Positioned.fill(
              child: Container(
                color: const Color.fromARGB(77, 0, 0, 0),
                child: Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Lottie.asset(AssetPaths.loadingLottie, repeat: true),
                  ),
                ),
              ),
            ),

          if (_showCelebration)
            Positioned.fill(
              child: Container(
                color: const Color.fromARGB(77, 0, 0, 0),
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: Lottie.asset(
                      AssetPaths.confetti,
                      repeat: false,
                      onLoaded: (composition) {
                        Future.delayed(composition.duration, () {
                          if (mounted) {
                            setState(() => _showCelebration = false);
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
