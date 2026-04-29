import 'models.dart';

class RatingEngine {
  static const double baseRating = 6.0;

  static const Map<Outcome, double> _weights = {
    Outcome.attackPoint: 0.4,
    Outcome.attackError: -0.4,
    Outcome.attackBlocked: -0.2,
    Outcome.receptionPerfect: 0.2,
    Outcome.receptionPositive: 0.1,
    Outcome.receptionError: -0.4,
    Outcome.serviceAce: 0.4,
    Outcome.serviceError: -0.3,
    Outcome.serviceGood: 0.1,
    Outcome.blockPoint: 0.5,
    Outcome.blockTouch: 0.1,
    Outcome.blockError: -0.3,
    Outcome.defensePoint: 0.2,
    Outcome.defenseError: -0.2,
  };

  static double calculateRating(Player player, List<Action> actions) {
    double rating = baseRating;

    for (var action in actions) {
      double weight = _weights[action.outcome] ?? 0.0;
      weight *= _getRoleMultiplier(player.role, action.fundamental);
      rating += weight;
    }

    // Clamp between 1.0 and 10.0
    return rating.clamp(1.0, 10.0);
  }

  static double _getRoleMultiplier(PlayerRole role, Fundamental fundamental) {
    switch (role) {
      case PlayerRole.P:
        if (fundamental == Fundamental.service) return 1.2;
        break;
      case PlayerRole.S:
      case PlayerRole.O:
        if (fundamental == Fundamental.attack) return 1.2;
        break;
      case PlayerRole.C:
        if (fundamental == Fundamental.block) return 1.2;
        break;
      case PlayerRole.L:
        if (fundamental == Fundamental.reception || fundamental == Fundamental.defense) return 1.2;
        break;
    }
    return 1.0;
  }
}
