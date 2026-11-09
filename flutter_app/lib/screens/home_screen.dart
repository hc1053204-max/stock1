import 'package:flutter/material.dart';

import '../models/stock_models.dart';
import '../services/stock_api_client.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final StockApiClient api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _universe = const <StockSearchItem>[
    StockSearchItem(symbol: '2330', name: '台積電', market: 'tw'),
    StockSearchItem(symbol: '2317', name: '鴻海', market: 'tw'),
    StockSearchItem(symbol: '2454', name: '聯發科', market: 'tw'),
    StockSearchItem(symbol: '0050', name: '元大台灣50', market: 'tw'),
    StockSearchItem(symbol: 'AAPL', name: 'Apple', market: 'us'),
    StockSearchItem(symbol: 'MSFT', name: 'Microsoft', market: 'us'),
    StockSearchItem(symbol: 'NVDA', name: 'NVIDIA', market: 'us'),
  ];

  List<StockSearchItem> _results = const [];
  StockAnalysis? _analysis;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _results = _universe;
    _searchController.addListener(_filterStocks);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_filterStocks)
      ..dispose();
    super.dispose();
  }

  void _filterStocks() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _results = query.isEmpty
          ? _universe
          : _universe
                .where(
                  (stock) =>
                      stock.symbol.toLowerCase().contains(query) ||
                      stock.name.toLowerCase().contains(query),
                )
                .toList();
    });
  }

  Future<void> _loadAnalysis(StockSearchItem stock) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _analysis = null;
    });

    try {
      final analysis = await widget.api.fetchAnalysis(
        symbol: stock.symbol,
        market: stock.market,
      );
      if (!mounted) return;
      setState(() => _analysis = analysis);
    } on StockApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _trendColor(String trend) {
    switch (trend) {
      case 'bullish':
        return Colors.green.shade700;
      case 'bearish':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  String _trendLabel(String trend) {
    switch (trend) {
      case 'bullish':
        return '偏多';
      case 'bearish':
        return '偏空';
      case 'neutral':
        return '觀望';
      default:
        return '資料不足';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 股票分析'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final selected = _analysis;
          if (selected != null) {
            await _loadAnalysis(
              StockSearchItem(
                symbol: selected.symbol.replaceAll('.TW', ''),
                name: selected.symbol,
                market: selected.market,
              ),
            );
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '市場概況',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '搜尋股票，查看最新技術指標與趨勢摘要。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入股票代號或公司名稱，例如 2330、台積電、AAPL',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_results.isNotEmpty)
              Card(
                child: Column(
                  children: _results
                      .map(
                        (stock) => ListTile(
                          leading: CircleAvatar(
                            child: Text(stock.market == 'tw' ? '台' : '美'),
                          ),
                          title: Text(stock.name),
                          subtitle: Text('${stock.symbol} · ${stock.market}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _loadAnalysis(stock),
                        ),
                      )
                      .toList(),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('找不到符合的股票')),
              ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _ErrorCard(message: _error!),
            if (_analysis != null)
              _AnalysisCard(
                analysis: _analysis!,
                color: _trendColor(_analysis!.trend),
                label: _trendLabel(_analysis!.trend),
                onOpenHistory: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HistoryScreen(
                        api: widget.api,
                        symbol: _analysis!.symbol.replaceAll('.TW', ''),
                        market: _analysis!.market,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            const Text(
              '提醒：資料可能延遲，技術指標與趨勢摘要僅供學習與研究，不構成投資建議。',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.analysis,
    required this.color,
    required this.label,
    required this.onOpenHistory,
  });

  final StockAnalysis analysis;
  final Color color;
  final String label;
  final VoidCallback onOpenHistory;

  String _number(double? value) => value == null ? '--' : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: color.withAlpha(31),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(analysis.symbol, style: Theme.of(context).textTheme.titleLarge),
                    Text('資料日期：${analysis.asOf}'),
                  ],
                ),
                Chip(
                  label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  avatar: Icon(Icons.insights, color: color, size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _Metric(label: '收盤價', value: _number(analysis.close)),
                _Metric(label: 'MA20', value: _number(analysis.ma20)),
                _Metric(label: 'RSI14', value: _number(analysis.rsi14)),
                _Metric(label: 'MACD', value: _number(analysis.macd)),
                _Metric(label: 'MACD Signal', value: _number(analysis.macdSignal)),
                _Metric(label: '成交量', value: analysis.volume?.toString() ?? '--'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenHistory,
                icon: const Icon(Icons.show_chart),
                label: const Text('查看 K 線與歷史資料'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('取得資料失敗'),
        subtitle: Text(message),
      ),
    );
  }
}
