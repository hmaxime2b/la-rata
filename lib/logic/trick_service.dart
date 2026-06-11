import '../models/card_model.dart';
import '../models/contract.dart';
import '../models/game_state.dart';

class TrickService {
  // Returns valid cards the player can play given the current trick
  static List<CardModel> validCards(
    List<CardModel> hand,
    List<TrickCard> currentTrick,
    Contract contract,
    int trickNumber, // 0-indexed
  ) {
    if (currentTrick.isEmpty) {
      // Leading the trick
      if (_isFirstTrickHeartBanned(contract, trickNumber)) {
        final nonHearts = hand.where((c) => !c.isHeart).toList();
        return nonHearts.isEmpty ? hand : nonHearts;
      }
      return hand;
    }

    final ledSuit = currentTrick.first.card.suit;
    final sameSuit = hand.where((c) => c.suit == ledSuit).toList();
    return sameSuit.isEmpty ? hand : sameSuit;
  }

  static bool _isFirstTrickHeartBanned(Contract contract, int trickNumber) {
    if (trickNumber != 0) return false;
    return contract == Contract.coeurs ||
        contract == Contract.roiCoeur ||
        contract == Contract.rata;
  }

  // Returns index of winning player in the trick
  static int resolveTrick(List<TrickCard> trick) {
    assert(trick.isNotEmpty);
    final ledSuit = trick.first.card.suit;
    int winnerIdx = 0;
    for (int i = 1; i < trick.length; i++) {
      if (trick[i].card.suit == ledSuit &&
          trick[i].card.rank > trick[winnerIdx].card.rank) {
        winnerIdx = i;
      }
    }
    return trick[winnerIdx].playerId;
  }

  // Calculate points from a completed trick for each player, depending on contract
  static Map<int, int> trickPoints(
    List<TrickCard> trick,
    int winnerId,
    Contract contract,
    bool winnerIsAnnouncer,
    bool isLastTrick,
  ) {
    final points = <int, int>{};
    final multiplier = winnerIsAnnouncer ? 2 : 1;

    switch (contract) {
      case Contract.plis:
        points[winnerId] = 5 * multiplier;
        break;

      case Contract.coeurs:
        int hearts = trick.where((t) => t.card.isHeart).length;
        if (hearts > 0) points[winnerId] = hearts * 5 * multiplier;
        break;

      case Contract.dames:
        int queens = trick.where((t) => t.card.isQueen).length;
        if (queens > 0) points[winnerId] = queens * 10 * multiplier;
        break;

      case Contract.roiCoeur:
        bool hasKing = trick.any((t) => t.card.isKingOfHearts);
        if (hasKing) points[winnerId] = 40 * multiplier;
        break;

      case Contract.der:
        if (isLastTrick) points[winnerId] = 40 * multiplier;
        break;

      case Contract.rata:
        int p = 5 * multiplier; // plis
        int hearts = trick.where((t) => t.card.isHeart).length;
        int queens = trick.where((t) => t.card.isQueen).length;
        bool hasKing = trick.any((t) => t.card.isKingOfHearts);
        int total = p + hearts * 5 * multiplier + queens * 10 * multiplier;
        if (hasKing) total += 40 * multiplier;
        if (isLastTrick) total += 40 * multiplier;
        points[winnerId] = total;
        break;

      case Contract.reussite:
        break;
    }

    return points;
  }
}
