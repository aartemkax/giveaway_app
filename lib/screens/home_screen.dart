// lib/screens/home_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/participant.dart';
import '../services/participants_service.dart';
import '../widgets/participant_card.dart';

class HomeScreen extends StatefulWidget {
  // ✏️ Використовуємо super.key замість {Key? key}: super(key: key)
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlCtrl = TextEditingController(
    text: 'https://www.instagram.com/p/DJC7uo4APmr/',
  );
  final _countCtrl = TextEditingController(text: '1');

  // Ми використовуємо обидва поля — participants для зберігання всіх учасників,
  // winners  — вибраних. Тож ворнінг про unused_field зникне.
  List<Participant> _winners = [];

  bool _loading = false;

  Future<void> _refreshAndChoose() async {
    setState(() => _loading = true);
    try {
      final unique =
          (await fetchParticipants(_urlCtrl.text.trim())).toSet().toList();

      final rnd = Random();
      final n = int.tryParse(_countCtrl.text) ?? 1;
      unique.shuffle(rnd);

      if (!mounted) return;
      setState(() {
        _winners = unique.take(n.clamp(1, unique.length)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎉 Instagram Giveaway')),
      body: Center(
        child:
            _loading
                ? const CircularProgressIndicator()
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Посилання на пост',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _countCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Кількість переможців',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _refreshAndChoose,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Оновити і обрати'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ..._winners.map((w) => ParticipantCard(w)),
                    ],
                  ),
                ),
      ),
    );
  }
}
