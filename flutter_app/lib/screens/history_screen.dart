import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/stock_models.dart';
import '../services/stock_api_client.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.api,
    required this.symbol,
    required this.market,
  });

  final StockApiClient api;
  final String symbol;
  final String market;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _period = '3mo';
  late Future<List<StockHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<StockHistoryItem>> _loadHistory() {
    return widget.api.fetchHistory(
      symbol: widget.symbol,
      market: widget.market,
      period: _period,
    );
  }

  void _changePeriod(String? value) {
    if (value == null || value == _period) return;
    setState(() {
      _period = value;
      _historyFuture = _loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.symbol} 歷史走勢')),
      body: FutureBuilder<List<StockHistoryItem>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _HistoryError(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _historyFuture = _loadHistory()),
            );
          }

          final data = snapshot.data ?? const <StockHistoryItem>[];
          if (data.isEmpty) {
            return const Center(child: Text('目前沒有可用的歷史資料'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _historyFuture = _loadHistory());
              await _historyFuture;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'K 線圖',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    DropdownButton<String>(
                      value: _period,
                      items: const [
                        DropdownMenuItem(value: '1mo', child: Text('近 1 個月')),
                        DropdownMenuItem(value: '3mo', child: Text('近 3 個月')),
                        DropdownMenuItem(value: '6mo', child: Text('近 6 個月')),
                        DropdownMenuItem(value: '1y', child: Text('近 1 年')),
                      ],
                      onChanged: _changePeriod,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _Legend(),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 12, 12),
                    child: SizedBox(
                      height: 390,
                      child: CandlestickChart(data: data),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '最新交易日資料',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _LatestQuoteCard(item: data.last),
                const SizedBox(height: 16),
                Text(
                  '歷史資料（最新在前）',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...data.reversed.take(20).map((item) => _HistoryRow(item: item)),
                const SizedBox(height: 12),
                const Text(
                  'K 線及技術指標由後端歷史資料計算，僅供學習與研究，不構成投資建議。',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CandlestickChart extends StatelessWidget {
  const CandlestickChart({super.key, required this.data});

  final List<StockHistoryItem> data;

  @override
  Widget build(BuildContext context) {
    final visible = data.length > 60 ? data.sublist(data.length - 60) : data;
    return CustomPaint(painter: _CandlestickPainter(visible));
  }
}

class _CandlestickPainter extends CustomPainter {
  _CandlestickPainter(this.data);

  final List<StockHistoryItem> data;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    const top = 12.0;
    final chartHeight = size.height * 0.68;
    final volumeTop = size.height * 0.77;
    final volumeHeight = size.height * 0.17;
    final left = 42.0;
    final right = size.width - 8;
    final plotWidth = math.max(1, right - left);

    final minPrice = data.map((e) => e.low).reduce((a, b) => a < b ? a : b);
    final maxPrice = data.map((e) => e.high).reduce((a, b) => a > b ? a : b);
    final priceRange = math.max(0.01, maxPrice - minPrice).toDouble();
    final maxVolume = data.map((e) => e.volume).reduce((a, b) => a > b ? a : b);
    final candleWidth = math.max(2.0, plotWidth / data.length * 0.62).toDouble();

    double xAt(int index) => left + plotWidth * (index + 0.5) / data.length;
    double yPrice(double price) =>
        top + (maxPrice - price) / priceRange * chartHeight;
    double yVolume(int volume) =>
        volumeTop + volumeHeight - volume / maxVolume * volumeHeight;

    final gridPaint = Paint()
      ..color = Colors.grey.withAlpha(45)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
      _drawLabel(
        canvas,
        maxPrice - priceRange * i / 4,
        Offset(0, y - 7),
        const TextStyle(fontSize: 10, color: Colors.black54),
      );
    }
    canvas.drawLine(
      Offset(left, volumeTop),
      Offset(right, volumeTop),
      gridPaint,
    );
    _drawLabel(
      canvas,
      '成交量',
      Offset(0, volumeTop + 4),
      const TextStyle(fontSize: 10, color: Colors.black54),
    );

    final volumeUpPaint = Paint()..color = Colors.red.withAlpha(130);
    final volumeDownPaint = Paint()..color = Colors.green.withAlpha(130);
    final wickPaint = Paint()..strokeWidth = 1;
    final upPaint = Paint()..color = Colors.red;
    final downPaint = Paint()..color = Colors.green;

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final x = xAt(i);
      final isUp = item.close >= item.open;
      wickPaint.color = isUp ? Colors.red : Colors.green;
      canvas.drawLine(
        Offset(x, yPrice(item.high)),
        Offset(x, yPrice(item.low)),
        wickPaint,
      );

      final bodyTop = yPrice(item.open > item.close ? item.open : item.close);
      final bodyBottom = yPrice(item.open < item.close ? item.open : item.close);
      final bodyHeight = math.max(1.5, bodyBottom - bodyTop).toDouble();
      canvas.drawRect(
        Rect.fromLTWH(x - candleWidth / 2, bodyTop, candleWidth, bodyHeight),
        isUp ? upPaint : downPaint,
      );

      final volumePaint = isUp ? volumeUpPaint : volumeDownPaint;
      canvas.drawRect(
        Rect.fromLTRB(
          x - candleWidth / 2,
          yVolume(item.volume),
          x + candleWidth / 2,
          volumeTop + volumeHeight,
        ),
        volumePaint,
      );
    }

    _drawMovingAverage(canvas, data, (item) => item.ma5, xAt, yPrice, Colors.orange);
    _drawMovingAverage(canvas, data, (item) => item.ma20, xAt, yPrice, Colors.blue);
    _drawMovingAverage(canvas, data, (item) => item.ma60, xAt, yPrice, Colors.purple);

    final labelStyle = const TextStyle(fontSize: 10, color: Colors.black54);
    final labelIndexes = <int>{0, data.length ~/ 2, data.length - 1};
    for (final index in labelIndexes) {
      if (index < 0 || index >= data.length) continue;
      final text = '${data[index].date.month}/${data[index].date.day}';
      _drawLabel(canvas, text, Offset(xAt(index) - 14, size.height - 12), labelStyle);
    }
  }

  void _drawMovingAverage(
    Canvas canvas,
    List<StockHistoryItem> items,
    double? Function(StockHistoryItem) valueOf,
    double Function(int) xAt,
    double Function(double) yPrice,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path();
    var started = false;
    for (var i = 0; i < items.length; i++) {
      final value = valueOf(items[i]);
      if (value == null) {
        started = false;
        continue;
      }
      final point = Offset(xAt(i), yPrice(value));
      if (!started) {
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawLabel(Canvas canvas, Object value, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value is num ? value.toStringAsFixed(0) : '$value', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) =>
      oldDelegate.data != data;
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: const [
        _LegendItem(color: Colors.red, label: '上漲'),
        _LegendItem(color: Colors.green, label: '下跌'),
        _LegendItem(color: Colors.orange, label: 'MA5'),
        _LegendItem(color: Colors.blue, label: 'MA20'),
        _LegendItem(color: Colors.purple, label: 'MA60'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _LatestQuoteCard extends StatelessWidget {
  const _LatestQuoteCard({required this.item});

  final StockHistoryItem item;

  String _format(double value) => value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _QuoteMetric(label: '日期', value: '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}'),
            _QuoteMetric(label: '開盤', value: _format(item.open)),
            _QuoteMetric(label: '最高', value: _format(item.high)),
            _QuoteMetric(label: '最低', value: _format(item.low)),
            _QuoteMetric(label: '收盤', value: _format(item.close)),
            _QuoteMetric(label: '成交量', value: item.volume.toString()),
          ],
        ),
      ),
    );
  }
}

class _QuoteMetric extends StatelessWidget {
  const _QuoteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final StockHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final isUp = item.close >= item.open;
    final color = isUp ? Colors.red.shade700 : Colors.green.shade700;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}'),
      subtitle: Text('開 ${item.open.toStringAsFixed(2)}  高 ${item.high.toStringAsFixed(2)}  低 ${item.low.toStringAsFixed(2)}'),
      trailing: Text(
        item.close.toStringAsFixed(2),
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            const Text('歷史資料取得失敗'),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }
}
