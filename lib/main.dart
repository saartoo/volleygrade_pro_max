import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// --- THEME ---
class AppTheme {
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonRed = Color(0xFFFF073A);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: neonGreen,
      colorScheme: const ColorScheme.dark(
        primary: neonGreen,
        secondary: neonRed,
        surface: surface,
        background: background,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white24, width: 1),
          ),
        ),
      ),
    );
  }
}

// --- DOMAIN MODELS & ENUMS ---
enum PlayerRole { P, S, O, C, L }
enum Fundamental { attack, reception, service, block, defense }
enum Outcome {
  attackPoint, attackError, attackBlocked,
  receptionPerfect, receptionPositive, receptionError,
  serviceAce, serviceError, serviceGood,
  blockPoint, blockTouch, blockError,
  defensePoint, defenseError,
}

class Player extends HiveObject {
  final String id;
  final String name;
  final int number;
  final PlayerRole role;

  Player({required this.id, required this.name, required this.number, required this.role});
}

class Action extends HiveObject {
  final String id;
  final String playerId;
  final Fundamental fundamental;
  final Outcome outcome;
  final DateTime timestamp;

  Action({
    required this.id, required this.playerId, required this.fundamental,
    required this.outcome, required this.timestamp,
  });
}

// --- HIVE ADAPTERS (MANUAL) ---
class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 0;
  @override
  Player read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return Player(id: fields[0] as String, name: fields[1] as String, number: fields[2] as int, role: fields[3] as PlayerRole);
  }
  @override
  void write(BinaryWriter writer, Player obj) {
    writer..writeByte(4)..writeByte(0)..write(obj.id)..writeByte(1)..write(obj.name)..writeByte(2)..write(obj.number)..writeByte(3)..write(obj.role);
  }
}

class ActionAdapter extends TypeAdapter<Action> {
  @override
  final int typeId = 1;
  @override
  Action read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return Action(id: fields[0] as String, playerId: fields[1] as String, fundamental: fields[2] as Fundamental, outcome: fields[3] as Outcome, timestamp: fields[4] as DateTime);
  }
  @override
  void write(BinaryWriter writer, Action obj) {
    writer..writeByte(5)..writeByte(0)..write(obj.id)..writeByte(1)..write(obj.playerId)..writeByte(2)..write(obj.fundamental)..writeByte(3)..write(obj.outcome)..writeByte(4)..write(obj.timestamp);
  }
}

class PlayerRoleAdapter extends TypeAdapter<PlayerRole> {
  @override
  final int typeId = 2;
  @override
  PlayerRole read(BinaryReader reader) => PlayerRole.values[reader.readByte()];
  @override
  void write(BinaryWriter writer, PlayerRole obj) => writer.writeByte(obj.index);
}

class FundamentalAdapter extends TypeAdapter<Fundamental> {
  @override
  final int typeId = 3;
  @override
  Fundamental read(BinaryReader reader) => Fundamental.values[reader.readByte()];
  @override
  void write(BinaryWriter writer, Fundamental obj) => writer.writeByte(obj.index);
}

class OutcomeAdapter extends TypeAdapter<Outcome> {
  @override
  final int typeId = 4;
  @override
  Outcome read(BinaryReader reader) => Outcome.values[reader.readByte()];
  @override
  void write(BinaryWriter writer, Outcome obj) => writer.writeByte(obj.index);
}

// --- RATING ENGINE ---
class RatingEngine {
  static const double baseRating = 6.0;
  static const Map<Outcome, double> _weights = {
    Outcome.attackPoint: 0.4, Outcome.attackError: -0.4, Outcome.attackBlocked: -0.2,
    Outcome.receptionPerfect: 0.2, Outcome.receptionPositive: 0.1, Outcome.receptionError: -0.4,
    Outcome.serviceAce: 0.4, Outcome.serviceError: -0.3, Outcome.serviceGood: 0.1,
    Outcome.blockPoint: 0.5, Outcome.blockTouch: 0.1, Outcome.blockError: -0.3,
    Outcome.defensePoint: 0.2, Outcome.defenseError: -0.2,
  };

  static double calculateRating(Player player, List<Action> actions) {
    double rating = baseRating;
    for (var action in actions) {
      double weight = _weights[action.outcome] ?? 0.0;
      weight *= _getRoleMultiplier(player.role, action.fundamental);
      rating += weight;
    }
    return rating.clamp(1.0, 10.0);
  }

  static double _getRoleMultiplier(PlayerRole role, Fundamental fundamental) {
    switch (role) {
      case PlayerRole.P: if (fundamental == Fundamental.service) return 1.2; break;
      case PlayerRole.S:
      case PlayerRole.O: if (fundamental == Fundamental.attack) return 1.2; break;
      case PlayerRole.C: if (fundamental == Fundamental.block) return 1.2; break;
      case PlayerRole.L: if (fundamental == Fundamental.reception || fundamental == Fundamental.defense) return 1.2; break;
    }
    return 1.0;
  }
}

// --- DATA REPOSITORY ---
abstract class IBallRepository {
  Future<void> init();
  Future<List<Player>> getPlayers();
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
    
    var box = Hive.box<Player>(_playersBox);
    if (box.isEmpty) {
      await box.put('1', Player(id: '1', name: 'Giannelli', number: 6, role: PlayerRole.P));
      await box.put('2', Player(id: '2', name: 'Michieletto', number: 5, role: PlayerRole.S));
      await box.put('3', Player(id: '3', name: 'Lavia', number: 15, role: PlayerRole.S));
      await box.put('4', Player(id: '4', name: 'Galassi', number: 14, role: PlayerRole.C));
      await box.put('5', Player(id: '5', name: 'Romanò', number: 16, role: PlayerRole.O));
      await box.put('6', Player(id: '6', name: 'Balaso', number: 7, role: PlayerRole.L));
    }
  }

  @override
  Future<List<Player>> getPlayers() async {
    final box = Hive.box<Player>(_playersBox);
    return box.values.toList();
  }
}

// --- STATE MANAGEMENT (RIVERPOD) ---
final repositoryProvider = Provider<IBallRepository>((ref) => LocalHiveRepository());

final playersProvider = FutureProvider<List<Player>>((ref) async {
  final repo = ref.read(repositoryProvider);
  return repo.getPlayers();
});

class ActionNotifier extends StateNotifier<List<Action>> {
  ActionNotifier() : super([]);
  void addAction(Action action) => state = [...state, action];
  void undoLastAction() {
    if (state.isNotEmpty) state = state.sublist(0, state.length - 1);
  }
}

final actionsProvider = StateNotifierProvider<ActionNotifier, List<Action>>((ref) => ActionNotifier());

class PlayerStats {
  final int aces, blocks, attackPoints;
  final double attackEfficiency;
  final List<Action> actions;
  PlayerStats({required this.aces, required this.blocks, required this.attackPoints, required this.attackEfficiency, required this.actions});
}

final playerStatsProvider = Provider.family<PlayerStats, String>((ref, playerId) {
  final actions = ref.watch(actionsProvider).where((a) => a.playerId == playerId).toList();
  int aces = 0, blocks = 0, attackPoints = 0, attacksTotal = 0;
  for (var action in actions) {
    if (action.outcome == Outcome.serviceAce) aces++;
    if (action.outcome == Outcome.blockPoint) blocks++;
    if (action.fundamental == Fundamental.attack) {
      attacksTotal++;
      if (action.outcome == Outcome.attackPoint) attackPoints++;
    }
  }
  return PlayerStats(
    aces: aces, blocks: blocks, attackPoints: attackPoints,
    attackEfficiency: attacksTotal > 0 ? (attackPoints / attacksTotal) * 100 : 0.0,
    actions: actions,
  );
});

final playerRatingProvider = Provider.family<double, Player>((ref, player) {
  final stats = ref.watch(playerStatsProvider(player.id));
  return RatingEngine.calculateRating(player, stats.actions);
});

// --- UI WIDGETS ---
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
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${player.number}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(player.role.name, style: const TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(player.name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
            const Spacer(),
            Text(
              rating.toStringAsFixed(1),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: rating >= 6.0 ? AppTheme.neonGreen : AppTheme.neonRed),
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
      playerId: player.id, fundamental: fundamental, outcome: outcome, timestamp: DateTime.now(),
    );
    ref.read(actionsProvider.notifier).addAction(action);
    if (await Vibration.hasVibrator() ?? false) {
      if (outcome.name.toLowerCase().contains('error') || outcome.name.toLowerCase().contains('blocked')) {
        Vibration.vibrate(pattern: [0, 100, 50, 100]);
      } else {
        Vibration.vibrate(duration: 50);
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
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Action for ${player.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
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
          Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: outcomes))
        ],
      ),
    );
  }

  Widget _OutcomeBtn(Outcome outcome, String label, Color color, WidgetRef ref) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2), side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero,
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
      width: 1080 / 3, height: 1920 / 3,
      decoration: BoxDecoration(color: AppTheme.background, border: Border.all(color: AppTheme.neonGreen, width: 2)),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${player.name} #${player.number}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('ROLE: ${player.role.name}', style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
          const SizedBox(height: 40),
          Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: rating >= 6.0 ? AppTheme.neonGreen : AppTheme.neonRed)),
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

class RosterScreen extends ConsumerStatefulWidget {
  const RosterScreen({Key? key}) : super(key: key);
  @override
  _RosterScreenState createState() => _RosterScreenState();
}

class _RosterScreenState extends ConsumerState<RosterScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  void _showActionOverlay(player) {
    showDialog(context: context, barrierDismissible: true, builder: (_) => ActionOverlay(player: player, onClose: () => Navigator.of(context).pop()));
  }

  void _exportPlayerCard(player) async {
    final image = await screenshotController.captureFromWidget(PlayerCardExport(player: player), delay: const Duration(milliseconds: 100));
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = await File('${directory.path}/${player.name}_card.png').create();
    await imagePath.writeAsBytes(image);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Player card saved to ${imagePath.path}')));
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Last action undone'), duration: Duration(seconds: 1)));
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.8),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return GestureDetector(
                  onLongPress: () => _exportPlayerCard(player),
                  child: PlayerCell(player: player, onTap: () => _showActionOverlay(player)),
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

// --- MAIN ENTRANCE ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Wakelock might fail in some test environments, wrap in try/catch to be safe
    WakelockPlus.enable();
  } catch(e) {
    debugPrint("Wakelock could not be enabled: $e");
  }

  final repository = LocalHiveRepository();
  await repository.init();

  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
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
