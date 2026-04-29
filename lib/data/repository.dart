import '../domain/models.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class IBallRepository {
  Future<void> init();
  Future<List<Player>> getPlayers();
  Future<void> savePlayer(Player player);
  Future<void> saveActions(List<Action> actions);
  Future<List<Action>> getActionsForMatch(String matchId);
}

class LocalHiveRepository implements IBallRepository {
  static const String _playersBox = 'players';
  static const String _actionsBox = 'actions';

  @override
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PlayerAdapter());
    Hive.registerAdapter(ActionAdapter());
    Hive.registerAdapter(PlayerRoleAdapter());
    Hive.registerAdapter(FundamentalAdapter());
    Hive.registerAdapter(OutcomeAdapter());

    await Hive.openBox<Player>(_playersBox);
    await Hive.openBox<Action>(_actionsBox);
    
    // Seed initial data if empty
    var box = Hive.box<Player>(_playersBox);
    if (box.isEmpty) {
      await savePlayer(Player(id: '1', name: 'Giannelli', number: 6, role: PlayerRole.P));
      await savePlayer(Player(id: '2', name: 'Michieletto', number: 5, role: PlayerRole.S));
      await savePlayer(Player(id: '3', name: 'Lavia', number: 15, role: PlayerRole.S));
      await savePlayer(Player(id: '4', name: 'Galassi', number: 14, role: PlayerRole.C));
      await savePlayer(Player(id: '5', name: 'Romanò', number: 16, role: PlayerRole.O));
      await savePlayer(Player(id: '6', name: 'Balaso', number: 7, role: PlayerRole.L));
    }
  }

  @override
  Future<List<Player>> getPlayers() async {
    final box = Hive.box<Player>(_playersBox);
    return box.values.toList();
  }

  @override
  Future<void> savePlayer(Player player) async {
    final box = Hive.box<Player>(_playersBox);
    await box.put(player.id, player);
  }

  @override
  Future<void> saveActions(List<Action> actions) async {
    final box = Hive.box<Action>(_actionsBox);
    await box.clear();
    for (var action in actions) {
      await box.put(action.id, action);
    }
  }

  @override
  Future<List<Action>> getActionsForMatch(String matchId) async {
    final box = Hive.box<Action>(_actionsBox);
    return box.values.toList();
  }
}
