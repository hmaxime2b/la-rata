import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/ai/ai_service.dart';
import '../providers/game_provider.dart';
import '../services/purchase_service.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AiDifficulty _selected = AiDifficulty.medium;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'LA RATA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Jeu de cartes • 1 vs 3 IA',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 60),
              const Text(
                'DIFFICULTÉ',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              _DifficultySelector(
                selected: _selected,
                onChanged: (d) => setState(() => _selected = d),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48, vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                child: const Text('JOUER'),
              ),
              const SizedBox(height: 16),
              _RemoveAdsHomeButton(),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame() {
    context.read<GameProvider>().startGame(_selected);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }
}

class _DifficultySelector extends StatelessWidget {
  final AiDifficulty selected;
  final ValueChanged<AiDifficulty> onChanged;

  const _DifficultySelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: AiDifficulty.values.map((d) {
        final isSelected = d == selected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => onChanged(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.amber : Colors.white12,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? Colors.amber : Colors.white30,
                ),
              ),
              child: Text(
                _label(d),
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _label(AiDifficulty d) {
    switch (d) {
      case AiDifficulty.easy: return 'Facile';
      case AiDifficulty.medium: return 'Moyen';
      case AiDifficulty.hard: return 'Difficile';
    }
  }
}

class _RemoveAdsHomeButton extends StatelessWidget {
  const _RemoveAdsHomeButton();

  @override
  Widget build(BuildContext context) {
    final ps = context.watch<PurchaseService>();
    if (ps.adsRemoved) {
      return const Text(
        'Sans publicité',
        style: TextStyle(color: Colors.white38, fontSize: 12),
      );
    }
    return TextButton.icon(
      onPressed: ps.loading ? null : () => ps.purchase(),
      icon: const Icon(Icons.block, size: 14, color: Colors.white38),
      label: Text(
        'Supprimer les pubs — ${ps.priceLabel}',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}
