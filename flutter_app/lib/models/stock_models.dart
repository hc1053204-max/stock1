class StockSearchItem {
  const StockSearchItem({
    required this.symbol,
    required this.name,
    required this.market,
  });

  final String symbol;
  final String name;
  final String market;
}

class StockAnalysis {
  const StockAnalysis({
    required this.symbol,
    required this.market,
    required this.asOf,
    required this.close,
    required this.volume,
    required this.ma20,
    required this.rsi14,
    required this.macd,
    required this.macdSignal,
    required this.trend,
  });

  factory StockAnalysis.fromJson(Map<String, dynamic> json) {
    return StockAnalysis(
      symbol: json['symbol'] as String? ?? '',
      market: json['market'] as String? ?? '',
      asOf: json['as_of'] as String? ?? '',
      close: (json['close'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toInt(),
      ma20: (json['ma20'] as num?)?.toDouble(),
      rsi14: (json['rsi14'] as num?)?.toDouble(),
      macd: (json['macd'] as num?)?.toDouble(),
      macdSignal: (json['macd_signal'] as num?)?.toDouble(),
      trend: json['trend'] as String? ?? 'insufficient_data',
    );
  }

  final String symbol;
  final String market;
  final String asOf;
  final double? close;
  final int? volume;
  final double? ma20;
  final double? rsi14;
  final double? macd;
  final double? macdSignal;
  final String trend;
}

class StockHistoryItem {
  const StockHistoryItem({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.ma5,
    this.ma20,
    this.ma60,
  });

  factory StockHistoryItem.fromJson(Map<String, dynamic> json) {
    double? number(String key) => (json[key] as num?)?.toDouble();

    return StockHistoryItem(
      date: DateTime.parse(json['date'] as String),
      open: number('Open') ?? 0,
      high: number('High') ?? 0,
      low: number('Low') ?? 0,
      close: number('Close') ?? 0,
      volume: (json['Volume'] as num?)?.toInt() ?? 0,
      ma5: number('MA5'),
      ma20: number('MA20'),
      ma60: number('MA60'),
    );
  }

  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
  final double? ma5;
  final double? ma20;
  final double? ma60;
}
