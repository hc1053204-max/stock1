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
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF5F7FA),
        ),
      ),
      home: HomeScreen(api: api),
    );
  }
}
