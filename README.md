# AI Stock Analysis API（第一階段）

這是一個以 Python FastAPI 建立的股票分析後端範例，使用 Yahoo Finance 的歷史資料計算：

- OHLCV：開盤、最高、最低、收盤、成交量
- MA5、MA20、MA60
- RSI14
- MACD、MACD Signal、MACD Histogram
- 基於技術指標的簡單趨勢摘要：`bullish`、`bearish`、`neutral`

> 本範例是學習與專題原型，不是投資建議，也不保證資料即時或完整。Yahoo Finance / yfinance 的資料使用須遵守其服務條款；正式產品應評估合法授權的市場資料來源。

## 1. 安裝

建議使用 Python 3.11 或更新版本：

```bash
cd /home/ubuntu/stock-api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 2. 啟動

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

啟動後可開啟：

- Swagger 文件：`http://127.0.0.1:8000/docs`
- ReDoc 文件：`http://127.0.0.1:8000/redoc`
- 健康檢查：`http://127.0.0.1:8000/health`

## 3. 使用 Docker Compose 啟動

如果已安裝 Docker Desktop 或 Docker Engine，可在專案根目錄執行：

```bash
docker compose up --build -d
```

啟動後同樣可以開啟：

- Swagger 文件：`http://127.0.0.1:8000/docs`
- 健康檢查：`http://127.0.0.1:8000/health`

查看容器狀態與日誌：

```bash
docker compose ps
docker compose logs -f api
```

停止並移除容器：

```bash
docker compose down
```

Compose 會將本機 `8000` 埠映射到容器的 `8000` 埠，並透過 `/health` 執行健康檢查。容器內的 FastAPI 程式以非 root 使用者執行。

## 4. API 範例

### 台股：台積電 2330

```bash
curl "http://127.0.0.1:8000/api/v1/stocks/2330/history?market=tw&period=1y&interval=1d"
curl "http://127.0.0.1:8000/api/v1/stocks/2330/analysis?market=tw&period=1y&interval=1d"
```

### 美股：Apple

```bash
curl "http://127.0.0.1:8000/api/v1/stocks/AAPL/history?market=us&period=1y&interval=1d"
curl "http://127.0.0.1:8000/api/v1/stocks/AAPL/analysis?market=us&period=1y&interval=1d"
```

## 5. 回應範例

`/analysis` 會回傳類似以下 JSON。數值會依實際資料與查詢時間變動：

```json
{
  "symbol": "2330.TW",
  "market": "tw",
  "as_of": "2026-11-06",
  "close": 123.45,
  "volume": 12345678,
  "ma5": 122.1,
  "ma20": 119.8,
  "ma60": 115.4,
  "rsi14": 58.2,
  "macd": 1.25,
  "macd_signal": 0.92,
  "macd_histogram": 0.33,
  "trend": "bullish",
  "data_source": "Yahoo Finance via yfinance"
}
```

## 6. 專案結構

```text
stock-api/
├── app/
│   ├── __init__.py
│   ├── main.py          # FastAPI 路由與回應模型
│   └── stock_service.py # yfinance、技術指標與趨勢邏輯
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── requirements.txt
└── README.md
```

## 7. 後續可擴充項目

1. 加入資料快取與資料庫，避免每次請求都重新下載。
2. 使用排程工作每日更新股票資料。
3. 加入模型訓練與嚴格的時間序列回測，避免資料洩漏。
4. 將規則式 `trend` 替換成可驗證的 XGBoost / Random Forest 分類模型。
5. 將 CORS 的 `allow_origins=["*"]` 改成正式前端網域。
6. 增加速率限制、日誌、身份驗證與資料來源監控。
