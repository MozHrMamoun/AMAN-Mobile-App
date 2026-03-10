import 'package:flutter/material.dart';

import '../landing_page.dart';

class AmanApp extends StatelessWidget {
  const AmanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE9EAEC),
        useMaterial3: true,
      ),
      home: const LandingPage(),
    );
  }
}
