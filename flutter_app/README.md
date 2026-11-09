# Flutter 股票分析 App 前端範例

這個資料夾提供第一階段 Flutter 前端的架構與首頁範例，會呼叫上層 FastAPI 專案的：

```text
GET /api/v1/stocks/{symbol}/analysis
```

K 線與歷史資料頁面呼叫：

```text
GET /api/v1/stocks/{symbol}/history?market=tw&period=3mo&interval=1d
```

目前股票搜尋採用前端內建的常用股票清單，搜尋結果點選後再向 FastAPI 取得分析資料。這是因為目前後端尚未提供股票代號搜尋資料庫或 `/search` API。

## 架構

```text
lib/
├── main.dart                         # App 入口、主題與 API_BASE_URL
├── models/
│   └── stock_models.dart              # 股票、分析與 OHLCV 歷史資料模型
├── services/
│   └── stock_api_client.dart          # HTTP client、URL、錯誤處理
└── screens/
    ├── home_screen.dart               # 首頁、搜尋、分析結果卡片
    └── history_screen.dart            # K 線圖、均線、成交量與歷史清單
```

建議後續完整 App 採用以下分層：

```text
Presentation（screens/widgets）
        ↓
State management（Riverpod / Bloc）
        ↓
Repository（StockRepository）
        ↓
Data source（StockApiClient）
        ↓
FastAPI
```

第一階段使用 `StatefulWidget` 管理畫面狀態，讓範例容易理解；功能擴大後，再將 `_loading`、`_error`、`_analysis` 移到 Riverpod 或 Bloc。

## 建立與執行

目前資料夾是可以放進 Flutter 專案的範例程式碼。若要建立完整原生專案：

```bash
cd /home/ubuntu/stock-api
flutter create flutter_app
```

接著將本資料夾中的 `lib/`、`pubspec.yaml` 與 Android 設定範例合併到 Flutter 專案，再執行：

```bash
cd flutter_app
flutter pub get
flutter run
```

## 瀏覽器互動預覽

由於此範例的執行環境不一定安裝 Flutter SDK，另提供不依賴 Flutter 的手機尺寸互動預覽：

```bash
cd flutter_app/preview
python3 -m http.server 8080
```

開啟 `http://127.0.0.1:8080` 後，可以點選股票、查看分析卡片，再進入 K 線與歷史資料頁面。

- `preview/index.html`：可點擊的互動預覽
- `UI_DESIGN.md`：色彩、元件、頁面配置與互動規範
- `UI_FLOW.md`：Mermaid 頁面流程原始碼
- `UI_FLOW.png`：頁面流程圖
- `preview/home-preview.png`：首頁預覽截圖
- `preview/history-preview.png`：K 線頁預覽截圖

## FastAPI 位址設定

### Android Emulator

預設值已設定為：

```text
http://10.0.2.2:8000
```

`10.0.2.2` 代表 Android Emulator 的主機 localhost。

### iOS Simulator

執行時覆寫：

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

### 實體手機

1. 確認手機與執行 FastAPI 的電腦位於同一個區域網路。
2. 將 `API_BASE_URL` 改為電腦區網 IP，例如 `http://192.168.1.20:8000`。
3. 啟動 FastAPI 時綁定所有網卡：

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

範例：

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
```

Android 開發階段的 HTTP 權限參考 `android/AndroidManifest.xml.example`。正式環境應使用 HTTPS，並移除 cleartext traffic 設定。

## 已包含的功能

- Material 3 金融科技風格基礎主題
- 股票代號與公司名稱搜尋
- 台股／美股市場標示
- 點選股票後呼叫 FastAPI `/analysis`
- 從分析結果進入 K 線與歷史資料頁面
- 使用 CustomPainter 繪製 OHLC 蠟燭線
- 顯示 MA5、MA20、MA60 均線
- 顯示成交量柱狀圖
- 顯示近 1 個月、3 個月、6 個月與 1 年資料區間
- 顯示最新交易日 OHLCV 與歷史資料清單
- 網頁預覽支援 Bollinger Bands 與 KD 指標切換
- 網頁預覽支援自選股新增、移除與 localStorage 保存
- 顯示收盤價、MA20、RSI14、MACD、MACD Signal、成交量
- 偏多、偏空、觀望、資料不足顏色標籤
- 載入中、錯誤與下拉重新整理狀態
- API 連線逾時與非 2xx 回應處理

## 注意事項

- 這個搜尋清單只是前端示範資料，不是完整的市場股票清單。
- 目前 FastAPI 使用 yfinance，資料可能延遲或受第三方服務限制。
- 所有分析結果僅供學習與研究，不構成投資建議。
