import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models.dart';
import '../domain/rating_engine.dart';
import '../data/repository.dart';

final repositoryProvider = Provider<IBallRepository>((ref) {
  return LocalHiveRepository();
});

final playersProvider = FutureProvider<List<Player>>((ref) async {
  final repo = ref.read(repositoryProvider);
  return repo.getPlayers();
});

class ActionNotifier extends StateNotifier<List<Action>> {
  ActionNotifier() : super([]);

  void addAction(Action action) {
    state = [...state, action];
  }

  void undoLastAction() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }
}

final actionsProvider = StateNotifierProvider<ActionNotifier, List<Action>>((ref) {
  return ActionNotifier();
});

final playerStatsProvider = Provider.family<PlayerStats, String>((ref, playerId) {
  final actions = ref.watch(actionsProvider).where((a) => a.playerId == playerId).toList();
  
  int aces = 0;
  int blocks = 0;
  int attackPoints = 0;
  int attacksTotal = 0;

  for (var action in actions) {
    if (action.outcome == Outcome.serviceAce) aces++;
    if (action.outcome == Outcome.blockPoint) blocks++;
    if (action.fundamental == Fundamental.attack) {
      attacksTotal++;
      if (action.outcome == Outcome.attackPoint) attackPoints++;
    }
  }

  double attackEfficiency = attacksTotal > 0 ? (attackPoints / attacksTotal) * 100 : 0.0;

  return PlayerStats(
    aces: aces,
    blocks: blocks,
    attackPoints: attackPoints,
    attackEfficiency: attackEfficiency,
    actions: actions,
  );
});

class PlayerStats {
  final int aces;
  final int blocks;
  final int attackPoints;
  final double attackEfficiency;
  final List<Action> actions;

  PlayerStats({
    required this.aces,
    required this.blocks,
    required this.attackPoints,
    required this.attackEfficiency,
    required this.actions,
  });
}

final playerRatingProvider = Provider.family<double, Player>((ref, player) {
  final stats = ref.watch(playerStatsProvider(player.id));
  return RatingEngine.calculateRating(player, stats.actions);
});
