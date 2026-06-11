enum Suit { hearts, diamonds, clubs, spades }

enum CardValue { seven, eight, nine, ten, jack, queen, king, ace }

class CardModel {
  final Suit suit;
  final CardValue value;

  const CardModel(this.suit, this.value);

  int get rank => value.index;

  bool get isHeart => suit == Suit.hearts;
  bool get isQueen => value == CardValue.queen;
  bool get isKingOfHearts => suit == Suit.hearts && value == CardValue.king;
  bool get isJack => value == CardValue.jack;
  bool get isAce => value == CardValue.ace;

  String get suitSymbol {
    switch (suit) {
      case Suit.hearts: return '♥';
      case Suit.diamonds: return '♦';
      case Suit.clubs: return '♣';
      case Suit.spades: return '♠';
    }
  }

  String get valueLabel {
    switch (value) {
      case CardValue.seven: return '7';
      case CardValue.eight: return '8';
      case CardValue.nine: return '9';
      case CardValue.ten: return '10';
      case CardValue.jack: return 'V';
      case CardValue.queen: return 'D';
      case CardValue.king: return 'R';
      case CardValue.ace: return 'A';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CardModel && other.suit == suit && other.value == value;

  @override
  int get hashCode => suit.index * 10 + value.index;

  @override
  String toString() => '$valueLabel$suitSymbol';
}
