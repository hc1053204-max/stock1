import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/stock_models.dart';

class StockApiException implements Exception {
  StockApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StockApiClient {
  StockApiClient({
    http.Client? client,
    // Android Emulator 連到開發主機要使用 10.0.2.2；實機請改成電腦區網 IP。
    this.baseUrl = 'http://10.0.2.2:8000',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<StockAnalysis> fetchAnalysis({
    required String symbol,
    required String market,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/stocks/$symbol/analysis').replace(
      queryParameters: {
        'market': market,
        'period': '1y',
        'interval': '1d',
      },
    );

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StockApiException(
          body['detail']?.toString() ?? '股票 API 回應錯誤（${response.statusCode}）',
        );
      }
      return StockAnalysis.fromJson(body);
    } on StockApiException {
      rethrow;
    } on FormatException {
      throw StockApiException('後端回傳格式不是有效的 JSON');
    } catch (error) {
      throw StockApiException('無法連線到股票後端：$error');
    }
  }

  Future<List<StockHistoryItem>> fetchHistory({
    required String symbol,
    required String market,
    String period = '3mo',
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/stocks/$symbol/history').replace(
      queryParameters: {
        'market': market,
        'period': period,
        'interval': '1d',
      },
    );

    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StockApiException(
          body['detail']?.toString() ?? '歷史資料 API 回應錯誤（${response.statusCode}）',
        );
      }

      final rows = body['data'] as List<dynamic>? ?? const [];
      return rows
          .map((row) => StockHistoryItem.fromJson(row as Map<String, dynamic>))
          .toList();
    } on StockApiException {
      rethrow;
    } on FormatException {
      throw StockApiException('後端回傳的歷史資料格式不是有效的 JSON');
    } catch (error) {
      throw StockApiException('無法取得歷史資料：$error');
    }
  }

  void dispose() => _client.close();
}
