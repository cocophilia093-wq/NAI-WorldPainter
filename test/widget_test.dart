import 'package:flutter_test/flutter_test.dart';
import 'package:nai_huishi/presentation/app.dart';

void main() {
  testWidgets('app builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NaiHuishiApp());
    expect(find.text('nai 绘世'), findsOneWidget);
  });
}
