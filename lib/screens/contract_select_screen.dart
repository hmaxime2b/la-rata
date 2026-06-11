import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/card_model.dart';
import '../models/contract.dart';
import '../providers/game_provider.dart';
import '../widgets/card_widget.dart';

class ContractSelectScreen extends StatelessWidget {
  const ContractSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gp, _) {
        final remaining = gp.state.remainingContracts;
        final hand = gp.humanPlayer.hand;
        final contractIndex = gp.state.contractIndexInTurn + 1;

        return Scaffold(
          backgroundColor: const Color(0xFF1B5E20),
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  color: Colors.black26,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHOIX DU CONTRAT',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              letterSpacing: 3,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Contrat $contractIndex / 7',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${remaining.length} contrat${remaining.length > 1 ? 's' : ''} restant${remaining.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Ta main
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'TA MAIN',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _HandDisplay(hand: hand),
                const SizedBox(height: 20),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'QUEL CONTRAT ?',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Contrats disponibles
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: remaining
                        .map((c) => _ContractCard(
                              contract: c,
                              onTap: () {
                                gp.setContractNow(c);
                                Navigator.of(context).pop();
                              },
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HandDisplay extends StatelessWidget {
  final List<CardModel> hand;

  const _HandDisplay({required this.hand});

  @override
  Widget build(BuildContext context) {
    if (hand.isEmpty) return const SizedBox(height: 70);

    const suitOrder = {Suit.hearts: 0, Suit.spades: 1, Suit.diamonds: 2, Suit.clubs: 3};
    final sorted = List<CardModel>.from(hand)
      ..sort((a, b) {
        final sc = (suitOrder[a.suit] ?? 0).compareTo(suitOrder[b.suit] ?? 0);
        return sc != 0 ? sc : a.rank.compareTo(b.rank);
      });

    return LayoutBuilder(builder: (context, constraints) {
      const cardW = 48.0;
      const cardH = 70.0;
      final count = sorted.length;
      final availableW = constraints.maxWidth - 32;
      final step = count > 1
          ? ((availableW - cardW) / (count - 1)).clamp(14.0, cardW * 0.75)
          : 0.0;
      final totalW = cardW + (count - 1) * step;

      return SizedBox(
        height: cardH,
        child: Center(
          child: SizedBox(
            width: totalW,
            height: cardH,
            child: Stack(
              children: sorted.asMap().entries.map((e) {
                return Positioned(
                  left: e.key * step,
                  child: CardWidget(
                    card: e.value,
                    width: cardW,
                    height: cardH,
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

class _ContractCard extends StatelessWidget {
  final Contract contract;
  final VoidCallback onTap;

  const _ContractCard({required this.contract, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            // Icône contrat
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _contractColor(contract).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _contractIcon(contract),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contract.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contract.description,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  Color _contractColor(Contract c) {
    switch (c) {
      case Contract.coeurs: return Colors.red;
      case Contract.dames: return Colors.purple;
      case Contract.roiCoeur: return Colors.redAccent;
      case Contract.plis: return Colors.blue;
      case Contract.der: return Colors.orange;
      case Contract.reussite: return Colors.green;
      case Contract.rata: return Colors.amber;
    }
  }

  String _contractIcon(Contract c) {
    switch (c) {
      case Contract.coeurs: return '♥';
      case Contract.dames: return '♛';
      case Contract.roiCoeur: return '♚';
      case Contract.plis: return '🂡';
      case Contract.der: return '⚑';
      case Contract.reussite: return '✦';
      case Contract.rata: return '🐀';
    }
  }
}
