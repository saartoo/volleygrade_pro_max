import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:vibration/vibration.dart';
import '../domain/models.dart';
import '../core/theme.dart';
import 'providers.dart';
import 'dart:math' as math;

class PlayerCell extends ConsumerWidget {
  final Player player;
  final VoidCallback onTap;

  const PlayerCell({Key? key, required this.player, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(playerRatingProvider(player));
    final stats = ref.watch(playerStatsProvider(player.id));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${player.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(player.role.name, style: TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(player.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: rating >= 6.0 ? AppTheme.neonGreen : AppTheme.neonRed,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MiniBadge(icon: Icons.flash_on, count: stats.aces, color: Colors.yellow),
                _MiniBadge(icon: Icons.sports_volleyball, count: stats.attackPoints, color: AppTheme.neonGreen),
                _MiniBadge(icon: Icons.back_hand, count: stats.blocks, color: Colors.blueAccent),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _MiniBadge({required this.icon, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text('$count', style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class ActionOverlay extends ConsumerWidget {
  final Player player;
  final VoidCallback onClose;

  const ActionOverlay({Key? key, required this.player, required this.onClose}) : super(key: key);

  void _recordAction(WidgetRef ref, Fundamental fundamental, Outcome outcome) async {
    final action = Action(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      playerId: player.id,
      fundamental: fundamental,
      outcome: outcome,
      timestamp: DateTime.now(),
    );
    ref.read(actionsProvider.notifier).addAction(action);
    
    // Haptic feedback
    if (await Vibration.hasVibrator() ?? false) {
      if (outcome.name.toLowerCase().contains('error') || outcome.name.toLowerCase().contains('blocked')) {
        Vibration.vibrate(pattern: [0, 100, 50, 100]); // Double pattern for error
      } else {
        Vibration.vibrate(duration: 50); // Short for positive/neutral
      }
    }
    onClose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black87,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Action for ${player.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Simulating 2-tap layout: first tap fundamental, then outcome.
              // For simplicity in MVP overlay, we show outcomes grouped by fundamental.
              _buildFundamentalRow('Attack', Fundamental.attack, [
                _OutcomeBtn(Outcome.attackPoint, 'Point', AppTheme.neonGreen, ref),
                _OutcomeBtn(Outcome.attackError, 'Error', AppTheme.neonRed, ref),
                _OutcomeBtn(Outcome.attackBlocked, 'Blocked', Colors.orange, ref),
              ]),
              _buildFundamentalRow('Reception', Fundamental.reception, [
                _OutcomeBtn(Outcome.receptionPerfect, 'Perfect', AppTheme.neonGreen, ref),
                _OutcomeBtn(Outcome.receptionPositive, 'Positive', Colors.green, ref),
                _OutcomeBtn(Outcome.receptionError, 'Error', AppTheme.neonRed, ref),
              ]),
              _buildFundamentalRow('Service', Fundamental.service, [
                _OutcomeBtn(Outcome.serviceAce, 'Ace', AppTheme.neonGreen, ref),
                _OutcomeBtn(Outcome.serviceGood, 'Good', Colors.green, ref),
                _OutcomeBtn(Outcome.serviceError, 'Error', AppTheme.neonRed, ref),
              ]),
              _buildFundamentalRow('Block', Fundamental.block, [
                _OutcomeBtn(Outcome.blockPoint, 'Point', AppTheme.neonGreen, ref),
                _OutcomeBtn(Outcome.blockTouch, 'Touch', Colors.green, ref),
                _OutcomeBtn(Outcome.blockError, 'Error', AppTheme.neonRed, ref),
              ]),
              _buildFundamentalRow('Defense', Fundamental.defense, [
                _OutcomeBtn(Outcome.defensePoint, 'Point', AppTheme.neonGreen, ref),
                _OutcomeBtn(Outcome.defenseError, 'Error', AppTheme.neonRed, ref),
              ]),
              const SizedBox(height: 20),
              TextButton(onPressed: onClose, child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFundamentalRow(String title, Fundamental fund, List<Widget> outcomes) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: outcomes,
            ),
          )
        ],
      ),
    );
  }

  Widget _OutcomeBtn(Outcome outcome, String label, Color color, WidgetRef ref) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
      ),
      onPressed: () => _recordAction(ref, _getFundForOutcome(outcome), outcome),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Fundamental _getFundForOutcome(Outcome o) {
    if (o.name.startsWith('attack')) return Fundamental.attack;
    if (o.name.startsWith('reception')) return Fundamental.reception;
    if (o.name.startsWith('service')) return Fundamental.service;
    if (o.name.startsWith('block')) return Fundamental.block;
    return Fundamental.defense;
  }
}

class PlayerCardExport extends ConsumerWidget {
  final Player player;
  const PlayerCardExport({Key? key, required this.player}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(playerRatingProvider(player));
    final stats = ref.watch(playerStatsProvider(player.id));

    return Container(
      width: 1080 / 3, // Scaled down for preview, 9:16 ratio approx
      height: 1920 / 3,
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.neonGreen, width: 2),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${player.name} #${player.number}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('ROLE: ${player.role.name}', style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
          const SizedBox(height: 40),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: rating >= 6.0 ? AppTheme.neonGreen : AppTheme.neonRed,
            ),
          ),
          const Text('RATING', style: TextStyle(letterSpacing: 2, color: Colors.white54)),
          const SizedBox(height: 40),
          _StatRow('ATTACK EFF', '${stats.attackEfficiency.toStringAsFixed(0)}%'),
          const SizedBox(height: 16),
          _StatRow('ACES', '${stats.aces}'),
          const SizedBox(height: 16),
          _StatRow('BLOCKS', '${stats.blocks}'),
        ],
      ),
    );
  }

  Widget _StatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.white70)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
