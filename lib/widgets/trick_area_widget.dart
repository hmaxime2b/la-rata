import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import 'card_widget.dart';

class TrickAreaWidget extends StatelessWidget {
  final List<TrickCard> trick;
  final List<Player> players;

  const TrickAreaWidget({
    super.key,
    required this.trick,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    // Show cards in positions: top=player2, left=player3, right=player1, bottom=player0
    final positions = {
      2: Alignment.topCenter,
      3: Alignment.centerLeft,
      1: Alignment.centerRight,
      0: Alignment.bottomCenter,
    };

    return SizedBox(
      width: 200,
      height: 160,
      child: Stack(
        children: [
          ...trick.map((tc) {
            final align = positions[tc.playerId] ?? Alignment.center;
            return Align(
              alignment: align,
              child: CardWidget(card: tc.card, width: 46, height: 68),
            );
          }),
        ],
      ),
    );
  }
}
