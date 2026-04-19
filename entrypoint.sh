#!/bin/sh

set -e

echo "[INFO] Starting Apple Music Bridge..."

# ===============================
# 复制配置文件（带备份机制）
# ===============================
mkdir -p /app/config

for f in sky_config.yaml; do
    if [ ! -f "/app/config/$f" ]; then
        echo "[INFO] Initializing $f from backup..."
        cp "/app/backup/$f" "/app/config/$f"
    else
        echo "[INFO] Using existing $f from config directory"
    fi
    # 确保工作目录也有最新的配置文件
    cp "/app/config/$f" "/app/$f"
done

echo "[INFO] Configuration files ready"

# ===============================
# 初始化数据库文件（如果不存在则创建）
# ===============================
if [ ! -f "/app/apple_music_bridge.db" ]; then
    echo "[INFO] Initializing database..."
    touch /app/apple_music_bridge.db
else
    echo "[INFO] Using existing database"
fi

echo "[INFO] Database ready"

# ===============================
# 启动主应用（apple-music-bridge 会调用 downloader）
# ===============================
echo "[INFO] Starting Apple Music Bridge on port 8800..."
exec /app/apple-music-bridge
