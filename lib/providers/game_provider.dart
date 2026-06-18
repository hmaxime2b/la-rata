import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/card_model.dart';
import '../models/contract.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../logic/deck_service.dart';
import '../logic/trick_service.dart';
import '../logic/scoring_service.dart';
import '../logic/ai/ai_service.dart';

class GameProvider extends ChangeNotifier {
  late GameState state;
  late AiDifficulty difficulty;
  late List<AiService> aiServices;

  String? message;
  Map<int, int>? lastTrickPoints;
  int? lastTrickWinnerId;

  Map<int, int> _pendingScores = {};
  Map<int, int> _reussiteScores = {};
  Map<int, Set<Suit>> _playerVoids = {};
  int? lastCapotPlayerId;
  int _announcersDone = 0;
  bool _inAceBonusTurn = false;
  bool get inAceBonusTurn => _inAceBonusTurn;
  final _rng = Random();


  void startGame(AiDifficulty diff) {
    difficulty = diff;
    aiServices = List.generate(
      4,
      (i) => AiService(diff),
    );

    final players = [
      Player(id: 0, name: 'Toi', type: PlayerType.human),
      Player(id: 1, name: 'Alice', type: PlayerType.ai),
      Player(id: 2, name: 'Bob', type: PlayerType.ai),
      Player(id: 3, name: 'Charlie', type: PlayerType.ai),
    ];

    state = GameState(players: players);
    _dealCards();
    _doInitialDraw();
    notifyListeners();
  }

  void _dealCards() {
    final deck = DeckService.shuffle(DeckService.buildDeck());
    final hands = DeckService.deal(deck);
    for (int i = 0; i < 4; i++) {
      state.players[i].hand = hands[i];
    }
  }

  // Tirage pour déterminer le premier annonceur
  void _doInitialDraw() {
    final deck = DeckService.shuffle(DeckService.buildDeck());
    state.initialDraw = List.generate(4, (i) => deck[i]);

    // Le joueur avec la carte la plus faible est annonceur
    int minRank = 999;
    int announcerIdx = 0;
    for (int i = 0; i < 4; i++) {
      final card = state.initialDraw[i]!;
      if (card.rank < minRank) {
        minRank = card.rank;
        announcerIdx = i;
      }
    }
    state.announcerIndex = announcerIdx;
    _announcersDone = 0;
    state.phase = GamePhase.initialDraw;
  }

  void confirmInitialDraw() {
    _startAnnouncerTurn();
  }

  void _startAnnouncerTurn() {
    state.contractIndexInTurn = 0;
    state.remainingContracts = List.from(Contract.values);
    _dealAndSelectContract();
  }

  // Après chaque contrat, redistribuer et choisir le suivant
  void _dealAndSelectContract() {
    _dealCards();
    for (final ai in aiServices) {
      ai.reset();
    }

    if (state.announcer.isHuman) {
      state.phase = GamePhase.contractSelection;
      notifyListeners();
    } else {
      final chosen = aiServices[state.announcerIndex].chooseContractNow(
        state.players[state.announcerIndex].hand,
        state.remainingContracts,
      );
      _playContract(chosen);
    }
  }

  // Human choisit un contrat
  void setContractNow(Contract contract) {
    _playContract(contract);
  }

  void _playContract(Contract contract) {
    state.currentContract = contract;
    state.remainingContracts.remove(contract);

    if (contract == Contract.reussite) {
      _startReussite();
    } else {
      _startTrickContract();
    }
    notifyListeners();
  }

  void _startTrickContract() {
    state.resetTrickState();
    _pendingScores = {for (final p in state.players) p.id: 0};
    _playerVoids = {};
    lastCapotPlayerId = null;
    // First lead = right of announcer
    state.leadPlayerIndex =
        (state.announcerIndex + 3) % 4; // right = -1 mod 4
    state.phase = GamePhase.trickPlay;
    notifyListeners();
    _maybeAiPlay();
  }

  void _startReussite() {
    state.reussiteBoard = ReussiteBoard();
    state.reussiteFinishOrder = [];
    _reussiteScores = {};
    // Right of announcer starts
    state.reussiteCurrentPlayer = (state.announcerIndex + 3) % 4;
    state.phase = GamePhase.reussitePlay;
    notifyListeners();
    _maybeAiPlayReussite();
  }

  // ─── TRICK PLAY ────────────────────────────────────────────────────────────

  bool canPlayCard(CardModel card) {
    if (state.phase != GamePhase.trickPlay) return false;
    final humanIdx = _humanIndex();
    if (state.leadPlayerIndex != humanIdx &&
        state.currentTrick.length < _nextPlayerTurn()) {
      return false;
    }
    if (_currentTurnPlayer() != humanIdx) return false;

    final valid = TrickService.validCards(
      state.players[humanIdx].hand,
      state.currentTrick,
      state.currentContract!,
      state.trickCount,
    );
    return valid.contains(card);
  }

  void playCard(CardModel card) {
    if (state.currentTrick.length >= 4) return;
    final playerIdx = _currentTurnPlayer();
    _doPlayCard(playerIdx, card);
  }

  void _doPlayCard(int playerIdx, CardModel card) {
    state.players[playerIdx].hand.remove(card);
    state.currentTrick.add(TrickCard(card, playerIdx));
    for (final ai in aiServices) {
      ai.recordPlayedCard(card);
    }
    notifyListeners();

    if (state.currentTrick.length == 4) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (state.currentTrick.length == 4) _resolveTrick();
      });
    } else {
      Future.delayed(const Duration(milliseconds: 300), _maybeAiPlay);
    }
  }

  void _resolveTrick() {
    final winnerId = TrickService.resolveTrick(state.currentTrick);
    final winnerIdx = state.players.indexWhere((p) => p.id == winnerId);
    final isLastTrick = state.trickCount == 7;
    final isAnnouncer = winnerIdx == state.announcerIndex;

    final points = TrickService.trickPoints(
      state.currentTrick,
      winnerId,
      state.currentContract!,
      isAnnouncer,
      isLastTrick,
    );

    for (final entry in points.entries) {
      _pendingScores[entry.key] = (_pendingScores[entry.key] ?? 0) + entry.value;
    }

    // Détecter les voids : tout joueur ayant joué une autre couleur que led est void
    final ledSuit = state.currentTrick.first.card.suit;
    for (final tc in state.currentTrick) {
      if (tc.card.suit != ledSuit) {
        _playerVoids.putIfAbsent(tc.playerId, () => {}).add(ledSuit);
      }
    }

    lastTrickPoints = points;
    lastTrickWinnerId = winnerId;

    state.tricksWonByPlayer[winnerId] =
        (state.tricksWonByPlayer[winnerId] ?? 0) + 1;
    state.lastTrickWinner = winnerIdx;
    state.trickCount++;
    state.currentTrick = [];
    state.leadPlayerIndex = winnerIdx;

    if (state.trickCount >= 8) {
      _applyContractScores();
      _onContractEnd();
    } else {
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 300), _maybeAiPlay);
    }
  }

  void _maybeAiPlay() {
    if (state.phase != GamePhase.trickPlay) return;
    if (state.currentTrick.length >= 4) return; // pli déjà plein, en attente de résolution
    final currentIdx = _currentTurnPlayer();
    if (state.players[currentIdx].isHuman) {
      notifyListeners();
      return;
    }

    final ai = aiServices[currentIdx];
    final card = ai.chooseTrickCard(
      hand: state.players[currentIdx].hand,
      currentTrick: state.currentTrick,
      contract: state.currentContract!,
      trickNumber: state.trickCount,
      announcerId: state.announcerIndex,
      myPlayerId: currentIdx,
      tricksWonByPlayer: Map.from(state.tricksWonByPlayer),
      playerVoids: Map.from(_playerVoids),
      humanPlayerId: _humanIndex(),
    );

    // Capture l'état attendu au moment du délai pour éviter les doubles-jeux
    final expectedTrickLen = state.currentTrick.length;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (state.phase == GamePhase.trickPlay &&
          state.currentTrick.length == expectedTrickLen &&
          _currentTurnPlayer() == currentIdx) {
        _doPlayCard(currentIdx, card);
      }
    });
  }

  int _currentTurnPlayer() {
    return (state.leadPlayerIndex + state.currentTrick.length) % 4;
  }

  int _nextPlayerTurn() => state.currentTrick.length;

  // ─── RÉUSSITE ──────────────────────────────────────────────────────────────

  bool canPlayReussiteCard(CardModel card) {
    if (state.phase != GamePhase.reussitePlay) return false;
    if (_currentReussitePlayer() != _humanIndex()) return false;
    return state.reussiteBoard!.canPlace(card);
  }

  void playReussiteCard(CardModel card) {
    _doPlayReussiteCard(_humanIndex(), card);
  }

  void passReussite() {
    if (_currentReussitePlayer() != _humanIndex()) return;
    _inAceBonusTurn = false;
    _advanceReussitePlayer();
  }

  void _doPlayReussiteCard(int playerIdx, CardModel card) {
    state.players[playerIdx].hand.remove(card);
    state.reussiteBoard!.place(card);

    final isAce = card.isAce;
    notifyListeners();

    if (state.players[playerIdx].hand.isEmpty) {
      state.reussiteFinishOrder.add(playerIdx);
      final pos = state.reussiteFinishOrder.length - 1;
      final isAnnouncer = playerIdx == state.announcerIndex;
      final score = reussiteScore(pos, isAnnouncer);
      state.players[playerIdx].addScore(score);
      _reussiteScores[playerIdx] = (_reussiteScores[playerIdx] ?? 0) + score;

      if (state.reussiteFinishOrder.length == 4) {
        _recordReussiteResult(Map.from(_reussiteScores));
        _onContractEnd();
        return;
      }
    }

    if (isAce && state.players[playerIdx].hand.isNotEmpty) {
      // Tour bonus : le joueur PEUT rejouer mais n'y est pas obligé
      _inAceBonusTurn = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!state.players[playerIdx].isHuman) {
          _aiAceBonusTurn(playerIdx);
        } else {
          notifyListeners(); // humain voit le bouton "Passer"
        }
      });
      return;
    }

    _inAceBonusTurn = false;
    _advanceReussitePlayer();
  }

  void _aiAceBonusTurn(int playerIdx) {
    if (state.phase != GamePhase.reussitePlay) return;
    final ai = aiServices[playerIdx];
    final card = ai.chooseReussiteCard(
      hand: state.players[playerIdx].hand,
      board: state.reussiteBoard!,
    );
    if (card != null) {
      // Facile : 50% de chance d'utiliser le tour bonus
      final shouldPlay = difficulty != AiDifficulty.easy || _rng.nextBool();
      if (shouldPlay) {
        _inAceBonusTurn = false;
        _doPlayReussiteCard(playerIdx, card);
        return;
      }
    }
    _inAceBonusTurn = false;
    _advanceReussitePlayer();
  }

  void _advanceReussitePlayer() {
    int next = (state.reussiteCurrentPlayer + 1) % 4;
    // Skip players who already finished
    int tries = 0;
    while (state.reussiteFinishOrder.contains(next) && tries < 4) {
      next = (next + 1) % 4;
      tries++;
    }
    state.reussiteCurrentPlayer = next;
    notifyListeners();
    _maybeAiPlayReussite();
  }

  void _maybeAiPlayReussite() {
    if (state.phase != GamePhase.reussitePlay) return;
    final idx = _currentReussitePlayer();
    if (state.players[idx].isHuman) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      _aiPlayReussite(idx);
    });
  }

  void _aiPlayReussite(int playerIdx) {
    if (state.phase != GamePhase.reussitePlay) return;
    final ai = aiServices[playerIdx];
    final card = ai.chooseReussiteCard(
      hand: state.players[playerIdx].hand,
      board: state.reussiteBoard!,
    );

    if (card != null) {
      _doPlayReussiteCard(playerIdx, card);
    } else {
      _advanceReussitePlayer();
    }
  }

  int _currentReussitePlayer() => state.reussiteCurrentPlayer;

  // ─── CAPOT + SCORES ────────────────────────────────────────────────────────

  void _applyContractScores() {
    int? capotId;
    for (final entry in state.tricksWonByPlayer.entries) {
      if (entry.value == 8) { capotId = entry.key; break; }
    }

    if (capotId != null) {
      lastCapotPlayerId = capotId;
      _pendingScores[capotId] = -(_pendingScores[capotId] ?? 0);
    } else {
      lastCapotPlayerId = null;
    }

    for (final p in state.players) {
      final pts = _pendingScores[p.id] ?? 0;
      if (pts != 0) p.addScore(pts);
    }

    _recordContractResult(Map.from(_pendingScores), capotId);
    _pendingScores = {};
  }

  void _recordContractResult(Map<int, int> scores, int? capotId) {
    state.history.add(ContractResult(
      announcerIndex: state.announcerIndex,
      announcerName: state.announcer.name,
      contract: state.currentContract!,
      pointsByPlayer: scores,
      capotPlayerId: capotId,
    ));
  }

  void _recordReussiteResult(Map<int, int> scores) {
    state.history.add(ContractResult(
      announcerIndex: state.announcerIndex,
      announcerName: state.announcer.name,
      contract: Contract.reussite,
      pointsByPlayer: scores,
    ));
  }

  // ─── CONTRACT END ──────────────────────────────────────────────────────────

  void _onContractEnd() {
    state.contractIndexInTurn++;
    state.phase = GamePhase.contractEnd;
    notifyListeners();
  }

  void continueAfterContract() {
    if (state.contractIndexInTurn >= 7) {
      _onAnnouncerDone();
    } else {
      _dealAndSelectContract();
    }
  }

  void _onAnnouncerDone() {
    _announcersDone++;
    if (_announcersDone >= 4) {
      state.phase = GamePhase.gameEnd;
      notifyListeners();
      return;
    }
    state.announcerIndex = (state.announcerIndex + 1) % 4;
    _startAnnouncerTurn();
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  int _humanIndex() => state.players.indexWhere((p) => p.isHuman);

  bool get isHumanTurn {
    if (state.phase == GamePhase.trickPlay) {
      return _currentTurnPlayer() == _humanIndex();
    }
    if (state.phase == GamePhase.reussitePlay) {
      return _currentReussitePlayer() == _humanIndex();
    }
    return false;
  }

  Player get humanPlayer => state.players[_humanIndex()];

  List<CardModel> get humanValidCards {
    if (state.phase != GamePhase.trickPlay) return [];
    return TrickService.validCards(
      humanPlayer.hand,
      state.currentTrick,
      state.currentContract!,
      state.trickCount,
    );
  }

  bool get humanCanPassReussite {
    if (state.phase != GamePhase.reussitePlay) return false;
    if (_currentReussitePlayer() != _humanIndex()) return false;
    // Toujours passable pendant un tour bonus As
    if (_inAceBonusTurn) return true;
    // Passable uniquement si aucune carte jouable
    return humanPlayer.hand.every((c) => !state.reussiteBoard!.canPlace(c));
  }
}
