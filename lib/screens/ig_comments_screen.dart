//lib/screens/ig_comments_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giveaway_app/services/graph_service.dart';

class IgCommentsScreen extends StatefulWidget {
  const IgCommentsScreen({super.key});

  @override
  State<IgCommentsScreen> createState() => _IgCommentsScreenState();
}

class _IgCommentsScreenState extends State<IgCommentsScreen> {
  bool _loading = true;
  bool _drawing = false;
  String? _error;

  bool _inited = false;

  String _mediaId = '';
  String _pageId = '';
  String _igUsername = '';
  List<Map<String, dynamic>> _comments = [];

  // ---------- helpers for copy ----------
  String _csvEscape(String v) {
    final s = v.replaceAll('"', '""');
    final needQuotes = s.contains(',') ||
        s.contains('\n') ||
        s.contains('\r') ||
        s.contains('"');
    return needQuotes ? '"$s"' : s;
  }

  String _winnersPlain(List<Map<String, dynamic>> winners) {
    return winners.map((w) {
      final u = (w['username'] ?? '').toString();
      final id = (w['id'] ?? '').toString();
      return '@$u (comment_id: $id)';
    }).join('\n');
  }

  String _winnersCsv(List<Map<String, dynamic>> winners) {
    final b = StringBuffer();
    b.writeln('username,comment_id');
    for (final w in winners) {
      final u = (w['username'] ?? '').toString();
      final id = (w['id'] ?? '').toString();
      b.writeln('${_csvEscape(u)},${_csvEscape(id)}');
    }
    return b.toString();
  }

  Future<void> _copyText(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  // ---------- lifecycle ----------
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    _igUsername = (args['ig_username'] ?? '').toString();
    _mediaId = (args['media_id'] ?? '').toString();
    _pageId = (args['page_id'] ?? '').toString();
    _load();
  }

  Future<void> _load() async {
    if (_mediaId.isEmpty || _pageId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing media_id або page_id';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _comments = [];
    });

    try {
      final r = await GraphService().comments(_mediaId, _pageId);
      final items = (r['participants'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _comments = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---------- draw UI ----------
  Future<void> _openDrawSheet() async {
    if (_drawing) return;

    final winnersCtrl = TextEditingController(text: '1');
    final hashtagsCtrl = TextEditingController();
    final denylistCtrl = TextEditingController();
    final minMentionsCtrl = TextEditingController(text: '0');

    String uniqueBy = 'user'; // user|comment|both
    bool uniqueWinners = true; // важливо для режиму "comment"
    bool excludeMe = false;

    final res = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Draw settings',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: winnersCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Winners count',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: uniqueBy,
                    decoration: const InputDecoration(
                      labelText: 'Tickets mode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'user',
                        child: Text('User (1 ticket per user)'),
                      ),
                      DropdownMenuItem(
                        value: 'comment',
                        child: Text('Comment (each comment is a ticket)'),
                      ),
                      DropdownMenuItem(
                        value: 'both',
                        child: Text('Both (unique by user+comment)'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => uniqueBy = v ?? 'user'),
                  ),
                  const SizedBox(height: 12),

                  // Режим 2: більше коментів = більше шансів, але 1 перемога на юзера
                  if (uniqueBy == 'comment') ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Unique winners (max 1 win per user)'),
                      value: uniqueWinners,
                      onChanged: (v) => setLocal(() => uniqueWinners = v),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (_igUsername.isNotEmpty) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Exclude me (@$_igUsername)'),
                      value: excludeMe,
                      onChanged: (v) => setLocal(() => excludeMe = v),
                    ),
                    const SizedBox(height: 8),
                  ],

                  TextField(
                    controller: minMentionsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min @mentions (0..)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: hashtagsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Required hashtags (comma separated)',
                      hintText: 'e.g. giveaway, #giveaway2026',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: denylistCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Denylist usernames (comma separated)',
                      hintText: 'e.g. spam1, spam2',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final winners =
                            int.tryParse(winnersCtrl.text.trim()) ?? 0;
                        if (winners < 1) {
                          Navigator.pop(
                              ctx, {'_error': 'Winners count must be >= 1'});
                          return;
                        }

                        final minMentions =
                            int.tryParse(minMentionsCtrl.text.trim()) ?? 0;

                        final requiredHashtags = hashtagsCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .map((s) {
                          final low = s.toLowerCase();
                          return low.startsWith('#') ? low : '#$low';
                        }).toList();

                        final denylist = denylistCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        if (excludeMe && _igUsername.isNotEmpty) {
                          denylist.add(_igUsername);
                        }

                        Navigator.pop(ctx, {
                          'winners': winners,
                          'unique_winners': uniqueWinners,
                          'filter': {
                            'unique_by': uniqueBy,
                            'min_mentions': minMentions,
                            'required_hashtags': requiredHashtags,
                            'denylist': denylist,
                          }
                        });
                      },
                      child: const Text('Run draw'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;
    if (res == null) return;

    if (res['_error'] != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(res['_error'].toString())));
      return;
    }

    final winnersCount = res['winners'] as int;
    final filter = (res['filter'] as Map?)?.cast<String, dynamic>();
    final uniqueWinnersRes = (res['unique_winners'] as bool?) ?? true;

    await _runDraw(
      winnersCount: winnersCount,
      filter: filter,
      uniqueWinners: uniqueWinnersRes,
    );
  }

  Future<void> _runDraw({
    required int winnersCount,
    Map<String, dynamic>? filter,
    required bool uniqueWinners,
  }) async {
    setState(() => _drawing = true);

    try {
      final r = await GraphService().runDraw(
        mediaId: _mediaId,
        pageId: _pageId,
        winners: winnersCount,
        filter: filter,
        uniqueWinners: uniqueWinners,
      );

      final audit =
          (r['audit'] is Map) ? Map<String, dynamic>.from(r['audit']) : {};
      final winners = (r['winners'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;

      final seed = (audit['seed'] ?? '').toString();
      final poolHash = (audit['pool_hash'] ?? '').toString();
      final plain = _winnersPlain(winners);
      final csv = _winnersCsv(winners);
      final auditJson = const JsonEncoder.withIndent('  ').convert(audit);

      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Winners'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fetched: ${audit['fetched_count'] ?? '-'}'),
                  Text('Filtered: ${audit['filtered_count'] ?? '-'}'),
                  Text('Unique by: ${audit['unique_by'] ?? '-'}'),
                  if (seed.isNotEmpty) Text('Seed: $seed'),
                  if (poolHash.isNotEmpty) Text('Pool hash: $poolHash'),
                  const SizedBox(height: 12),
                  ...winners.map((w) {
                    final u = (w['username'] ?? '').toString();
                    final id = (w['id'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('@$u  (comment_id: $id)'),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _copyText('Winners', plain),
                child: const Text('Copy winners'),
              ),
              TextButton(
                onPressed: () => _copyText('Winners CSV', csv),
                child: const Text('Copy CSV'),
              ),
              TextButton(
                onPressed: () => _copyText('Audit JSON', auditJson),
                child: const Text('Copy audit'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Draw error: $e')));
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments • $_mediaId'),
        actions: [
          IconButton(
            onPressed: _drawing ? null : _openDrawSheet,
            icon: const Icon(Icons.casino),
            tooltip: 'Draw',
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : ListView.separated(
                  itemCount: _comments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = _comments[i];
                    final u = (c['username'] ?? '').toString();
                    final t = (c['text'] ?? '').toString();
                    final ts = (c['timestamp'] ?? '').toString();

                    return ListTile(
                      title: Text(u),
                      subtitle: Text(t),
                      trailing:
                          ts.isNotEmpty ? Text(ts.split('T').first) : null,
                    );
                  },
                ),
    );
  }
}
