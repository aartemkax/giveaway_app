// lib/screens/participants_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:lottie/lottie.dart';
import '../utils/api_exception.dart';
import '../services/participants_service.dart';
import '../models/participant.dart';
import '../widgets/participant_card.dart';
import 'package:giveaway_app/utils/asset_paths.dart';

class ParticipantsScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const ParticipantsScreen({
    required this.onLocaleChanged,
    super.key,
  });

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _countCtrl = TextEditingController(text: '1');

  bool _loading = false;
  List<Participant> _participants = [];
  bool _showCelebration = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAndChoose() async {
    final loc = AppLocalizations.of(context)!;
    final n = int.tryParse(_countCtrl.text.trim()) ?? 0;
    if (n < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.error_invalid_winner_count)),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) Отримуємо всіх коментаторів, унікалізуємо, перемішуємо
      final unique =
          (await fetchParticipants(_urlCtrl.text.trim())).toSet().toList();
      unique.shuffle(Random());

      // 2) Якщо масив коментаторів порожній — одразу виводимо No participants
      if (unique.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.no_participants)),
        );
        setState(() {
          _participants = [];
          _showCelebration = false;
        });
        return;
      }

      // 3) Беремо перші n (мінімум 1, максимум unique.length)
      final limit = n.clamp(1, unique.length);
      final winners = unique.take(limit).toList();

      // 4) Якщо winners все ж опинився порожнім — ще раз No participants
      if (winners.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.no_participants)),
        );
        setState(() {
          _participants = [];
          _showCelebration = false;
        });
        return;
      }

      // 5) Встановлюємо список переможців та запускаємо конфеті
      setState(() {
        _participants = winners;
        _showCelebration = true;
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
          message = loc.error_login_required;
          break;
        case 'invalid_credentials':
          message = loc.error_invalid_credentials;
          break;
        case 'internal_error':
          message = loc.error_internal_error;
          break;
        case 'error_unknown':
          message = loc.error_unknown;
          break;
        default:
          message = loc.error_generic(e.code);
      }
      if (!mounted) return;
      if (e.code == 'login_required' || e.code == 'invalid_credentials') {
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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
      body: Stack(
        children: [
          // ───────── Основний контент ─────────
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AssetPaths.homeBackground),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // AppBar: кнопка «назад», заголовок, вибір мови
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          loc.participants_title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PopupMenuButton<Locale>(
                          icon: const Icon(Icons.language, color: Colors.white),
                          onSelected: widget.onLocaleChanged,
                          itemBuilder: (_) =>
                              AppLocalizations.supportedLocales.map((locale) {
                            String label;
                            if (locale.languageCode == 'uk') {
                              label = 'Українська';
                            } else if (locale.languageCode == 'fr') {
                              label = 'Français';
                            } else {
                              label = 'English';
                            }
                            return PopupMenuItem(
                              value: locale,
                              child: Text(label),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Поля URL та кількості переможців + кнопка
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

                  // ───────── Рендер результатів ─────────
                  Expanded(
                    child: _participants.isEmpty
                        ? Center(
                            child: Text(
                              loc.no_participants,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
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
                            itemBuilder: (_, i) {
                              // Останній "guard" — якщо i поза межами, повертаємо порожню ячейку
                              if (i < 0 || i >= _participants.length) {
                                return const SizedBox.shrink();
                              }
                              return ParticipantCard(_participants[i]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // ───────── Оверлей-лоадер ─────────
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Color.fromARGB(77, 0, 0, 0),
                child: Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Lottie.asset(
                      AssetPaths.loadingLottie,
                      repeat: true,
                    ),
                  ),
                ),
              ),
            ),

          // ───────── Оверлей-конфеті ─────────
          if (_showCelebration)
            Positioned.fill(
              child: Container(
                color: Color.fromARGB(77, 0, 0, 0),
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: Lottie.asset(
                      AssetPaths.confetti,
                      repeat: false,
                      onLoaded: (composition) {
                        Future.delayed(composition.duration, () {
                          setState(() => _showCelebration = false);
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
