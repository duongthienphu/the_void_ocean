import 'package:flutter_test/flutter_test.dart';
import 'package:ocean/main.dart';

void main() {
  testWidgets('Ocean app shows the login experience', (tester) async {
    await tester.pumpWidget(const VoidOceanApp());

    expect(find.text('Đại dương\nẩn danh'), findsOneWidget);
    expect(find.text('Vào đại dương'), findsOneWidget);
    expect(find.text('Text và audio'), findsOneWidget);
  });
}
