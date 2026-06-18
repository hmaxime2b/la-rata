import 'dart:math';
import '../../models/card_model.dart';
import '../../models/contract.dart';
import '../../models/game_state.dart';
import '../trick_service.dart';

enum AiDifficulty { easy, medium, hard }

class AiService {
  final AiDifficulty difficulty;
  final _rng = Random();

  // Cartes jouées depuis le début du contrat
  final Set<CardModel> _playedCards = {};

  AiService(this.difficulty);

  void recordPlayedCard(CardModel card) => _playedCards.add(card);
  void reset() => _playedCards.clear();

  // ═══════════════════════════════════════════════════════════════════════════
  // API PUBLIQUE
  // ═══════════════════════════════════════════════════════════════════════════

  CardModel chooseTrickCard({
    required List<CardModel> hand,
    required List<TrickCard> currentTrick,
    required Contract contract,
    required int trickNumber,
    required int announcerId,
    required int myPlayerId,
    Map<int, int> tricksWonByPlayer = const {},
    Map<int, Set<Suit>> playerVoids = const {},
    int humanPlayerId = 0,
  }) {
    final valid = TrickService.validCards(hand, currentTrick, contract, trickNumber);
    if (valid.length == 1) return valid.first;

    switch (difficulty) {
      case AiDifficulty.easy:
        return _easyCard(valid, currentTrick, contract);
      case AiDifficulty.medium:
        return _mediumCard(valid, currentTrick, contract, trickNumber, hand);
      case AiDifficulty.hard:
        return _hardCard(
          valid: valid,
          currentTrick: currentTrick,
          contract: contract,
          trickNumber: trickNumber,
          hand: hand,
          myPlayerId: myPlayerId,
          tricksWonByPlayer: tricksWonByPlayer,
          playerVoids: playerVoids,
          humanPlayerId: humanPlayerId,
        );
    }
  }

  CardModel? chooseReussiteCard({
    required List<CardModel> hand,
    required ReussiteBoard board,
  }) {
    final playable = hand.where((c) => board.canPlace(c)).toList();
    if (playable.isEmpty) return null;
    switch (difficulty) {
      case AiDifficulty.easy:
        // 40% chance de passer même avec une carte jouable
        if (_rng.nextInt(10) < 4) return null;
        return playable[_rng.nextInt(playable.length)];
      case AiDifficulty.medium:
        return _mediumReussite(playable, hand, board);
      case AiDifficulty.hard:
        return _hardReussite(playable, hand, board);
    }
  }

  Contract chooseContractNow(List<CardModel> hand, List<Contract> remaining) {
    if (remaining.length == 1) return remaining.first;
    switch (difficulty) {
      case AiDifficulty.easy:
        return remaining[_rng.nextInt(remaining.length)];
      case AiDifficulty.medium:
        return _chooseContract(hand, remaining, hard: false);
      case AiDifficulty.hard:
        return _chooseContract(hand, remaining, hard: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EASY — aléatoire avec quelques réflexes de survie
  // ═══════════════════════════════════════════════════════════════════════════

  CardModel _easyCard(List<CardModel> valid, List<TrickCard> trick, Contract contract) {
    // 60% random, 40% joue la plus basse
    return _rng.nextInt(10) < 4 ? _lowest(valid) : valid[_rng.nextInt(valid.length)];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEDIUM — stratégie par contrat, sans mémoire des cartes jouées
  // ═══════════════════════════════════════════════════════════════════════════

  CardModel _mediumCard(
    List<CardModel> valid,
    List<TrickCard> trick,
    Contract contract,
    int trickNumber,
    List<CardModel> hand,
  ) {
    if (trick.isEmpty) return _mediumLead(valid, contract, hand);
    return _mediumFollow(valid, trick, contract);
  }

  CardModel _mediumLead(List<CardModel> valid, Contract contract, List<CardModel> hand) {
    switch (contract) {
      case Contract.coeurs:
        final nonHearts = valid.where((c) => !c.isHeart).toList();
        return _lowest(nonHearts.isNotEmpty ? nonHearts : valid);

      case Contract.dames:
        final nonQueens = valid.where((c) => !c.isQueen).toList();
        return _lowest(nonQueens.isNotEmpty ? nonQueens : valid);

      case Contract.roiCoeur:
        // Si on a le Roi de Cœur, on cherche à s'en défaire via un lead cœur
        if (hand.any((c) => c.isKingOfHearts)) {
          final hearts = valid.where((c) => c.isHeart && !c.isKingOfHearts).toList();
          if (hearts.isNotEmpty) return _lowest(hearts);
        }
        return _lowest(valid);

      case Contract.plis:
      case Contract.der:
      case Contract.rata:
        return _lowest(valid);

      case Contract.reussite:
        return valid[_rng.nextInt(valid.length)];
    }
  }

  CardModel _mediumFollow(List<CardModel> valid, List<TrickCard> trick, Contract contract) {
    final ledSuit = trick.first.card.suit;
    final winner = _winnerCard(trick);
    final sameSuit = valid.where((c) => c.suit == ledSuit).toList();

    if (sameSuit.isEmpty) return _mediumDiscard(valid, contract);

    // Perdre gracieusement : jouer la plus haute carte sous le gagnant actuel
    final losing = sameSuit.where((c) => c.rank < winner.rank).toList();
    if (losing.isNotEmpty) return _highest(losing);

    // Forcé de gagner : jouer la plus basse
    return _lowest(sameSuit);
  }

  CardModel _mediumDiscard(List<CardModel> valid, Contract contract) {
    switch (contract) {
      case Contract.roiCoeur:
        if (valid.any((c) => c.isKingOfHearts)) return valid.firstWhere((c) => c.isKingOfHearts);
        final hearts = valid.where((c) => c.isHeart).toList();
        return _highest(hearts.isNotEmpty ? hearts : valid);

      case Contract.dames:
        final queens = valid.where((c) => c.isQueen).toList();
        if (queens.isNotEmpty) return queens.first;
        return _highest(valid);

      case Contract.coeurs:
      case Contract.rata:
        final hearts = valid.where((c) => c.isHeart).toList();
        if (hearts.isNotEmpty) return _highest(hearts);
        final queens = valid.where((c) => c.isQueen).toList();
        if (queens.isNotEmpty) return queens.first;
        return _highest(valid);

      case Contract.plis:
      case Contract.der:
        return _highest(valid); // Écouler les hautes cartes

      default:
        return _lowest(valid);
    }
  }

  CardModel _mediumReussite(List<CardModel> playable, List<CardModel> hand, ReussiteBoard board) {
    // Jouer la carte qui débloque le plus de cartes futures
    CardModel? best;
    int bestScore = -1;
    for (final card in playable) {
      final b = _cloneBoard(board);
      b.place(card);
      final remaining = hand.where((c) => c != card).toList();
      final unlocked = remaining.where((c) => b.canPlace(c)).length;
      if (unlocked > bestScore) {
        bestScore = unlocked;
        best = card;
      }
    }
    return best ?? playable.first;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HARD — mémoire complète, ciblage du joueur humain, stratégie avancée
  // ═══════════════════════════════════════════════════════════════════════════

  CardModel _hardCard({
    required List<CardModel> valid,
    required List<TrickCard> currentTrick,
    required Contract contract,
    required int trickNumber,
    required List<CardModel> hand,
    required int myPlayerId,
    required Map<int, int> tricksWonByPlayer,
    required Map<int, Set<Suit>> playerVoids,
    required int humanPlayerId,
  }) {
    if (currentTrick.isEmpty) {
      return _hardLead(
        valid: valid,
        contract: contract,
        trickNumber: trickNumber,
        hand: hand,
        playerVoids: playerVoids,
        humanPlayerId: humanPlayerId,
      );
    }
    return _hardFollow(
      valid: valid,
      trick: currentTrick,
      contract: contract,
      trickNumber: trickNumber,
      hand: hand,
    );
  }

  CardModel _hardLead({
    required List<CardModel> valid,
    required Contract contract,
    required int trickNumber,
    required List<CardModel> hand,
    required Map<int, Set<Suit>> playerVoids,
    required int humanPlayerId,
  }) {
    final humanVoids = playerVoids[humanPlayerId] ?? {};

    switch (contract) {
      case Contract.coeurs:
        final remainingHearts = _remainingInSuit(Suit.hearts, hand);
        // Forcer l'humain à défausser des cœurs : attaquer une couleur où il est void
        if (remainingHearts > 0) {
          final forceCard = _forcingLead(valid, humanVoids, excludeSuit: Suit.hearts);
          if (forceCard != null) return forceCard;
        }
        // Sinon mener la carte "sortie sûre" ou la plus basse non-cœur
        final exitCard = _safeExitCard(valid.where((c) => !c.isHeart).toList());
        if (exitCard != null) return exitCard;
        final nonHearts = valid.where((c) => !c.isHeart).toList();
        return _lowest(nonHearts.isNotEmpty ? nonHearts : valid);

      case Contract.dames:
        final queensLeft = _remainingQueens(hand);
        if (queensLeft > 0) {
          final forceCard = _forcingLead(valid, humanVoids, excludeSuit: null);
          if (forceCard != null) return forceCard;
        }
        final nonQueens = valid.where((c) => !c.isQueen).toList();
        final exitCard = _safeExitCard(nonQueens);
        if (exitCard != null) return exitCard;
        return _lowest(nonQueens.isNotEmpty ? nonQueens : valid);

      case Contract.roiCoeur:
        final kohPlayed = _playedCards.any((c) => c.isKingOfHearts);
        if (!kohPlayed) {
          // Tenter de forcer l'humain à prendre le Roi de Cœur
          if (humanVoids.isNotEmpty) {
            final forceCard = _forcingLead(valid, humanVoids, excludeSuit: null);
            if (forceCard != null) return forceCard;
          }
          // Si on a le Roi de Cœur, chercher à s'en défaire
          if (hand.any((c) => c.isKingOfHearts)) {
            final hearts = valid.where((c) => c.isHeart && !c.isKingOfHearts).toList();
            if (hearts.isNotEmpty) return _lowest(hearts);
          }
        }
        final exitCard = _safeExitCard(valid);
        return exitCard ?? _lowest(valid);

      case Contract.plis:
        // Trouver une carte "sortie" garantie de perdre
        final exit = _safeExitCard(valid);
        if (exit != null) return exit;
        // Forcer l'humain à gagner
        if (humanVoids.isNotEmpty) {
          final forceCard = _forcingLead(valid, humanVoids, excludeSuit: null);
          if (forceCard != null) return forceCard;
        }
        return _lowest(valid);

      case Contract.der:
        if (trickNumber == 7) {
          // Dernier pli : mener la plus haute pour forcer quelqu'un d'autre à gagner
          return _highest(valid);
        }
        if (trickNumber >= 5) {
          // Écouler les hautes cartes dangereuses pour le dernier pli
          final dangerousCards = valid.where((c) => c.rank >= 5).toList();
          if (dangerousCards.isNotEmpty) return _highest(dangerousCards);
        }
        final exit = _safeExitCard(valid);
        return exit ?? _lowest(valid);

      case Contract.rata:
        // Priorité : se défaire du Roi de Cœur, puis forcer l'humain
        if (hand.any((c) => c.isKingOfHearts)) {
          final hearts = valid.where((c) => c.isHeart && !c.isKingOfHearts).toList();
          if (hearts.isNotEmpty) return _lowest(hearts);
        }
        if (humanVoids.isNotEmpty) {
          final forceCard = _forcingLead(valid, humanVoids, excludeSuit: null);
          if (forceCard != null) return forceCard;
        }
        return _lowest(valid);

      case Contract.reussite:
        return valid[_rng.nextInt(valid.length)];
    }
  }

  CardModel _hardFollow({
    required List<CardModel> valid,
    required List<TrickCard> trick,
    required Contract contract,
    required int trickNumber,
    required List<CardModel> hand,
  }) {
    final ledSuit = trick.first.card.suit;
    final winner = _winnerCard(trick);
    final sameSuit = valid.where((c) => c.suit == ledSuit).toList();
    final isLast = trick.length == 3; // on joue en dernier

    if (sameSuit.isEmpty) {
      return _hardDiscard(valid: valid, contract: contract, trick: trick, trickNumber: trickNumber, isLast: isLast);
    }

    final trickDangerous = _trickIsDangerous(trick, contract);
    final losing = sameSuit.where((c) => c.rank < winner.rank).toList();

    if (losing.isNotEmpty) {
      if (trickDangerous) {
        // Pli dangereux : perdre avec la carte la plus haute qui perd encore
        return _highest(losing);
      }
      if (isLast) {
        // On joue en dernier : on peut être précis
        // Si le pli est safe, jouer la plus haute sous le gagnant (économiser les basses)
        return _highest(losing);
      }
      return _highest(losing);
    }

    // Forcé de gagner
    // Jouer la plus basse carte gagnante pour minimiser les dégâts
    return _lowest(sameSuit);
  }

  CardModel _hardDiscard({
    required List<CardModel> valid,
    required Contract contract,
    required List<TrickCard> trick,
    required int trickNumber,
    required bool isLast,
  }) {
    switch (contract) {
      case Contract.roiCoeur:
        if (valid.any((c) => c.isKingOfHearts)) return valid.firstWhere((c) => c.isKingOfHearts);
        final hearts = valid.where((c) => c.isHeart).toList();
        if (hearts.isNotEmpty) return _highest(hearts);
        return _highest(valid);

      case Contract.dames:
        final queens = valid.where((c) => c.isQueen).toList();
        if (queens.isNotEmpty) {
          // Défausser la dame la plus coûteuse d'abord
          return queens.reduce((a, b) => a.rank >= b.rank ? a : b);
        }
        return _highest(valid);

      case Contract.coeurs:
        final hearts = valid.where((c) => c.isHeart).toList();
        if (hearts.isNotEmpty) return _highest(hearts);
        return _highest(valid);

      case Contract.plis:
      case Contract.der:
        // Écouler les as et rois — ils sont dangereux pour les futurs plis
        final aces = valid.where((c) => c.isAce).toList();
        if (aces.isNotEmpty) return aces.first;
        final kings = valid.where((c) => c.value == CardValue.king).toList();
        if (kings.isNotEmpty) return kings.first;
        return _highest(valid);

      case Contract.rata:
        // Ordre de priorité : Roi♥ > Dames > Cœurs > Hautes cartes
        if (valid.any((c) => c.isKingOfHearts)) return valid.firstWhere((c) => c.isKingOfHearts);
        final queens = valid.where((c) => c.isQueen).toList();
        if (queens.isNotEmpty) return queens.first;
        final hearts = valid.where((c) => c.isHeart).toList();
        if (hearts.isNotEmpty) return _highest(hearts);
        return _highest(valid);

      default:
        return _highest(valid);
    }
  }

  CardModel _hardReussite(List<CardModel> playable, List<CardModel> hand, ReussiteBoard board) {
    // Lookahead 2 niveaux : maximize les cartes débloquées
    CardModel? best;
    int bestScore = -1;

    for (final card in playable) {
      final b1 = _cloneBoard(board);
      b1.place(card);
      final hand1 = hand.where((c) => c != card).toList();
      final next1 = hand1.where((c) => b1.canPlace(c)).toList();

      int score = next1.length * 10;
      if (card.isAce) score += 20; // As = tour bonus garanti

      for (final card2 in next1) {
        final b2 = _cloneBoard(b1);
        b2.place(card2);
        final hand2 = hand1.where((c) => c != card2).toList();
        final next2 = hand2.where((c) => b2.canPlace(c)).length;
        score += next2 * 2;
        if (card2.isAce) score += 10;
      }

      if (score > bestScore) {
        bestScore = score;
        best = card;
      }
    }
    return best ?? playable.first;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHOIX DE CONTRAT
  // ═══════════════════════════════════════════════════════════════════════════

  Contract _chooseContract(List<CardModel> hand, List<Contract> remaining, {required bool hard}) {
    final a = _analyze(hand);
    final scores = <Contract, int>{};

    for (final c in remaining) {
      int s = _contractScore(c, a);
      if (hard) {
        // Ajustements supplémentaires en mode difficile
        if (c == Contract.reussite && a.aces > 0) s += a.aces * 15;
        if (c == Contract.plis && a.maxSuit >= 5) s += 25;
        if (c == Contract.rata && a.capotPotential) s += 60;
        if (c == Contract.coeurs && a.hearts >= 4) s -= 25;
        if (c == Contract.dames && a.queens >= 3) s -= 30;
        if (c == Contract.roiCoeur && a.hasKoH && !a.capotPotential) s -= 40;
      }
      scores[c] = s;
    }

    final sorted = remaining.toList()
      ..sort((a, b) => (scores[b] ?? 0) - (scores[a] ?? 0));

    // Hard : 15% de variance pour être imprévisible
    if (hard && sorted.length >= 2 && _rng.nextInt(100) < 15) return sorted[1];
    return sorted.first;
  }

  int _contractScore(Contract c, _HandAnalysis a) {
    switch (c) {
      case Contract.reussite:
        return 40 + a.lowCards * 7 - a.highCards * 2;

      case Contract.coeurs:
        if (a.capotPotential) return 88;
        return 72 - a.hearts * 11;

      case Contract.dames:
        if (a.capotPotential) return 82;
        return 70 - a.queens * 20;

      case Contract.roiCoeur:
        if (a.hasKoH && !a.capotPotential) return 10;
        if (a.capotPotential) return 78;
        return 62;

      case Contract.plis:
        if (a.capotPotential) return 92;
        return 66 - a.highCards * 7;

      case Contract.der:
        if (a.capotPotential) return 76;
        return 58 - a.highCards * 6 + a.lowCards * 4;

      case Contract.rata:
        if (a.capotPotential) return 105;
        return 20 - a.hearts * 6 - a.queens * 9;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS — analyse de main, cartes, board
  // ═══════════════════════════════════════════════════════════════════════════

  _HandAnalysis _analyze(List<CardModel> hand) {
    final hearts = hand.where((c) => c.isHeart).length;
    final queens = hand.where((c) => c.isQueen).length;
    final hasKoH = hand.any((c) => c.isKingOfHearts);
    final highCards = hand.where((c) => c.rank >= 5).length; // D, R, A
    final aces = hand.where((c) => c.isAce).length;
    final lowCards = hand.where((c) => c.rank <= 2).length; // 7, 8, 9
    final suitCounts = <Suit, int>{};
    for (final card in hand) {
      suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
    }
    final maxSuit = suitCounts.values.fold(0, max);
    final capotPotential = highCards >= 6 || (highCards >= 5 && maxSuit >= 5);
    return _HandAnalysis(
      hearts: hearts, queens: queens, hasKoH: hasKoH,
      highCards: highCards, aces: aces, lowCards: lowCards,
      maxSuit: maxSuit, capotPotential: capotPotential,
    );
  }

  // Cartes d'une couleur pas encore jouées (hors main)
  int _remainingInSuit(Suit suit, List<CardModel> myHand) {
    final totalInSuit = CardValue.values.length; // 8
    final playedInSuit = _playedCards.where((c) => c.suit == suit).length;
    final inMyHand = myHand.where((c) => c.suit == suit).length;
    return totalInSuit - playedInSuit - inMyHand;
  }

  int _remainingQueens(List<CardModel> myHand) {
    final playedQueens = _playedCards.where((c) => c.isQueen).length;
    final myQueens = myHand.where((c) => c.isQueen).length;
    return 4 - playedQueens - myQueens;
  }

  // Trouve une carte garantie de perdre (il reste des cartes plus hautes non jouées)
  CardModel? _safeExitCard(List<CardModel> cards) {
    for (final card in cards) {
      final maxRank = CardValue.values.length - 1; // 7 = As
      final totalHigher = maxRank - card.rank;
      final playedHigher = _playedCards.where((c) => c.suit == card.suit && c.rank > card.rank).length;
      if (totalHigher - playedHigher > 0) return card;
    }
    return null;
  }

  // Trouve une carte à mener dans une couleur où l'humain est void → il devra défausser
  CardModel? _forcingLead(List<CardModel> valid, Set<Suit> humanVoids, {required Suit? excludeSuit}) {
    for (final suit in humanVoids) {
      if (suit == excludeSuit) continue;
      final suitCards = valid.where((c) => c.suit == suit).toList();
      if (suitCards.isNotEmpty) return _lowest(suitCards);
    }
    return null;
  }

  // Le pli actuel contient-il une carte dangereuse pour ce contrat ?
  bool _trickIsDangerous(List<TrickCard> trick, Contract contract) {
    switch (contract) {
      case Contract.coeurs: return trick.any((tc) => tc.card.isHeart);
      case Contract.dames: return trick.any((tc) => tc.card.isQueen);
      case Contract.roiCoeur: return trick.any((tc) => tc.card.isKingOfHearts);
      case Contract.plis: return true;
      case Contract.der: return false;
      case Contract.rata: return trick.any((tc) => tc.card.isHeart || tc.card.isQueen);
      case Contract.reussite: return false;
    }
  }

  CardModel _lowest(List<CardModel> cards) => cards.reduce((a, b) => a.rank < b.rank ? a : b);
  CardModel _highest(List<CardModel> cards) => cards.reduce((a, b) => a.rank > b.rank ? a : b);

  CardModel _winnerCard(List<TrickCard> trick) {
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

class _HandAnalysis {
  final int hearts, queens, highCards, aces, lowCards, maxSuit;
  final bool hasKoH, capotPotential;
  _HandAnalysis({
    required this.hearts, required this.queens, required this.hasKoH,
    required this.highCards, required this.aces, required this.lowCards,
    required this.maxSuit, required this.capotPotential,
  });
}
