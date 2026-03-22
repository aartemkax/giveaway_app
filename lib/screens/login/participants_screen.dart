// Active screen: current session-based participants and draw screen.
// lib/screens/login/participants_screen.dart
//
// ──────────────────────────────────────────────────────────────────────────────
// ParticipantsScreen
// ──────────────────────────────────────────────────────────────────────────────
// Цей екран виконує роль “центру жеребку” для кастомного API.
//
// Ключова логіка:
//   1) Приймає URL поста Instagram.
//   2) Запитує бекенд про список учасників (асинхронна джоба з полінгом).
//   3) Локально застосовує унікальність (user / comment / both).
//   4) Перемішує пул і показує випадкових переможців.
//   5) Має простий лоадер-оверлей і святкову анімацію.
//
// Безпека / UX:
//   • Якщо бек повертає 401 / login_required → перекинемо на /login.
//   • Якщо пул порожній → покажемо повідомлення користувачу.
//   • Якщо користувач ввів невалідну кількість переможців → підкажемо.
//
// Структура файлу:
//   • Імпорти
//   • StatefulWidget + State з контролерами
//   • Основний метод _refreshAndChoose()
//   • Build-методи (_buildHeader, _buildForm, _buildResults) — для читабельності
//   • Приватні хелпери (_applyUniqueness, _validateAndParseWinnersCount, тощо)
//
// Примітка щодо унікальності:
//   На бекенді вже є можливість віддавати id коментарів. Поки що у фронті
//   модель Participant не містить commentId, тому режим UniqueBy.comment і
//   UniqueBy.both працює як “плейсхолдер” (фільтрує тільки за username).
//   Щойно додаси поле commentId у Participant — розкоментуй відповідне місце
//   в _applyUniqueness(), щоб унікальність враховувала і коментар.
// ──────────────────────────────────────────────────────────────────────────────
// Ліцензія: internal use
// ──────────────────────────────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────────────────────────────
// ІМПОРТИ
// ──────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:giveaway_app/l10n/app_localizations.dart';
import 'package:lottie/lottie.dart';
import '../../utils/api_exception.dart';
import '../../services/appapi/app_participants_service.dart';
import '../../models/participant.dart';
import '../../widgets/participant_card.dart';
import 'package:giveaway_app/utils/asset_paths.dart';
import '../../widgets/unique_by_switch.dart';

// ──────────────────────────────────────────────────────────────────────────────
// WIDGET
// ──────────────────────────────────────────────────────────────────────────────

class ParticipantsScreen extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;

  const ParticipantsScreen({
    required this.onLocaleChanged,
    super.key,
  });

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

// ──────────────────────────────────────────────────────────────────────────────
// STATE
// ──────────────────────────────────────────────────────────────────────────────

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  // Контролери інпутів
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _countCtrl = TextEditingController(text: '1');

  // Сервіс взаємодії з бекендом
  final ParticipantsService _participantsService = ParticipantsService();

  // Стан UI
  bool _loading = false;
  bool _showCelebration = false;

  // Поточний список переможців (результат для відмальовки)
  List<Participant> _participants = [];

  // Перемикач унікальності
  UniqueBy _uniqueBy = UniqueBy.user;

  // Додаткові вузли фокусу (для UX на мобільних)
  final FocusNode _urlFocus = FocusNode();
  final FocusNode _countFocus = FocusNode();

  @override
  void dispose() {
    _urlCtrl.dispose();
    _countCtrl.dispose();
    _urlFocus.dispose();
    _countFocus.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ОСНОВНИЙ МЕТОД: оновити список і обрати переможців
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _refreshAndChoose() async {
    final loc = AppLocalizations.of(context)!;

    // Валідація кількості переможців
    final n = _validateAndParseWinnersCount(_countCtrl.text);
    if (n == null || n < 1) {
      _showSnack(loc.error_invalid_winner_count);
      return;
    }

    // Забираємо фокус з полів, щоб приховати клавіатуру
    _urlFocus.unfocus();
    _countFocus.unfocus();

    setState(() => _loading = true);

    try {
      // 1) Тягнемо учасників із бекенда
      final raw = await _participantsService.fetchParticipants(
        _urlCtrl.text.trim(),
        context: context,
      );

      // 2) Локальна унікальність за перемикачем
      final pool = _applyUniqueness(raw, _uniqueBy);

      // 3) Перемішуємо
      pool.shuffle(Random());

      // 4) Валідації по результату
      if (pool.isEmpty) {
        _showSnack(loc.no_participants);
        setState(() {
          _participants = [];
          _showCelebration = false;
        });
        return;
      }

      final take = n.clamp(1, pool.length);
      final winners = pool.take(take).toList();

      if (winners.isEmpty) {
        _showSnack(loc.no_participants);
        setState(() {
          _participants = [];
          _showCelebration = false;
        });
        return;
      }

      // 5) Рендер і конфеті
      setState(() {
        _participants = winners;
        _showCelebration = true;
      });
    } on ApiException catch (e) {
      // Мапінг відомих кодів помилок у локалізовані повідомлення
      final msg = _mapApiErrorToMessage(e, loc);

      // Якщо сесія прострочена — ведемо на /login
      if (e.code == 'login_required' || e.code == 'invalid_credentials') {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        _showSnack(msg);
      }
    } catch (_) {
      _showSnack(loc.error_internal_error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          // Фоновий контент
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
                  _buildHeader(loc),
                  const SizedBox(height: 16),
                  _buildForm(loc),
                  const SizedBox(height: 20),
                  _buildResults(loc),
                ],
              ),
            ),
          ),

          // Лоадер-оверлей
          if (_loading) _buildLoaderOverlay(),

          // Конфеті-оверлей
          if (_showCelebration) _buildConfettiOverlay(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD: HEADER
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Title
          Text(
            loc.participants_title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          // Language switch
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: widget.onLocaleChanged,
            itemBuilder: (_) => AppLocalizations.supportedLocales.map((locale) {
              final label = _localeLabel(locale);
              return PopupMenuItem(value: locale, child: Text(label));
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD: FORM
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildForm(AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Поле URL
          TextField(
            controller: _urlCtrl,
            focusNode: _urlFocus,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color.fromRGBO(255, 255, 255, 0.8),
              labelText: loc.post_url_label,
              border: const OutlineInputBorder(),
              helperText:
                  'https://www.instagram.com/p/... або /reel/...', // невелика підказка
            ),
          ),

          const SizedBox(height: 12),

          // Поле кількості переможців
          TextField(
            controller: _countCtrl,
            focusNode: _countFocus,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color.fromRGBO(255, 255, 255, 0.8),
              labelText: loc.winners_count_label,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _refreshAndChoose(),
          ),

          const SizedBox(height: 12),

          // Перемикач унікальності (user/comment/both)
          Align(
            alignment: Alignment.centerLeft,
            child: UniqueBySwitch(
              value: _uniqueBy,
              onChanged: (v) => setState(() => _uniqueBy = v),
            ),
          ),

          const SizedBox(height: 12),

          // Кнопка запуску жеребку
          ElevatedButton.icon(
            onPressed: _loading ? null : _refreshAndChoose,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(loc.refresh_and_choose),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD: RESULTS GRID
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildResults(AppLocalizations loc) {
    return Expanded(
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _participants.length,
              itemBuilder: (_, i) => ParticipantCard(_participants[i]),
            ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD: LOADER OVERLAY
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLoaderOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color.fromARGB(77, 0, 0, 0),
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
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD: CONFETTI OVERLAY
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildConfettiOverlay() {
    return Positioned.fill(
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
                // Після завершення анімації — прибираємо її
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
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ХЕЛПЕРИ: Валідації, локалізація, SnackBar
  // ──────────────────────────────────────────────────────────────────────────

  int? _validateAndParseWinnersCount(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return null;
    if (parsed < 1) return null;
    return parsed;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _localeLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'uk':
        return 'Українська';
      case 'fr':
        return 'Français';
      default:
        return 'English';
    }
  }

  String _mapApiErrorToMessage(ApiException e, AppLocalizations loc) {
    switch (e.code) {
      case 'invalid_post_url':
        return loc.error_invalid_post_url;
      case 'post_unavailable':
        return loc.error_post_unavailable;
      case 'rate_limited':
        return loc.error_rate_limited;
      case 'proxy_blocked':
        return loc.error_proxy_blocked;
      case 'login_required':
        return loc.error_login_required;
      case 'invalid_credentials':
        return loc.error_invalid_credentials;
      case 'internal_error':
        return loc.error_internal_error;
      case 'error_unknown':
        return loc.error_unknown;
      default:
        return loc.error_generic(e.code);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ХЕЛПЕР: УНІКАЛЬНІСТЬ
  // ──────────────────────────────────────────────────────────────────────────
  //
  // Зверни увагу:
  //  • На даний момент модель Participant не має commentId.
  //  • Коли додаси commentId у Participant (і парсинг у сервісі),
  //    онови ключ для режимів UniqueBy.comment / UniqueBy.both.
  //
  // Приклад майбутнього ключа:
  //    final key = '${p.username.trim().toLowerCase()}#${p.commentId}';
  //
  // Тимчасово режими comment/both поводяться як по username.

  List<Participant> _applyUniqueness(List<Participant> items, UniqueBy mode) {
    switch (mode) {
      case UniqueBy.user:
        // Де-дубляція лише за username (case-insensitive)
        final seen = <String>{};
        return items.where((p) {
          final u = p.username.trim().toLowerCase();
          if (seen.contains(u)) return false;
          seen.add(u);
          return true;
        }).toList();

      case UniqueBy.comment:
        // Коли з’явиться commentId — фільтруй по ньому:
        // final seen = <String>{};
        // return items.where((p) {
        //   final key = (p.commentId ?? '').trim();
        //   if (key.isEmpty) return true; // якщо бек не дав id — не чіпаємо
        //   if (seen.contains(key)) return false;
        //   seen.add(key);
        //   return true;
        // }).toList();
        //
        // Поки що повертаємо як є.
        return items;

      case UniqueBy.both:
        // Майбутній ключ: username + commentId
        // final seen = <String>{};
        // return items.where((p) {
        //   final key =
        //       '${p.username.trim().toLowerCase()}#${(p.commentId ?? '').trim()}';
        //   if (seen.contains(key)) return false;
        //   seen.add(key);
        //   return true;
        // }).toList();
        //
        // Поки що — лише за username, як і в UniqueBy.user:
        final seen = <String>{};
        return items.where((p) {
          final key = p.username.trim().toLowerCase();
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        }).toList();
    }
  }
}
