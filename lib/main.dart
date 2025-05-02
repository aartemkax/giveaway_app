import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  // Щоб Flutter ініціалізував потрібні binding перед асинхронною роботою
  WidgetsFlutterBinding.ensureInitialized();
  // Завантажуємо файл .env (із кореня проекту)
  await dotenv.load(fileName: ".env");
  runApp(const GiveawayApp());
}

class GiveawayApp extends StatelessWidget {
  const GiveawayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instagram Giveaway',
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
