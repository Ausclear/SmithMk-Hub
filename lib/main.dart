import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'theme/smithmk_theme.dart';
import 'widgets/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load Noto Color Emoji as a fallback font so emojis render on web
  final emojiFont = await rootBundle.load('assets/fonts/NotoColorEmoji.ttf');
  final fontLoader = FontLoader('NotoColorEmoji')..addFont(Future.value(emojiFont));
  await fontLoader.load();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SmithMkColors.cardSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SmithMkApp());
}

class SmithMkApp extends StatelessWidget {
  const SmithMkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmithMk Hub',
      debugShowCheckedModeBanner: false,
      theme: SmithMkTheme.darkTheme,
      home: const AppShell(),
    );
  }
}
