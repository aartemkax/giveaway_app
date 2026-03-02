//lib/screens/ig_comments_screen.dart
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

  final TextEditingController _linkCtrl = TextEditingController();
  bool _resolving = false;
  String? _resolveError;

  List<Map<String, dynamic>> _items = [];

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

      if (!mounted) return;
      setState(() {
        _items = data;
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

  String _normalizePermalink(String s) {
    var x = s.trim();
    if (x.startsWith('/')) x = 'https:$x';
    if (!x.startsWith('http')) x = 'https://$x';
    if (!x.endsWith('/')) x = '$x/';
    return x;
  }

  Future<void> _findByLink() async {
    final raw = _linkCtrl.text.trim();
    if (raw.isEmpty) return;

    setState(() {
      _resolving = true;
      _resolveError = null;
    });

    try {
      final permalink = _normalizePermalink(raw);

      final item = await GraphService().resolveMedia(
        igUserId: _igUserId,
        pageId: _pageId,
        permalink: permalink,
      );

      final mediaId = (item['id'] ?? '').toString();
      if (mediaId.isEmpty) {
        throw Exception('Resolve returned empty media_id');
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/ig_comments',
        arguments: {'media_id': mediaId, 'page_id': _pageId},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resolveError = 'Resolve error: $e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Widget _resolveCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste Instagram link (permalink)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _linkCtrl,
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
                    icon: const Icon(Icons.search),
                    label: const Text('Find'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _resolving
                      ? null
                      : () {
                          setState(() {
                            _linkCtrl.clear();
                            _resolveError = null;
                          });
                        },
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
            if (_resolveError != null) ...[
              const SizedBox(height: 10),
              Text(
                _resolveError!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : Column(
                  children: [
                    _resolveCard(),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = _items[i];
                          final mediaId = (m['id'] ?? '').toString();
                          final img = (m['media_url'] ?? '').toString();
                          final comments =
                              (m['comments_count'] ?? 0).toString();
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
                            subtitle:
                                Text('comments: $comments • likes: $likes'),
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
                      ),
                    ),
                  ],
                ),
    );
  }
}
