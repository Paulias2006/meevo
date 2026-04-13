import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:meevo/src/meevo_api.dart';
import 'package:meevo/src/meevo_app.dart';
import 'package:meevo/src/meevo_state.dart';

void main() {
  testWidgets('Meevo app starts', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MeevoState(MeevoApi())..isBootstrapping = false,
        child: const MeevoApp(),
      ),
    );

    await tester.pump();

    expect(find.text('Meevo'), findsOneWidget);
  });
}
