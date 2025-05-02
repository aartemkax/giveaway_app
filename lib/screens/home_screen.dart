// lib/screens/home_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/participant.dart';
import '../services/participants_service.dart';
import '../widgets/participant_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
  //                    ^^^^^^^^^^^^^^^^^^^^^^
  // Тепер return-type – публічний State<HomeScreen>, а не приватний _HomeScreenState
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlCtrl = TextEditingController(
    text: 'https://www.instagram.com/p/DJC7uo4APmr/',
  );
  final _countCtrl = TextEditingController(text: '1');
  List<Participant> _participants = [];
  List<Participant> _winners = [];
  bool _loading = false;

  Future<void> _loadParticipants() async {
    // починаємо завантаження
    if (mounted) setState(() => _loading = true);

    try {
      final fetched = await fetchParticipants(_urlCtrl.text.trim());
      // якщо під час fetch віджет вже видалили з дерева — кидаємося з цього методу
      if (!mounted) return;

      setState(() {
        // зберігаємо результат
        _participants = fetched.toSet().toList();
        _winners = [];
      });
    } catch (e) {
      // якщо still mounted — показуємо помилку
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      // вимикаємо індикатор
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickWinners() {
    final rnd = Random();
    final n = int.tryParse(_countCtrl.text) ?? 1;
    final pool = List.of(_participants)..shuffle(rnd);
    _winners = pool.take(n.clamp(1, pool.length)).toList();
    setState(() {});
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎉 Instagram Giveaway')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
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
                    ElevatedButton(
                      onPressed:
                          _participants.isEmpty
                              ? _loadParticipants
                              : _pickWinners,
                      child: Text(
                        _participants.isEmpty
                            ? '🔄 Завантажити учасників'
                            : '🎯 Обрати переможців',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._winners.map((p) => ParticipantCard(p)),
                  ],
                ),
              ),
    );
  }
}
