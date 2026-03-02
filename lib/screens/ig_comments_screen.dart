// lib/screens/ig_media_screen.dart
import 'package:flutter/material.dart';
import 'package:giveaway_app/services/graph_service.dart';

class IgCommentsScreen extends StatefulWidget {
  const IgCommentsScreen({super.key});

  @override
  State<IgCommentsScreen> createState() => _IgCommentsScreenState();
}

class _IgCommentsScreenState extends State<IgCommentsScreen> {
  bool _loading = true;
  String? _error;

  bool _inited = false;

  String _mediaId = '';
  String _pageId = '';
  List<Map<String, dynamic>> _comments = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
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

      setState(() {
        _comments = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments • $_mediaId'),
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
