import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/smithmk_theme.dart';
import 'widgets/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
