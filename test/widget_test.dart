// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:cochabamba_reporta/main.dart';

void main() {
  testWidgets('Muestra el mapa ciudadano', (WidgetTester tester) async {
    // Solución correcta
await tester.pumpWidget(const BachesCochaApp());
    await tester.pump();
    expect(find.text('Mapa ciudadano'), findsOneWidget);
    expect(find.text('Añadir reporte en el mapa'), findsOneWidget);
  });
}
