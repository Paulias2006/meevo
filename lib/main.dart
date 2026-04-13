import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'src/meevo_api.dart';
import 'src/meevo_app.dart';
import 'src/meevo_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  runApp(
    ChangeNotifierProvider(
      create: (_) => MeevoState(MeevoApi())..bootstrap(),
      child: const MeevoApp(),
    ),
  );
}
