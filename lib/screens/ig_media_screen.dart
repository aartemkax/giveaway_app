// lib/screens/ig_media_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:giveaway_app/services/graph_service.dart';

class IgMediaScreen extends StatefulWidget {
  const IgMediaScreen({super.key});

  @override
  State<IgMediaScreen> createState() => _IgMediaScreenState();
}

class _IgMediaScreenState extends State<IgMediaScreen> {
  bool _loading = true;
  String? _error;

  bool _inited = false;

  String _igUserId = '';
  String _pageId = '';
  String _title = 'IG media';

  List<Map<String, dynamic>> _items = [];

  final _linkCtrl = TextEditingController();
  bool _resolving = false;
  String? _resolveError;

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
    _igUserId = (args['ig_user_id'] ?? '').toString();
    _pageId = (args['page_id'] ?? '').toString();

    final pageName = (args['page_name'] ?? '').toString();
    final igUsername = (args['ig_username'] ?? '').toString();
    _title = pageName.isNotEmpty ? '$pageName • $igUsername' : 'IG media';

    _load();
  }

  String _normalizePermalink(String s) {
    s = s.trim();
    if (s.isEmpty) return s;
    final uri = Uri.tryParse(s);
    if (uri != null) {
      final clean = uri.replace(query: '', fragment: '');
      s = clean.toString();
    }
    if (!s.endsWith('/')) s += '/';
    return s;
  }

  Future<void> _findByLink() async {
    final raw = _linkCtrl.text;
    final link = _normalizePermalink(raw);

    if (link.isEmpty) {
      setState(() => _resolveError = 'Встав посилання на пост.');
      return;
    }
    if (_igUserId.isEmpty || _pageId.isEmpty) {
      setState(() => _resolveError = 'Missing ig_user_id або page_id');
      return;
    }

    setState(() {
      _resolving = true;
      _resolveError = null;
    });

    try {
      final res = await GraphService().resolveMedia(
        igUserId: _igUserId,
        pageId: _pageId,
        permalink: link,
      );

      final mediaId = (res['media_id'] ?? res['id'] ?? '').toString();
      if (mediaId.isEmpty) {
        setState(() => _resolveError = 'Resolve повернув пустий media_id');
        return;
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/ig_comments',
        arguments: {
          'media_id': mediaId,
          'page_id': _pageId,
        },
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 404) {
        setState(
            () => _resolveError = 'Пост не знайдено. Обери зі списку нижче.');
      } else {
        setState(() =>
            _resolveError = 'Resolve error: ${e.message ?? code.toString()}');
      }
    } catch (e) {
      setState(() => _resolveError = e.toString());
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _load() async {
    if (_igUserId.isEmpty || _pageId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing ig_user_id або page_id';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });

    try {
      final r = await GraphService().media(_igUserId, _pageId);
      final data = (r['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildPasteLinkCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Paste Instagram link (permalink)'),
              const SizedBox(height: 8),
              TextField(
                controller: _linkCtrl,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _resolving ? null : _findByLink(),
                decoration: const InputDecoration(
                  hintText: 'https://www.instagram.com/p/XXXX/',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _resolving ? null : _findByLink,
                      icon: _resolving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(_resolving ? 'Finding...' : 'Find'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _resolving
                        ? null
                        : () {
                            _linkCtrl.clear();
                            setState(() => _resolveError = null);
                          },
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear',
                  )
                ],
              ),
              if (_resolveError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _resolveError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      return const Center(child: Text('Немає постів.'));
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = _items[i];
        final mediaId = (m['id'] ?? '').toString();
        final img = (m['media_url'] ?? '').toString();
        final comments = (m['comments_count'] ?? 0).toString();
        final likes = (m['like_count'] ?? 0).toString();

        return ListTile(
          leading: img.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    img,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                )
              : const SizedBox(width: 52, height: 52),
          title: Text('media_id: $mediaId'),
          subtitle: Text('comments: $comments • likes: $likes'),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/ig_comments',
              arguments: {
                'media_id': mediaId,
                'page_id': _pageId,
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : Column(
                  children: [
                    _buildPasteLinkCard(),
                    const Divider(height: 1),
                    Expanded(child: _buildList()),
                  ],
                ),
    );
  }
}
