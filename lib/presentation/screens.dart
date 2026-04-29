import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/theme.dart';
import 'providers.dart';
import 'widgets.dart';

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({Key? key}) : super(key: key);

  @override
  _RosterScreenState createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  void _showActionOverlay(player) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ActionOverlay(
        player: player,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _exportPlayerCard(player) async {
    // Show a loading or temporary overlay
    final image = await screenshotController.captureFromWidget(
      PlayerCardExport(player: player),
      delay: const Duration(milliseconds: 100),
    );

    // Save to device
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = await File('${directory.path}/${player.name}_card.png').create();
    await imagePath.writeAsBytes(image);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Player card saved to ${imagePath.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsyncValue = ref.watch(playersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Volleygrade Pro', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo Last Action',
            onPressed: () {
              ref.read(actionsProvider.notifier).undoLastAction();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Last action undone'), duration: Duration(seconds: 1)),
              );
            },
          ),
        ],
      ),
      body: playersAsyncValue.when(
        data: (players) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return GestureDetector(
                  onLongPress: () => _exportPlayerCard(player), // Long press to export
                  child: PlayerCell(
                    player: player,
                    onTap: () => _showActionOverlay(player),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
