import 'package:hive/hive.hive.dart';

part 'models.g.dart';

enum PlayerRole {
  P, // Palleggiatore
  S, // Schiacciatore
  O, // Opposto
  C, // Centrale
  L, // Libero
}

enum Fundamental { attack, reception, service, block, defense }

enum Outcome {
  // Attack
  attackPoint,
  attackError,
  attackBlocked,
  // Reception
  receptionPerfect,
  receptionPositive,
  receptionError,
  // Service
  serviceAce,
  serviceError,
  serviceGood,
  // Block
  blockPoint,
  blockTouch,
  blockError,
  // Defense
  defensePoint,
  defenseError,
}

@HiveType(typeId: 0)
class Player extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final int number;
  @HiveField(3)
  final PlayerRole role;

  Player({
    required this.id,
    required this.name,
    required this.number,
    required this.role,
  });
}

@HiveType(typeId: 1)
class Action extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String playerId;
  @HiveField(2)
  final Fundamental fundamental;
  @HiveField(3)
  final Outcome outcome;
  @HiveField(4)
  final DateTime timestamp;

  Action({
    required this.id,
    required this.playerId,
    required this.fundamental,
    required this.outcome,
    required this.timestamp,
  });
}
