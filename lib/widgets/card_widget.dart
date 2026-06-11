import 'package:flutter/material.dart';
import '../models/card_model.dart';

class CardWidget extends StatelessWidget {
  final CardModel card;
  final bool isPlayable;
  final bool isSelected;
  final bool faceDown;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const CardWidget({
    super.key,
    required this.card,
    this.isPlayable = false,
    this.isSelected = false,
    this.faceDown = false,
    this.onTap,
    this.width = 58,
    this.height = 86,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlayable ? onTap : null,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: faceDown ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPlayable ? Colors.amber : Colors.black26,
            width: isPlayable ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isPlayable ? 0.5 : 0.25),
              blurRadius: isPlayable ? 8 : 4,
              offset: const Offset(1, 3),
            ),
          ],
        ),
        child: faceDown ? _buildBack() : _buildFace(),
      ),
    );
  }

  Widget _buildBack() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 1),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const Center(
              child: Text('🂠',
                  style: TextStyle(fontSize: 22, color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFace() {
    final isRed = card.suit == Suit.hearts || card.suit == Suit.diamonds;
    final color = isRed ? const Color(0xFFC62828) : const Color(0xFF212121);
    final isSmall = width < 40;

    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: isSmall ? _buildFaceSmall(color) : _buildFaceFull(color),
    );
  }

  // Compact layout for small cards (Réussite board)
  Widget _buildFaceSmall(Color color) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.valueLabel,
              style: TextStyle(
                  color: color,
                  fontSize: width * 0.26,
                  fontWeight: FontWeight.bold,
                  height: 1)),
          Text(card.suitSymbol,
              style: TextStyle(
                  color: color, fontSize: width * 0.24, height: 1)),
          Expanded(
            child: Center(
              child: Text(card.suitSymbol,
                  style: TextStyle(
                      color: color, fontSize: width * 0.4, height: 1)),
            ),
          ),
        ],
      ),
    );
  }

  // Full layout for normal cards
  Widget _buildFaceFull(Color color) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 2,
            child: _Corner(
                valueLabel: card.valueLabel,
                suitSymbol: card.suitSymbol,
                color: color,
                size: width * 0.22),
          ),
          Positioned(
            bottom: 0,
            right: 2,
            child: Transform.rotate(
              angle: 3.14159,
              child: _Corner(
                  valueLabel: card.valueLabel,
                  suitSymbol: card.suitSymbol,
                  color: color,
                  size: width * 0.22),
            ),
          ),
          Center(
            child: Text(
              card.suitSymbol,
              style: TextStyle(color: color, fontSize: width * 0.45, height: 1),
            ),
          ),
        ],
      ),
    );
  }

}

class _Corner extends StatelessWidget {
  final String valueLabel;
  final String suitSymbol;
  final Color color;
  final double size;

  const _Corner({
    required this.valueLabel,
    required this.suitSymbol,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(valueLabel,
            style: TextStyle(
                color: color,
                fontSize: size,
                fontWeight: FontWeight.bold,
                height: 1.1)),
        Text(suitSymbol,
            style: TextStyle(color: color, fontSize: size * 0.85, height: 1)),
      ],
    );
  }
}
