import 'dart:convert';
import 'dart:io';

void main() {
  final arbPath = 'lib/l10n/app_en.arb';
  final libDir = Directory('lib');

  if (!File(arbPath).existsSync()) {
    stderr.writeln("ARB not found: $arbPath");
    exit(1);
  }

  final arbJson = jsonDecode(File(arbPath).readAsStringSync());
  final keys = arbJson.keys.where((k) => !k.startsWith('@')).toList()..sort();

  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final cache = <String, String>{};
  int uses(String key) {
    final re1 = RegExp(r'\bloc\.' + RegExp.escape(key) + r'\b');
    final re2 = RegExp(
      r'AppLocalizations\.of\([^)]+\)!?\s*\.' + RegExp.escape(key) + r'\b',
      multiLine: true,
    );
    int count = 0;
    for (final f in dartFiles) {
      final txt = cache.putIfAbsent(f.path, () => f.readAsStringSync());
      if (re1.hasMatch(txt) || re2.hasMatch(txt)) count++;
    }
    return count;
  }

  final unused = <String>[];
  for (final k in keys) {
    if (uses(k) == 0) unused.add(k);
  }

  stdout.writeln('=== Unused keys (${unused.length}) ===');
  for (final k in unused) stdout.writeln(' - $k');
}
