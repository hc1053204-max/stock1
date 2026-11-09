FROM python:3.11-slim

# 避免產生 .pyc，並讓日誌即時輸出到容器標準輸出。
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# 先安裝依賴，讓 Docker build 能有效利用 layer cache。
COPY requirements.txt ./
RUN pip install --upgrade pip \
    && pip install -r requirements.txt

# 複製應用程式原始碼。
COPY app ./app

# 不以 root 執行應用程式。
RUN addgroup --system appgroup \
    && adduser --system --ingroup appgroup appuser \
    && chown -R appuser:appgroup /app
USER appuser

EXPOSE 8000

# Compose 與容器平台可用此端點判斷服務是否正常。
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
