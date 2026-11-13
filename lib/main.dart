import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/jspeak_app.dart';
import 'core/widgets/active5_web_viewport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  const app = ProviderScope(child: JspeakApp());

  runApp(
    Active5WebViewport.enabled ? const Active5WebViewport(child: app) : app,
  );
}
