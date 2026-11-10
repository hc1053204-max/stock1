from __future__ import annotations

from collections import OrderedDict
from datetime import date
import threading
import time
from typing import Literal

import pandas as pd
import yfinance as yf

Market = Literal["tw", "us"]

# Yahoo Finance calls are relatively slow and are shared by both API endpoints.
# Keep a short-lived, bounded in-memory cache to avoid downloading identical
# history repeatedly while ensuring callers cannot mutate cached DataFrames.
_HISTORY_CACHE_TTL_SECONDS = 300
_HISTORY_CACHE_MAX_ENTRIES = 128
_HISTORY_CACHE: OrderedDict[tuple[str, str, str], tuple[float, pd.DataFrame]] = OrderedDict()
_HISTORY_CACHE_LOCK = threading.RLock()


class StockDataError(Exception):
    """股票資料取得或格式處理失敗。"""


def normalize_symbol(symbol: str, market: Market = "tw") -> str:
    """將使用者輸入轉成 Yahoo Finance ticker 格式。"""
    cleaned = symbol.strip().upper()
    if not cleaned:
        raise ValueError("股票代號不可為空")

    if market == "tw":
        # 台股現貨通常使用 .TW；若使用者已提供 suffix 則保留。
        if "." not in cleaned:
            cleaned = f"{cleaned}.TW"
    elif market == "us":
        if "." in cleaned:
            raise ValueError("美股股票代號請輸入不含市場 suffix 的代號，例如 AAPL")
    else:
        raise ValueError("market 必須是 tw 或 us")

    return cleaned


def _flatten_columns(frame: pd.DataFrame) -> pd.DataFrame:
    """處理 yfinance 在部分版本或情況下回傳的 MultiIndex 欄位。"""
    if isinstance(frame.columns, pd.MultiIndex):
        frame.columns = [column[0] for column in frame.columns]
    return frame


def download_history(
    symbol: str,
    market: Market = "tw",
    period: str = "1y",
    interval: str = "1d",
) -> pd.DataFrame:
    """從 Yahoo Finance 下載歷史 OHLCV 資料，並短暫快取成功結果。"""
    ticker = normalize_symbol(symbol, market)
    cache_key = (ticker, period, interval)
    now = time.monotonic()

    with _HISTORY_CACHE_LOCK:
        cached = _HISTORY_CACHE.get(cache_key)
        if cached is not None:
            cached_at, cached_frame = cached
            if now - cached_at < _HISTORY_CACHE_TTL_SECONDS:
                _HISTORY_CACHE.move_to_end(cache_key)
                return cached_frame.copy(deep=True)
            del _HISTORY_CACHE[cache_key]

    try:
        frame = yf.download(
            ticker,
            period=period,
            interval=interval,
            auto_adjust=False,
            progress=False,
            threads=False,
        )
    except Exception as exc:  # noqa: BLE001 - 將第三方錯誤轉成服務層錯誤
        raise StockDataError(f"無法取得 {ticker} 的股票資料：{exc}") from exc

    if frame is None or frame.empty:
        raise StockDataError(
            f"找不到 {ticker} 的歷史資料，請確認股票代號、market 或 period 是否正確"
        )

    frame = _flatten_columns(frame)
    required = {"Open", "High", "Low", "Close", "Volume"}
    missing = required.difference(frame.columns)
    if missing:
        raise StockDataError(f"資料缺少必要欄位：{', '.join(sorted(missing))}")

    frame = frame.loc[:, ["Open", "High", "Low", "Close", "Volume"]].copy()
    frame.index = pd.to_datetime(frame.index)
    frame = frame.dropna(subset=["Open", "High", "Low", "Close"])
    if frame.empty:
        raise StockDataError(f"{ticker} 沒有可用的價格資料")

    # Cache only validated data. Return a separate copy so downstream indicator
    # calculations cannot mutate the shared cached frame.
    with _HISTORY_CACHE_LOCK:
        _HISTORY_CACHE[cache_key] = (time.monotonic(), frame.copy(deep=True))
        _HISTORY_CACHE.move_to_end(cache_key)
        while len(_HISTORY_CACHE) > _HISTORY_CACHE_MAX_ENTRIES:
            _HISTORY_CACHE.popitem(last=False)
    return frame


def add_indicators(frame: pd.DataFrame) -> pd.DataFrame:
    """計算均線、RSI、MACD、Bollinger Bands 與 KD。"""
    result = frame.copy()
    close = result["Close"].astype(float)

    result["MA5"] = close.rolling(window=5, min_periods=5).mean()
    result["MA20"] = close.rolling(window=20, min_periods=20).mean()
    result["MA60"] = close.rolling(window=60, min_periods=60).mean()

    # Bollinger Bands：20 日均線，上下軌為均線加減 2 個標準差。
    bb_middle = close.rolling(window=20, min_periods=20).mean()
    bb_std = close.rolling(window=20, min_periods=20).std(ddof=0)
    result["BBMiddle"] = bb_middle
    result["BBUpper"] = bb_middle + 2 * bb_std
    result["BBLower"] = bb_middle - 2 * bb_std

    # RSI 使用 Wilder 常用的 exponential moving average 版本。
    delta = close.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    average_gain = gain.ewm(alpha=1 / 14, min_periods=14, adjust=False).mean()
    average_loss = loss.ewm(alpha=1 / 14, min_periods=14, adjust=False).mean()
    relative_strength = average_gain / average_loss.replace(0, pd.NA)
    result["RSI14"] = 100 - (100 / (1 + relative_strength))
    result.loc[(average_loss == 0) & (average_gain > 0), "RSI14"] = 100.0
    result.loc[(average_loss == 0) & (average_gain == 0), "RSI14"] = 50.0

    ema12 = close.ewm(span=12, adjust=False, min_periods=12).mean()
    ema26 = close.ewm(span=26, adjust=False, min_periods=26).mean()
    result["MACD"] = ema12 - ema26
    result["MACDSignal"] = result["MACD"].ewm(
        span=9, adjust=False, min_periods=9
    ).mean()
    result["MACDHistogram"] = result["MACD"] - result["MACDSignal"]

    # KD：9 日 RSV，K/D 使用 alpha=1/3 的平滑方式，J=3K-2D。
    lowest_9 = result["Low"].rolling(window=9, min_periods=9).min()
    highest_9 = result["High"].rolling(window=9, min_periods=9).max()
    denominator = (highest_9 - lowest_9).replace(0, pd.NA)
    rsv = ((close - lowest_9) / denominator * 100).fillna(50.0)
    result["RSV9"] = rsv
    result["K9"] = rsv.ewm(alpha=1 / 3, adjust=False, min_periods=1).mean()
    result["D9"] = result["K9"].ewm(alpha=1 / 3, adjust=False, min_periods=1).mean()
    result["J9"] = 3 * result["K9"] - 2 * result["D9"]

    return result


def infer_trend(frame: pd.DataFrame) -> str:
    """以 MA20/MA60、RSI 與 MACD 做簡單的規則式趨勢摘要。"""
    latest = frame.dropna(subset=["MA20", "RSI14", "MACD", "MACDSignal"]).iloc[-1]
    score = 0
    score += 1 if latest["Close"] > latest["MA20"] else -1
    score += 1 if latest["MA20"] > latest.get("MA60", latest["MA20"]) else -1
    score += 1 if latest["MACD"] > latest["MACDSignal"] else -1
    score += 1 if latest["RSI14"] >= 50 else -1

    if score >= 2:
        return "bullish"
    if score <= -2:
        return "bearish"
    return "neutral"


def to_records(frame: pd.DataFrame) -> list[dict]:
    """將 DataFrame 轉成 JSON-safe 的歷史資料陣列。"""
    output: list[dict] = []
    for timestamp, row in frame.iterrows():
        record = {"date": timestamp.strftime("%Y-%m-%d")}
        for column, value in row.items():
            if pd.isna(value):
                record[column] = None
            elif column == "Volume":
                record[column] = int(value)
            else:
                record[column] = round(float(value), 4)
        output.append(record)
    return output


def latest_summary(frame: pd.DataFrame, symbol: str, market: Market) -> dict:
    """產生最新一筆價格、指標與規則式趨勢摘要。"""
    latest = frame.iloc[-1]
    indicator_frame = frame.dropna(subset=["MA20", "RSI14", "MACD", "MACDSignal"])
    trend = infer_trend(frame) if not indicator_frame.empty else "insufficient_data"

    def number(column: str):
        value = latest.get(column)
        return None if pd.isna(value) else round(float(value), 4)

    return {
        "symbol": symbol,
        "market": market,
        "as_of": frame.index[-1].date().isoformat(),
        "close": number("Close"),
        "volume": int(latest["Volume"]) if not pd.isna(latest["Volume"]) else None,
        "ma5": number("MA5"),
        "ma20": number("MA20"),
        "ma60": number("MA60"),
        "bb_upper": number("BBUpper"),
        "bb_middle": number("BBMiddle"),
        "bb_lower": number("BBLower"),
        "rsi14": number("RSI14"),
        "macd": number("MACD"),
        "macd_signal": number("MACDSignal"),
        "macd_histogram": number("MACDHistogram"),
        "rsv9": number("RSV9"),
        "k9": number("K9"),
        "d9": number("D9"),
        "j9": number("J9"),
        "trend": trend,
        "data_source": "Yahoo Finance via yfinance",
    }
