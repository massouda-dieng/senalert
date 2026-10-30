import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/push.dart';
import 'state/apparence.dart';
import 'state/configuration.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await Push.instance.initialiser();
  final session = Session();
  final configuration = Configuration();
  final apparence = Apparence();
  await apparence.charger();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: configuration),
      ChangeNotifierProvider.value(value: apparence),
    ],
    child: SenAlertApp(session: session),
  ));
  configuration.charger();
  session.restaurer();
}
