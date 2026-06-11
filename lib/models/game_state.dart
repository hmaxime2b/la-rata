import 'card_model.dart';
import 'contract.dart';
import 'player.dart';

class ContractResult {
  final int announcerIndex;
  final String announcerName;
  final Contract contract;
  final Map<int, int> pointsByPlayer; // playerId → pts ce contrat
  final int? capotPlayerId;

  ContractResult({
    required this.announcerIndex,
    required this.announcerName,
    required this.contract,
    required this.pointsByPlayer,
    this.capotPlayerId,
  });
}

enum GamePhase {
  initialDraw,
  contractSelection,
  trickPlay,
  reussitePlay,
  contractEnd,
  gameEnd,
}

class TrickCard {
  final CardModel card;
  final int playerId;
  TrickCard(this.card, this.playerId);
}

class ReussiteBoard {
  // 4 suits, each row: index 0 = jack position (center)
  // below[suit] = cards placed below jack (10,9,8,7)
  // above[suit] = cards placed above jack (Q,K,A)
  final Map<Suit, List<CardModel>> above = {};
  final Map<Suit, List<CardModel>> below = {};
  final Map<Suit, bool> jackPlaced = {};

  ReussiteBoard() {
    for (final suit in Suit.values) {
      above[suit] = [];
      below[suit] = [];
      jackPlaced[suit] = false;
    }
  }

  bool canPlace(CardModel card) {
    if (card.isJack) return !jackPlaced[card.suit]!;
    if (!jackPlaced[card.suit]!) return false;
    if (card.value.index > CardValue.jack.index) {
      // above jack: must be consecutive
      final placed = above[card.suit]!;
      if (placed.isEmpty) return card.value == CardValue.queen;
      return card.value.index == placed.last.value.index + 1;
    } else {
      // below jack: must be consecutive downward
      final placed = below[card.suit]!;
      if (placed.isEmpty) return card.value == CardValue.ten;
      return card.value.index == placed.last.value.index - 1;
    }
  }

  void place(CardModel card) {
    if (card.isJack) {
      jackPlaced[card.suit] = true;
    } else if (card.value.index > CardValue.jack.index) {
      above[card.suit]!.add(card);
    } else {
      below[card.suit]!.add(card);
    }
  }

  CardModel? get topCard {
    CardModel? top;
    for (final suit in Suit.values) {
      if (!jackPlaced[suit]!) continue;
      final a = above[suit]!;
      final candidate = a.isNotEmpty ? a.last : CardModel(suit, CardValue.jack);
      if (top == null || candidate.rank > top.rank) top = candidate;
    }
    return top;
  }
}

class GameState {
  List<Player> players;
  int announcerIndex;
  int contractIndexInTurn;
  GamePhase phase;
  Contract? currentContract;
  List<Contract> currentContractOrder;

  // Trick play state
  List<TrickCard> currentTrick;
  int leadPlayerIndex;
  int trickCount;
  Map<int, int> tricksWonByPlayer;
  Map<int, int> heartsWonByPlayer;
  Map<int, int> queensWonByPlayer;
  Map<int, bool> kingOfHeartsWonByPlayer;
  int lastTrickWinner;

  // Réussite state
  ReussiteBoard? reussiteBoard;
  int reussiteCurrentPlayer;
  List<int> reussiteFinishOrder;

  // Contrats restants à jouer pour l'annonceur courant
  List<Contract> remainingContracts;

  // Historique complet des résultats
  List<ContractResult> history;

  // Initial draw
  List<CardModel?> initialDraw;

  GameState({required this.players})
      : announcerIndex = 0,
        contractIndexInTurn = 0,
        phase = GamePhase.initialDraw,
        currentContractOrder = [],
        remainingContracts = [],
        history = [],
        currentTrick = [],
        leadPlayerIndex = 0,
        trickCount = 0,
        tricksWonByPlayer = {},
        heartsWonByPlayer = {},
        queensWonByPlayer = {},
        kingOfHeartsWonByPlayer = {},
        lastTrickWinner = 0,
        reussiteCurrentPlayer = 0,
        reussiteFinishOrder = [],
        initialDraw = List.filled(4, null);

  Player get announcer => players[announcerIndex];
  Player get currentLeadPlayer => players[leadPlayerIndex];

  bool get isGameOver => phase == GamePhase.gameEnd;

  void resetTrickState() {
    currentTrick = [];
    trickCount = 0;
    tricksWonByPlayer = {for (var p in players) p.id: 0};
    heartsWonByPlayer = {for (var p in players) p.id: 0};
    queensWonByPlayer = {for (var p in players) p.id: 0};
    kingOfHeartsWonByPlayer = {for (var p in players) p.id: false};
    lastTrickWinner = -1;
  }
}
