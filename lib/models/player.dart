import 'card_model.dart';
import 'contract.dart';

enum PlayerType { human, ai }

class Player {
  final int id;
  final String name;
  final PlayerType type;
  List<CardModel> hand;
  int totalScore;
  List<int> contractScores;
  List<Contract> contractOrder;

  Player({
    required this.id,
    required this.name,
    required this.type,
    List<CardModel>? hand,
  })  : hand = hand ?? [],
        totalScore = 0,
        contractScores = [],
        contractOrder = [];

  bool get isHuman => type == PlayerType.human;

  void addScore(int points) {
    totalScore += points;
    contractScores.add(points);
  }
}
