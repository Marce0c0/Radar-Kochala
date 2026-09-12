// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:cochabamba_reporta/main.dart';

void main() {
  testWidgets('Selecciona un rol y permite abrir el mapa ciudadano', (WidgetTester tester) async {
    await tester.pumpWidget(const BachesCochaApp());
    await tester.pumpAndSettle();
    expect(find.text('Cochabamba Reporta'), findsOneWidget);
    expect(find.text('Vecino / Ciudadano'), findsOneWidget);
    expect(find.text('Operador Municipal'), findsOneWidget);
    expect(find.text('Encargado de Campo'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    await tester.tap(find.text('Vecino / Ciudadano'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(find.text('Mapa ciudadano'), findsOneWidget);
    expect(find.text('Añadir reporte en el mapa'), findsOneWidget);
  });
}
