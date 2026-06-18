import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../models/contract.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';
import '../widgets/card_widget.dart';
import '../widgets/trick_area_widget.dart';
import '../widgets/reussite_board_widget.dart';
import 'contract_select_screen.dart';
import 'score_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  CardModel? _selectedCard;
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gp, _) {
        final phase = gp.state.phase;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_navigating && phase == GamePhase.contractSelection) {
            _navigating = true;
            Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => const ContractSelectScreen()))
                .then((_) => _navigating = false);
          } else if (!_navigating && phase == GamePhase.gameEnd) {
            _navigating = true;
            Navigator.of(context)
                .pushReplacement(
                    MaterialPageRoute(builder: (_) => const ScoreScreen()))
                .then((_) => _navigating = false);
          }
        });

        final adsRemoved = context.watch<PurchaseService>().adsRemoved;
        return Scaffold(
          backgroundColor: const Color(0xFF1B5E20),
          body: Column(
            children: [
              Expanded(child: SafeArea(child: _buildBody(context, gp))),
              if (!adsRemoved) const _BannerAdWidget(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, GameProvider gp) {
    switch (gp.state.phase) {
      case GamePhase.initialDraw:
        return _buildInitialDraw(context, gp);
      case GamePhase.contractSelection:
        return _buildWaiting('Choix des contrats...');
      case GamePhase.trickPlay:
        return _buildTrickPlay(context, gp);
      case GamePhase.reussitePlay:
        return _buildReussitePlay(context, gp);
      case GamePhase.contractEnd:
        return _buildContractEnd(context, gp);
      case GamePhase.gameEnd:
        return _buildWaiting('Fin de partie...');
    }
  }

  // ─── INITIAL DRAW ──────────────────────────────────────────────────────────

  Widget _buildInitialDraw(BuildContext context, GameProvider gp) {
    final draw = gp.state.initialDraw;
    final announcer = gp.state.announcer;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _sectionLabel('TIRAGE INITIAL'),
        const SizedBox(height: 8),
        Text(
          '${announcer.name} commence en tant qu\'annonceur',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final player = gp.state.players[i];
            final card = draw[i];
            final isAnnouncer = i == gp.state.announcerIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAnnouncer
                          ? Colors.amber
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      player.name,
                      style: TextStyle(
                        color: isAnnouncer ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (card != null) CardWidget(card: card),
                  if (isAnnouncer)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('★ Annonceur',
                          style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 48),
        _primaryButton('COMMENCER', gp.confirmInitialDraw),
      ],
    );
  }

  // ─── TRICK PLAY ────────────────────────────────────────────────────────────

  Widget _buildTrickPlay(BuildContext context, GameProvider gp) {
    final state = gp.state;
    final human = gp.humanPlayer;
    final validCards = gp.humanValidCards;
    final isHumanTurn = gp.isHumanTurn;
    final currentTurnPlayer =
        (state.leadPlayerIndex + state.currentTrick.length) % 4;

    return Column(
      children: [
        _TopBar(gp: gp),
        const SizedBox(height: 6),

        // Opponents row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OpponentSlot(
                player: state.players[3],
                isAnnouncer: state.announcerIndex == 3,
                isTurn: currentTurnPlayer == 3,
                alignment: Alignment.centerLeft,
              ),
              _OpponentSlot(
                player: state.players[2],
                isAnnouncer: state.announcerIndex == 2,
                isTurn: currentTurnPlayer == 2,
                alignment: Alignment.topCenter,
              ),
              _OpponentSlot(
                player: state.players[1],
                isAnnouncer: state.announcerIndex == 1,
                isTurn: currentTurnPlayer == 1,
                alignment: Alignment.centerRight,
              ),
            ],
          ),
        ),

        const Spacer(),

        // Contract badge + trick counter
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _badge(state.currentContract?.label ?? ''),
            const SizedBox(width: 8),
            _badge('Pli ${state.trickCount + 1} / 8',
                color: Colors.white24),
          ],
        ),
        const SizedBox(height: 12),

        // Trick area
        TrickAreaWidget(
          trick: state.currentTrick,
          players: state.players,
        ),

        const Spacer(),

        // Turn indicator
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isHumanTurn
              ? Container(
                  key: const ValueKey('your-turn'),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'À ton tour — Tape une carte pour la sélectionner, retape pour jouer',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                )
              : Text(
                  key: const ValueKey('waiting'),
                  '${state.players[currentTurnPlayer].name} joue...',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
        ),

        const SizedBox(height: 10),

        // Human hand
        _FanHand(
          hand: human.hand,
          validCards: validCards,
          selectedCard: _selectedCard,
          onCardTap: (card) {
            if (!isHumanTurn) return;
            if (_selectedCard == card) {
              gp.playCard(card);
              setState(() => _selectedCard = null);
            } else {
              setState(() => _selectedCard = card);
            }
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ─── RÉUSSITE ──────────────────────────────────────────────────────────────

  Widget _buildReussitePlay(BuildContext context, GameProvider gp) {
    final state = gp.state;
    final human = gp.humanPlayer;
    final board = state.reussiteBoard!;
    final isHumanTurn = gp.isHumanTurn;
    final playableOnBoard = human.hand.where((c) => board.canPlace(c)).toList();

    return Column(
      children: [
        _TopBar(gp: gp),
        const SizedBox(height: 8),
        _sectionLabel('RÉUSSITE'),
        const SizedBox(height: 6),

        // Finish order chips
        if (state.reussiteFinishOrder.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: state.reussiteFinishOrder.asMap().entries.map((e) {
              final p = state.players[e.value];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${e.key + 1}. ${p.name}',
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),

        Expanded(
          child: SingleChildScrollView(
            child: ReussiteBoardWidget(
              board: board,
              playableCards: isHumanTurn ? playableOnBoard : [],
              onCardTap: (card) {
                if (isHumanTurn && board.canPlace(card)) {
                  gp.playReussiteCard(card);
                }
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        if (isHumanTurn)
          Column(
            children: [
              if (gp.inAceBonusTurn)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.6)),
                  ),
                  child: const Text(
                    '🃏 Tour bonus As — Rejoue ou passe',
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                )
              else
                const Text('À ton tour',
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              if (gp.humanCanPassReussite)
                TextButton(
                  onPressed: gp.passReussite,
                  child: const Text('Passer',
                      style: TextStyle(color: Colors.white54)),
                ),
            ],
          )
        else
          Text(
            '${state.players[state.reussiteCurrentPlayer].name} joue...',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),

        const SizedBox(height: 8),
        _FanHand(
          hand: human.hand,
          validCards: isHumanTurn ? playableOnBoard : [],
          selectedCard: null,
          onCardTap: (card) {
            if (isHumanTurn && board.canPlace(card)) {
              gp.playReussiteCard(card);
            }
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ─── CONTRACT END ──────────────────────────────────────────────────────────

  Widget _buildContractEnd(BuildContext context, GameProvider gp) {
    final state = gp.state;
    final contractIdx = state.contractIndexInTurn - 1;
    final contract = contractIdx >= 0 && contractIdx < state.currentContractOrder.length
        ? state.currentContractOrder[contractIdx]
        : null;

    final sorted = List.from(state.players)
      ..sort((a, b) => a.totalScore.compareTo(b.totalScore));

    final capotId = gp.lastCapotPlayerId;
    final capotPlayer = capotId != null
        ? state.players.firstWhere((p) => p.id == capotId)
        : null;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _sectionLabel(contract?.label.toUpperCase() ?? 'CONTRAT TERMINÉ'),
          const SizedBox(height: 4),
          Text(
            'Contrat ${state.contractIndexInTurn} / 7 — Annonceur : ${state.announcer.name}',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          if (capotPlayer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.7)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎯 ', style: TextStyle(fontSize: 18)),
                  Text(
                    'CAPOT — ${capotPlayer.name} a tous les plis !',
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          ...sorted.asMap().entries.map((e) {
            final rank = e.key + 1;
            final p = e.value;
            final isHuman = p.isHuman;
            final isAnnouncer = state.announcerIndex ==
                state.players.indexWhere((x) => x.id == p.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isHuman
                    ? Colors.amber.withValues(alpha: 0.15)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHuman
                      ? Colors.amber.withValues(alpha: 0.5)
                      : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Text('$rank.',
                      style: TextStyle(
                          color: isHuman ? Colors.amber : Colors.white38,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  if (isAnnouncer)
                    const Text('★ ',
                        style: TextStyle(
                            color: Colors.amber, fontSize: 12)),
                  Text(
                    p.name,
                    style: TextStyle(
                      color: isHuman ? Colors.amber : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${p.totalScore} pts',
                    style: TextStyle(
                      color: isHuman ? Colors.amber : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Spacer(),
          _primaryButton(
            state.contractIndexInTurn >= 7
                ? (state.announcerIndex >= 3
                    ? 'VOIR LES RÉSULTATS'
                    : 'PROCHAIN ANNONCEUR')
                : 'CONTRAT SUIVANT',
            gp.continueAfterContract,
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(String msg) {
    return Center(
      child: Text(msg, style: const TextStyle(color: Colors.white70)),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.amber,
        fontSize: 12,
        letterSpacing: 4,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _badge(String text, {Color color = Colors.white24}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
      child: Text(label),
    );
  }
}

// ─── BANNER AD ───────────────────────────────────────────────────────────────

class _BannerAdWidget extends StatefulWidget {
  const _BannerAdWidget();

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
        onAdFailedToLoad: (ad, _) { ad.dispose(); _ad = null; },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox(height: 50);
    return SizedBox(
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}


// ─── TOP BAR ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final GameProvider gp;
  const _TopBar({required this.gp});

  @override
  Widget build(BuildContext context) {
    final state = gp.state;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        border: const Border(
            bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.6), width: 1),
            ),
            child: Text(
              '★ ${state.announcer.name}',
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          ...state.players.map((p) => Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(p.name,
                    style: TextStyle(
                        color: p.isHuman ? Colors.amber : Colors.white54,
                        fontSize: 10)),
                Text('${p.totalScore}',
                    style: TextStyle(
                        color: p.isHuman ? Colors.amber : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─── OPPONENT SLOT ────────────────────────────────────────────────────────────

class _OpponentSlot extends StatelessWidget {
  final dynamic player;
  final bool isAnnouncer;
  final bool isTurn;
  final Alignment alignment;

  const _OpponentSlot({
    required this.player,
    required this.isAnnouncer,
    required this.isTurn,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final count = (player.hand as List).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Name badge
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isTurn
                ? Colors.amber.withValues(alpha: 0.9)
                : Colors.black26,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAnnouncer)
                const Text('★ ',
                    style: TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              Text(
                player.name,
                style: TextStyle(
                  color: isTurn ? Colors.black : Colors.white70,
                  fontWeight:
                      isTurn ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Mini card fan
        _MiniFan(count: count),
      ],
    );
  }
}

class _MiniFan extends StatelessWidget {
  final int count;
  const _MiniFan({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox(height: 38, width: 60);
    const cardW = 24.0;
    const cardH = 36.0;
    const step = 8.0;
    final totalW = cardW + (count - 1) * step;
    return SizedBox(
      width: totalW.clamp(cardW, 80),
      height: cardH,
      child: Stack(
        children: List.generate(count, (i) {
          return Positioned(
            left: i * step,
            child: Container(
              width: cardW,
              height: cardH,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 1))
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── FAN HAND (human) ────────────────────────────────────────────────────────

class _FanHand extends StatelessWidget {
  final List<CardModel> hand;
  final List<CardModel> validCards;
  final CardModel? selectedCard;
  final void Function(CardModel) onCardTap;

  const _FanHand({
    required this.hand,
    required this.validCards,
    required this.selectedCard,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    if (hand.isEmpty) return const SizedBox(height: 102);

    // Tri ♥ ♠ ♦ ♣ (alternance rouge/noir) puis par valeur
    const suitOrder = {Suit.hearts: 0, Suit.spades: 1, Suit.diamonds: 2, Suit.clubs: 3};
    final sorted = List<CardModel>.from(hand)
      ..sort((a, b) {
        final sc = (suitOrder[a.suit] ?? 0).compareTo(suitOrder[b.suit] ?? 0);
        return sc != 0 ? sc : a.rank.compareTo(b.rank);
      });

    return LayoutBuilder(builder: (context, constraints) {
      const cardW = 58.0;
      const cardH = 86.0;
      const liftH = 16.0;
      final count = sorted.length;

      final availableW = constraints.maxWidth - 24;
      final step = count > 1
          ? ((availableW - cardW) / (count - 1)).clamp(16.0, cardW * 0.8)
          : 0.0;
      final totalW = cardW + (count - 1) * step;

      return SizedBox(
        height: cardH + liftH + 4,
        child: Center(
          child: SizedBox(
            width: totalW,
            height: cardH + liftH + 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: sorted.asMap().entries.map((e) {
                final i = e.key;
                final card = e.value;
                final isPlayable = validCards.contains(card);
                final isSelected = selectedCard == card;
                return Positioned(
                  left: i * step,
                  bottom: isSelected ? liftH : 0,
                  child: CardWidget(
                    card: card,
                    isPlayable: isPlayable,
                    width: cardW,
                    height: cardH,
                    onTap: () => onCardTap(card),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    });
  }
}
