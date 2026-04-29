// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 0;

  @override
  Player read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Player(
      id: fields[0] as String,
      name: fields[1] as String,
      number: fields[2] as int,
      role: fields[3] as PlayerRole,
    );
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.number)
      ..writeByte(3)
      ..write(obj.role);
  }
}

class ActionAdapter extends TypeAdapter<Action> {
  @override
  final int typeId = 1;

  @override
  Action read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Action(
      id: fields[0] as String,
      playerId: fields[1] as String,
      fundamental: fields[2] as Fundamental,
      outcome: fields[3] as Outcome,
      timestamp: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Action obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.playerId)
      ..writeByte(2)
      ..write(obj.fundamental)
      ..writeByte(3)
      ..write(obj.outcome)
      ..writeByte(4)
      ..write(obj.timestamp);
  }
}

class PlayerRoleAdapter extends TypeAdapter<PlayerRole> {
  @override
  final int typeId = 2;

  @override
  PlayerRole read(BinaryReader reader) {
    return PlayerRole.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, PlayerRole obj) {
    writer.writeByte(obj.index);
  }
}

class FundamentalAdapter extends TypeAdapter<Fundamental> {
  @override
  final int typeId = 3;

  @override
  Fundamental read(BinaryReader reader) {
    return Fundamental.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, Fundamental obj) {
    writer.writeByte(obj.index);
  }
}

class OutcomeAdapter extends TypeAdapter<Outcome> {
  @override
  final int typeId = 4;

  @override
  Outcome read(BinaryReader reader) {
    return Outcome.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, Outcome obj) {
    writer.writeByte(obj.index);
  }
}
