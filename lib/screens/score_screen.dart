import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contract.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../models/player.dart';
import '../services/ad_service.dart';
import '../services/purchase_service.dart';
import 'home_screen.dart';

class ScoreScreen extends StatelessWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gp = context.read<GameProvider>();
    final players = gp.state.players;
    final history = gp.state.history;
    final sorted = List<Player>.from(players)
      ..sort((a, b) => a.totalScore.compareTo(b.totalScore));
    final winner = sorted.first;

    final Map<int, List<ContractResult>> byAnnouncer = {};
    for (final r in history) {
      byAnnouncer.putIfAbsent(r.announcerIndex, () => []).add(r);
    }
    final sortedEntries = byAnnouncer.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Column(
                children: [
                  const Text(
                    'FIN DE PARTIE',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${winner.name} gagne !',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                child: Column(
                  children: [
                    _PlayerHeaderRow(players: players),
                    const SizedBox(height: 6),
                    ...sortedEntries.map((entry) => _AnnouncerSection(
                          announcerIdx: entry.key,
                          results: entry.value,
                          players: players,
                        )),
                    const SizedBox(height: 6),
                    _GrandTotalRow(players: players),
                    const SizedBox(height: 20),
                    _RemoveAdsButton(),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _goHome(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                      child: const Text('REJOUER'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    final ps = context.read<PurchaseService>();
    void navigate() {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    }
    if (ps.adsRemoved) {
      navigate();
    } else {
      AdService.instance.showInterstitial(onComplete: navigate);
    }
  }
}

class _PlayerHeaderRow extends StatelessWidget {
  final List<Player> players;
  const _PlayerHeaderRow({required this.players});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 72),
        ...players.map(
          (p) => Expanded(
            child: Text(
              p.name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncerSection extends StatelessWidget {
  final int announcerIdx;
  final List<ContractResult> results;
  final List<Player> players;

  const _AnnouncerSection({
    required this.announcerIdx,
    required this.results,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final announcerName = results.isNotEmpty ? results.first.announcerName : '?';
    final announcerPlayerId = players[announcerIdx].id;

    final Map<int, int> subtotals = {for (final p in players) p.id: 0};
    for (final r in results) {
      for (final e in r.pointsByPlayer.entries) {
        subtotals[e.key] = (subtotals[e.key] ?? 0) + e.value;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin, color: Colors.amber, size: 14),
                const SizedBox(width: 5),
                Text(
                  'Annonceur : $announcerName',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          ...results.map(
            (r) => _ContractRow(
              result: r,
              players: players,
              announcerPlayerId: announcerPlayerId,
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          _SubtotalRow(subtotals: subtotals, players: players),
        ],
      ),
    );
  }
}

class _ContractRow extends StatelessWidget {
  final ContractResult result;
  final List<Player> players;
  final int announcerPlayerId;

  const _ContractRow({
    required this.result,
    required this.players,
    required this.announcerPlayerId,
  });

  String _shortLabel(Contract c) {
    switch (c) {
      case Contract.plis: return 'Plis';
      case Contract.coeurs: return 'Cœurs';
      case Contract.dames: return 'Dames';
      case Contract.roiCoeur: return 'Roi ♥';
      case Contract.der: return 'Der';
      case Contract.reussite: return 'Réussite';
      case Contract.rata: return 'Rata';
    }
  }

  String _icon(Contract c) {
    switch (c) {
      case Contract.plis: return '♠';
      case Contract.coeurs: return '♥';
      case Contract.dames: return '♛';
      case Contract.roiCoeur: return '♚';
      case Contract.der: return '⚑';
      case Contract.reussite: return '✦';
      case Contract.rata: return '★';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Row(
              children: [
                Text(_icon(result.contract),
                    style: TextStyle(
                        fontSize: 13,
                        color: result.contract == Contract.coeurs ||
                                result.contract == Contract.roiCoeur
                            ? Colors.redAccent
                            : Colors.white54)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _shortLabel(result.contract),
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ...players.map((p) {
            final pts = result.pointsByPlayer[p.id] ?? 0;
            return Expanded(
              child: _ScoreCell(
                pts: pts,
                isCapot: result.capotPlayerId == p.id,
                isAnnouncer: p.id == announcerPlayerId,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SubtotalRow extends StatelessWidget {
  final Map<int, int> subtotals;
  final List<Player> players;
  const _SubtotalRow({required this.subtotals, required this.players});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: [
          const SizedBox(
            width: 72,
            child: Text(
              'Total',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ),
          ...players.map((p) {
            final pts = subtotals[p.id] ?? 0;
            return Expanded(
              child: _ScoreCell(pts: pts, isBold: true),
            );
          }),
        ],
      ),
    );
  }
}

class _GrandTotalRow extends StatelessWidget {
  final List<Player> players;
  const _GrandTotalRow({required this.players});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 72,
            child: Text(
              'TOTAL',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          ...players.map((p) => Expanded(
                child: _ScoreCell(pts: p.totalScore, isBold: true, isGrand: true),
              )),
        ],
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  final int pts;
  final bool isCapot;
  final bool isAnnouncer;
  final bool isBold;
  final bool isGrand;

  const _ScoreCell({
    required this.pts,
    this.isCapot = false,
    this.isAnnouncer = false,
    this.isBold = false,
    this.isGrand = false,
  });

  @override
  Widget build(BuildContext context) {
    if (pts == 0 && !isBold) {
      return const Center(
        child: Text('—',
            style: TextStyle(color: Colors.white24, fontSize: 12)),
      );
    }

    Color color;
    if (isCapot) {
      color = Colors.purple[200]!;
    } else if (pts > 0) {
      color = isGrand ? Colors.greenAccent : Colors.green[300]!;
    } else if (pts < 0) {
      color = isGrand ? Colors.redAccent : Colors.red[300]!;
    } else {
      color = Colors.white38;
    }

    final prefix = pts > 0 ? '+' : '';
    final fontSize = isGrand ? 13.0 : 12.0;

    Widget text = Text(
      '$prefix$pts',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: (isBold || isAnnouncer) ? FontWeight.bold : FontWeight.normal,
      ),
    );

    if (isCapot) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: text,
        ),
      );
    }

    if (isAnnouncer && pts != 0) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: text,
        ),
      );
    }

    return Center(child: text);
  }
}

class _RemoveAdsButton extends StatelessWidget {
  const _RemoveAdsButton();

  @override
  Widget build(BuildContext context) {
    final ps = context.watch<PurchaseService>();
    if (ps.adsRemoved) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: ps.loading ? null : () => ps.purchase(),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        side: const BorderSide(color: Colors.white30),
        foregroundColor: Colors.white70,
      ),
      icon: ps.loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            )
          : const Icon(Icons.block, size: 16),
      label: Text(
        ps.loading ? 'Traitement...' : 'Supprimer les pubs — ${ps.priceLabel}',
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}
