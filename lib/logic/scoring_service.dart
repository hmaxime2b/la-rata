// Réussite finish order → points
const reussitePoints = [-40, -20, 20, 40];

int reussiteScore(int finishPosition, bool isAnnouncer) {
  final base = reussitePoints[finishPosition];
  return isAnnouncer ? base * 2 : base;
}
