import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../models/game_state.dart';
import 'card_widget.dart';

class ReussiteBoardWidget extends StatelessWidget {
  final ReussiteBoard board;
  final List<CardModel> playableCards;
  final void Function(CardModel) onCardTap;

  const ReussiteBoardWidget({
    super.key,
    required this.board,
    required this.playableCards,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: Suit.values.map((suit) => _SuitRow(
        suit: suit,
        board: board,
        playableCards: playableCards,
        onCardTap: onCardTap,
      )).toList(),
    );
  }
}

class _SuitRow extends StatelessWidget {
  final Suit suit;
  final ReussiteBoard board;
  final List<CardModel> playableCards;
  final void Function(CardModel) onCardTap;

  const _SuitRow({
    required this.suit,
    required this.board,
    required this.playableCards,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build the full row: 7 8 9 10 [J] Q K A
    final allValues = CardValue.values; // 7→A

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: allValues.map((value) {
          final card = CardModel(suit, value);
          final isJack = value == CardValue.jack;
          final isPlaced = _isPlaced(card);
          final isPlayable = playableCards.contains(card);

          if (!isPlaced && !isJack) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: SizedBox(
                width: 34,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isPlayable ? Colors.amber : Colors.white12,
                      width: isPlayable ? 2 : 1,
                    ),
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: isPlaced || isJack
                ? CardWidget(
                    card: card,
                    width: 34,
                    height: 50,
                    isPlayable: isPlayable,
                    onTap: () => onCardTap(card),
                  )
                : const SizedBox(width: 34, height: 50),
          );
        }).toList(),
      ),
    );
  }

  bool _isPlaced(CardModel card) {
    if (card.isJack) return board.jackPlaced[suit] ?? false;
    if (card.value.index > CardValue.jack.index) {
      return board.above[suit]!.contains(card);
    }
    return board.below[suit]!.contains(card);
  }
}
