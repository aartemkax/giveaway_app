import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'api/participants_service.dart'; // API-сервіс

void main() {
  runApp(const GiveawayApp());
}

class GiveawayApp extends StatelessWidget {
  const GiveawayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instagram Giveaway',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      ),
      home: const GiveawayHomePage(),
    );
  }
}

class GiveawayHomePage extends StatefulWidget {
  const GiveawayHomePage({super.key});

  @override
  State<GiveawayHomePage> createState() => _GiveawayHomePageState();
}

class _GiveawayHomePageState extends State<GiveawayHomePage> {
  List<Participant> participants = [];
  List<Participant> winners = [];
  bool isLoading = false;

  final TextEditingController _urlController = TextEditingController(
    text: 'https://www.instagram.com/p/DJC7uo4APmr/',
  );
  final TextEditingController _countController = TextEditingController(
    text: '1',
  );

  Future<void> _fetchFromApi() async {
    setState(() => isLoading = true);
    try {
      final result = await fetchParticipants(_urlController.text.trim());
      // Дедуплікація на рівні даних
      final unique = result.toSet().toList();
      if (!mounted) return;
      setState(() {
        participants = unique;
        winners = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Помилка: \$e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _selectWinners() {
    if (participants.isEmpty) return;
    final random = Random();
    final count = int.tryParse(_countController.text) ?? 1;
    final shuffled = List.of(participants)..shuffle(random);
    final selected =
        shuffled.take(count.clamp(1, participants.length)).toList();
    setState(() => winners = selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎉 Instagram Giveaway')),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Посилання на пост',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Кількість переможців',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (winners.isNotEmpty)
                      ...winners.map((winner) {
                        final avatarUrl =
                            winner.profilePicUrl.startsWith('http')
                                ? winner.profilePicUrl
                                : 'http://127.0.0.1:5000${winner.profilePicUrl}';
                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: NetworkImage(avatarUrl),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              winner.username,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      }),
                    ElevatedButton(
                      onPressed:
                          participants.isEmpty ? _fetchFromApi : _selectWinners,
                      child: Text(
                        participants.isEmpty
                            ? '🔄 Завантажити учасників'
                            : '🎯 Обрати переможців',
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
