import 'dart:math';
import '../models/card_model.dart';

class DeckService {
  static List<CardModel> buildDeck() {
    final deck = <CardModel>[];
    for (final suit in Suit.values) {
      for (final value in CardValue.values) {
        deck.add(CardModel(suit, value));
      }
    }
    return deck;
  }

  static List<CardModel> shuffle(List<CardModel> deck) {
    final d = List<CardModel>.from(deck);
    d.shuffle(Random());
    return d;
  }

  // Returns 4 hands of 8 cards
  static List<List<CardModel>> deal(List<CardModel> deck) {
    assert(deck.length == 32);
    return List.generate(4, (i) => deck.sublist(i * 8, i * 8 + 8));
  }
}
