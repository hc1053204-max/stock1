from __future__ import annotations

from typing import Literal

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .stock_service import (
    StockDataError,
    add_indicators,
    download_history,
    latest_summary,
    normalize_symbol,
    to_records,
)

app = FastAPI(
    title="AI Stock Analysis API",
    version="0.1.0",
    description="第一階段：取得股票歷史資料並計算常用技術指標。",
)

# 開發階段方便 Flutter 或其他前端呼叫；正式環境應限制 allow_origins。
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)


class HistoryItem(BaseModel):
    date: str
    Open: float | None = None
    High: float | None = None
    Low: float | None = None
    Close: float | None = None
    Volume: int | None = None
    MA5: float | None = None
    MA20: float | None = None
    MA60: float | None = None
    RSI14: float | None = None
    MACD: float | None = None
    MACDSignal: float | None = None
    MACDHistogram: float | None = None


class HistoryResponse(BaseModel):
    symbol: str
    market: Literal["tw", "us"]
    period: str
    interval: str
    count: int
    data: list[HistoryItem]


class AnalysisResponse(BaseModel):
    symbol: str
    market: Literal["tw", "us"]
    as_of: str
    close: float | None
    volume: int | None
    ma5: float | None
    ma20: float | None
    ma60: float | None
    rsi14: float | None
    macd: float | None
    macd_signal: float | None
    macd_histogram: float | None
    trend: str
    data_source: str


@app.get("/", tags=["system"])
def root() -> dict[str, str]:
    return {"message": "AI Stock Analysis API is running", "docs": "/docs"}


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    return {"status": "ok"}


def _load_frame(symbol: str, market: Literal["tw", "us"], period: str, interval: str):
    try:
        return add_indicators(download_history(symbol, market, period, interval))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except StockDataError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.get("/api/v1/stocks/{symbol}/history", response_model=HistoryResponse, tags=["stocks"])
def get_history(
    symbol: str,
    market: Literal["tw", "us"] = Query("tw", description="tw=台股，us=美股"),
    period: str = Query("1y", description="例如 1mo、3mo、6mo、1y、5y、max"),
    interval: str = Query("1d", description="例如 1d、1wk、1mo"),
) -> HistoryResponse:
    """取得 OHLCV 歷史資料及所有計算出的技術指標。"""
    frame = _load_frame(symbol, market, period, interval)
    return HistoryResponse(
        symbol=normalize_symbol(symbol, market),
        market=market,
        period=period,
        interval=interval,
        count=len(frame),
        data=to_records(frame),
    )


@app.get("/api/v1/stocks/{symbol}/analysis", response_model=AnalysisResponse, tags=["stocks"])
def get_analysis(
    symbol: str,
    market: Literal["tw", "us"] = Query("tw", description="tw=台股，us=美股"),
    period: str = Query("1y", description="技術指標計算所使用的歷史期間"),
    interval: str = Query("1d", description="例如 1d、1wk、1mo"),
) -> AnalysisResponse:
    """取得最新價格、技術指標與簡單規則式趨勢摘要。"""
    frame = _load_frame(symbol, market, period, interval)
    return AnalysisResponse(**latest_summary(frame, normalize_symbol(symbol, market), market))
