import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:la_rata/main.dart';
import 'package:la_rata/providers/game_provider.dart';

void main() {
  testWidgets('App launches without crash', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameProvider(),
        child: const LaRataApp(),
      ),
    );
    expect(find.text('LA RATA'), findsOneWidget);
  });
}
