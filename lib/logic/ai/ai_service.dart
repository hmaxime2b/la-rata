import 'dart:math';
import '../../models/card_model.dart';
import '../../models/contract.dart';
import '../../models/game_state.dart';
import '../trick_service.dart';

enum AiDifficulty { easy, medium, hard }

class AiService {
  final AiDifficulty difficulty;
  final _rng = Random();

  // Hard AI tracks played cards
  final Set<CardModel> _playedCards = {};

  AiService(this.difficulty);

  void recordPlayedCard(CardModel card) {
    _playedCards.add(card);
  }

  void reset() {
    _playedCards.clear();
  }

  // Choose a card to play in a trick-based contract
  CardModel chooseTrickCard({
    required List<CardModel> hand,
    required List<TrickCard> currentTrick,
    required Contract contract,
    required int trickNumber,
    required int announcerId,
    required int myPlayerId,
  }) {
    final valid = TrickService.validCards(hand, currentTrick, contract, trickNumber);

    switch (difficulty) {
      case AiDifficulty.easy:
        return _randomCard(valid);
      case AiDifficulty.medium:
        return _mediumTrickCard(valid, currentTrick, contract, trickNumber);
      case AiDifficulty.hard:
        return _hardTrickCard(valid, currentTrick, contract, trickNumber, hand);
    }
  }

  // Choose a card to play in Réussite
  CardModel? chooseReussiteCard({
    required List<CardModel> hand,
    required ReussiteBoard board,
  }) {
    final playable = hand.where((c) => board.canPlace(c)).toList();
    if (playable.isEmpty) return null;

    switch (difficulty) {
      case AiDifficulty.easy:
        return _randomCard(playable);
      case AiDifficulty.medium:
        return _mediumReussiteCard(playable, hand, board);
      case AiDifficulty.hard:
        return _hardReussiteCard(playable, hand, board);
    }
  }

  // Choisit UN contrat en fonction de la main actuelle
  Contract chooseContractNow(List<CardModel> hand, List<Contract> remaining) {
    if (remaining.length == 1) return remaining.first;

    switch (difficulty) {
      case AiDifficulty.easy:
        return remaining[_rng.nextInt(remaining.length)];
      case AiDifficulty.medium:
        return _mediumChooseContract(hand, remaining);
      case AiDifficulty.hard:
        return _hardChooseContract(hand, remaining);
    }
  }

  Contract _mediumChooseContract(List<CardModel> hand, List<Contract> remaining) {
    final hearts = hand.where((c) => c.isHeart).length;
    final queens = hand.where((c) => c.isQueen).length;
    final hasKingOfHearts = hand.any((c) => c.isKingOfHearts);
    final highCards = hand.where((c) => c.rank >= 5).length; // Dame, Roi, As

    // Potentiel de capot : main très forte (beaucoup de hautes cartes)
    final capotPotential = highCards >= 6;

    // Priorités selon la main
    final scores = <Contract, int>{};
    for (final c in remaining) {
      scores[c] = _contractScore(c, hearts, queens, hasKingOfHearts,
          highCards, capotPotential);
    }

    // Choisit le contrat avec le score le plus élevé (meilleure opportunité)
    return remaining.reduce((a, b) => (scores[a] ?? 0) >= (scores[b] ?? 0) ? a : b);
  }

  int _contractScore(Contract c, int hearts, int queens, bool hasKoH,
      int highCards, bool capotPotential) {
    switch (c) {
      case Contract.reussite:
        // Bonne main pour réussite si on a des cartes basses (peut finir premier)
        final lowCards = 8 - highCards;
        return 50 + lowCards * 5;

      case Contract.coeurs:
        // Jouer Cœurs si on a peu de cœurs (on prendra moins) OU si on peut capot
        if (capotPotential) return 80;
        return 60 - hearts * 8; // Moins de cœurs = meilleur moment

      case Contract.dames:
        if (capotPotential) return 75;
        return 60 - queens * 15; // Moins de dames = meilleur moment

      case Contract.roiCoeur:
        if (hasKoH && !capotPotential) return 20; // Dangereux si on l'a
        if (capotPotential) return 70;
        return 55;

      case Contract.plis:
        if (capotPotential) return 85;
        return 60 - highCards * 5;

      case Contract.der:
        if (capotPotential) return 70;
        // Bonne main pour Der si on a peu de hautes cartes (évite le dernier pli)
        return 65 - highCards * 4;

      case Contract.rata:
        // Rata = plus risqué, jouer quand on peut capot ou en dernier recours
        if (capotPotential) return 100;
        return 30; // Sinon éviter de le jouer tôt
    }
  }

  Contract _hardChooseContract(List<CardModel> hand, List<Contract> remaining) {
    // Même logique que medium mais avec analyse plus fine
    final hearts = hand.where((c) => c.isHeart).length;
    final queens = hand.where((c) => c.isQueen).length;
    final hasKoH = hand.any((c) => c.isKingOfHearts);
    final highCards = hand.where((c) => c.rank >= 5).length;
    final aces = hand.where((c) => c.isAce).length;

    // Main très homogène = bon pour capot
    final suitCounts = <Suit, int>{};
    for (final card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
    }
    final maxSuit = suitCounts.values.fold(0, (a, b) => a > b ? a : b);
    final capotPotential = highCards >= 5 && maxSuit >= 4;

    final scores = <Contract, int>{};
    for (final c in remaining) {
      int s = _contractScore(c, hearts, queens, hasKoH, highCards, capotPotential);
      // Hard: bonus si on a des As (utile en Réussite pour tours bonus)
      if (c == Contract.reussite) s += aces * 10;
      // Hard: si main dominante dans une couleur, Plis capot plus probable
      if (c == Contract.plis && maxSuit >= 5) s += 20;
      scores[c] = s;
    }

    return remaining.reduce((a, b) => (scores[a] ?? 0) >= (scores[b] ?? 0) ? a : b);
  }

  // ─── EASY ───────────────────────────────────────────────────────────────────

  CardModel _randomCard(List<CardModel> cards) {
    return cards[_rng.nextInt(cards.length)];
  }

  // ─── MEDIUM ─────────────────────────────────────────────────────────────────

  CardModel _mediumTrickCard(
    List<CardModel> valid,
    List<TrickCard> currentTrick,
    Contract contract,
    int trickNumber,
  ) {
    if (currentTrick.isEmpty) {
      return _mediumLead(valid, contract);
    }
    return _mediumFollow(valid, currentTrick, contract);
  }

  CardModel _mediumLead(List<CardModel> valid, Contract contract) {
    switch (contract) {
      case Contract.plis:
      case Contract.coeurs:
      case Contract.dames:
      case Contract.roiCoeur:
      case Contract.der:
      case Contract.rata:
        // Lead lowest to avoid winning
        return _lowestCard(valid);
      case Contract.reussite:
        return _randomCard(valid);
    }
  }

  CardModel _mediumFollow(
    List<CardModel> valid,
    List<TrickCard> currentTrick,
    Contract contract,
  ) {
    final ledSuit = currentTrick.first.card.suit;
    final currentWinner = _currentWinningCard(currentTrick);

    final sameSuit = valid.where((c) => c.suit == ledSuit).toList();

    if (sameSuit.isEmpty) {
      // Can't follow — discard most dangerous card
      return _discardForContract(valid, contract);
    }

    // Play just under the winner if possible, else lowest
    final underWinner = sameSuit
        .where((c) => c.rank < currentWinner.rank)
        .toList();

    if (underWinner.isNotEmpty) {
      // Play highest card that still loses
      underWinner.sort((a, b) => b.rank - a.rank);
      return underWinner.first;
    }

    // Must win — play lowest winning card to minimize future damage
    sameSuit.sort((a, b) => a.rank - b.rank);
    return sameSuit.first;
  }

  CardModel _discardForContract(List<CardModel> valid, Contract contract) {
    // Discard what hurts most if kept
    switch (contract) {
      case Contract.roiCoeur:
        final king = valid.firstWhere((c) => c.isKingOfHearts, orElse: () => _lowestCard(valid));
        return king;
      case Contract.dames:
        final queen = valid.firstWhere((c) => c.isQueen, orElse: () => _lowestCard(valid));
        return queen;
      case Contract.coeurs:
      case Contract.rata:
        final heart = valid.firstWhere((c) => c.isHeart, orElse: () => _lowestCard(valid));
        return heart;
      default:
        return _lowestCard(valid);
    }
  }

  CardModel _mediumReussiteCard(
    List<CardModel> playable,
    List<CardModel> hand,
    ReussiteBoard board,
  ) {
    // Prefer playing cards that unlock more of our hand
    CardModel? best;
    int bestUnlocked = -1;

    for (final card in playable) {
      // Simulate placing the card and count how many more become playable
      final tempBoard = _cloneBoard(board);
      tempBoard.place(card);
      final afterHand = hand.where((c) => c != card).toList();
      final unlocked = afterHand.where((c) => tempBoard.canPlace(c)).length;
      if (unlocked > bestUnlocked) {
        bestUnlocked = unlocked;
        best = card;
      }
    }
    return best ?? playable.first;
  }

  // ─── HARD ───────────────────────────────────────────────────────────────────

  CardModel _hardTrickCard(
    List<CardModel> valid,
    List<TrickCard> currentTrick,
    Contract contract,
    int trickNumber,
    List<CardModel> fullHand,
  ) {
    // Same as medium but also considers played cards to estimate risk
    if (currentTrick.isEmpty) {
      return _hardLead(valid, contract, fullHand);
    }
    return _hardFollow(valid, currentTrick, contract, fullHand);
  }

  CardModel _hardLead(List<CardModel> valid, Contract contract, List<CardModel> hand) {
    switch (contract) {
      case Contract.roiCoeur:
        // Try to force others to play king or hearts by leading hearts
        final hearts = valid.where((c) => c.isHeart && !c.isKingOfHearts).toList();
        if (hearts.isNotEmpty) return _lowestCard(hearts);
        return _lowestCard(valid);

      case Contract.dames:
        // Avoid leading suits where queens might be played
        final safeCards = valid.where((c) => !c.isQueen).toList();
        return _lowestCard(safeCards.isNotEmpty ? safeCards : valid);

      case Contract.coeurs:
      case Contract.rata:
        final nonHearts = valid.where((c) => !c.isHeart).toList();
        return _lowestCard(nonHearts.isNotEmpty ? nonHearts : valid);

      default:
        return _lowestCard(valid);
    }
  }

  CardModel _hardFollow(
    List<CardModel> valid,
    List<TrickCard> currentTrick,
    Contract contract,
    List<CardModel> hand,
  ) {
    final ledSuit = currentTrick.first.card.suit;
    final currentWinner = _currentWinningCard(currentTrick);
    final sameSuit = valid.where((c) => c.suit == ledSuit).toList();

    if (sameSuit.isEmpty) {
      return _hardDiscard(valid, contract, currentTrick);
    }

    final losing = sameSuit.where((c) => c.rank < currentWinner.rank).toList();

    if (losing.isNotEmpty) {
      losing.sort((a, b) => b.rank - a.rank);
      return losing.first;
    }

    // Must win — evaluate risk of winning this trick
    sameSuit.sort((a, b) => a.rank - b.rank);
    return sameSuit.first;
  }

  CardModel _hardDiscard(
    List<CardModel> valid,
    Contract contract,
    List<TrickCard> currentTrick,
  ) {
    switch (contract) {
      case Contract.roiCoeur:
        if (valid.any((c) => c.isKingOfHearts)) {
          return valid.firstWhere((c) => c.isKingOfHearts);
        }
        final hearts = valid.where((c) => c.isHeart).toList();
        if (hearts.isNotEmpty) return _highestCard(hearts);
        return _highestCard(valid);

      case Contract.dames:
        final queens = valid.where((c) => c.isQueen).toList();
        if (queens.isNotEmpty) return queens.first;
        return _highestCard(valid);

      case Contract.coeurs:
      case Contract.rata:
        final hearts = valid.where((c) => c.isHeart).toList();
        if (hearts.isNotEmpty) return _highestCard(hearts);
        return _highestCard(valid);

      default:
        return _highestCard(valid);
    }
  }

  CardModel _hardReussiteCard(
    List<CardModel> playable,
    List<CardModel> hand,
    ReussiteBoard board,
  ) {
    // Same strategic as medium for now
    return _mediumReussiteCard(playable, hand, board);
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────────

  CardModel _lowestCard(List<CardModel> cards) {
    return cards.reduce((a, b) => a.rank < b.rank ? a : b);
  }

  CardModel _highestCard(List<CardModel> cards) {
    return cards.reduce((a, b) => a.rank > b.rank ? a : b);
  }

  CardModel _currentWinningCard(List<TrickCard> trick) {
    final ledSuit = trick.first.card.suit;
    return trick
        .where((t) => t.card.suit == ledSuit)
        .map((t) => t.card)
        .reduce((a, b) => a.rank > b.rank ? a : b);
  }

  ReussiteBoard _cloneBoard(ReussiteBoard board) {
    final clone = ReussiteBoard();
    for (final suit in Suit.values) {
      clone.jackPlaced[suit] = board.jackPlaced[suit]!;
      clone.above[suit] = List.from(board.above[suit]!);
      clone.below[suit] = List.from(board.below[suit]!);
    }
    return clone;
  }
}
