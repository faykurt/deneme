import 'package:flutter_test/flutter_test.dart';

import 'package:aklimda/main.dart';

void main() {
  testWidgets('Ana sayfa açılır ve uygulama adını gösterir', (tester) async {
    await tester.pumpWidget(const AklimdaApp());
    expect(find.text('Aklımda'), findsOneWidget);
  });
}
