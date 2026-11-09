import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/stock_api_client.dart';

void main() {
  final api = StockApiClient(
    // Android Emulator：10.0.2.2；iOS Simulator：127.0.0.1；實機：改成電腦區網 IP。
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
  );
  runApp(StockAnalysisApp(api: api));
}

class StockAnalysisApp extends StatelessWidget {
  const StockAnalysisApp({super.key, required this.api});

  final StockApiClient api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 股票分析',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B87)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F9FC),
          foregroundColor: Color(0xFF102A43),
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0xFFE6EDF3)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Color(0xFF102A43),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(13)),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF5F7FA),
        ),
      ),
      home: HomeScreen(api: api),
    );
  }
}
