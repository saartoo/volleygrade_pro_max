import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core/theme.dart';
import 'data/repository.dart';
import 'presentation/providers.dart';
import 'presentation/screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Keep screen awake during match
  WakelockPlus.enable();

  // Initialize repository (Hive)
  final repository = LocalHiveRepository();
  await repository.init();

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
      ],
      child: const VolleygradeApp(),
    ),
  );
}

class VolleygradeApp extends StatelessWidget {
  const VolleygradeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volleygrade Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const RosterScreen(),
    );
  }
}
