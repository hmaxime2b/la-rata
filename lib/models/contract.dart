enum Contract { plis, coeurs, dames, roiCoeur, der, reussite, rata }

extension ContractExtension on Contract {
  String get label {
    switch (this) {
      case Contract.plis: return 'Plis';
      case Contract.coeurs: return 'Cœurs';
      case Contract.dames: return 'Dames';
      case Contract.roiCoeur: return 'Roi de Cœur';
      case Contract.der: return 'Der';
      case Contract.reussite: return 'Réussite';
      case Contract.rata: return 'Rata';
    }
  }

  String get description {
    switch (this) {
      case Contract.plis: return 'Chaque pli = +5 pts';
      case Contract.coeurs: return 'Chaque cœur = +5 pts';
      case Contract.dames: return 'Chaque dame = +10 pts';
      case Contract.roiCoeur: return 'Roi de cœur = +40 pts';
      case Contract.der: return 'Dernier pli = +40 pts';
      case Contract.reussite: return '1er: -40 / 4e: +40 pts';
      case Contract.rata: return 'Cumul : plis + cœurs + dames + roi + der';
    }
  }

  bool get isTrickBased => this != Contract.reussite;
}
