import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean/main.dart'; // Đảm bảo đúng tên package của bạn

void main() {
  testWidgets('Ocean app smoke test', (WidgetTester tester) async {
    // 1. Build app đại dương thay vì MyApp
    await tester.pumpWidget(const VoidOceanApp());

    // 2. Kiểm tra xem dòng chữ mặc định lúc chưa có chai nào có hiển thị không
    expect(find.text('The ocean is calm. No bottles floating yet.'), findsOneWidget);
    
    // 3. Kiểm tra xem có cái nút bấm Vent không
    expect(find.text('Vent to the Void'), findsOneWidget);
  });
}