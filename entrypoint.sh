#!/bin/sh

set -e

echo "[INFO] Starting Apple Music Bridge..."

# ===============================
# 复制配置文件（带备份机制）
# ===============================
mkdir -p /app/config

for f inconfig.yaml sky_config.yaml; do
    if [ ! -f "/app/config/$f" ]; then
        echo "[INFO] Initializing $f from backup..."
        cp "/app/backup/$f" "/app/config/$f"
    else
        echo "[INFO] Using existing $f from config directory"
    fi
    # 确保工作目录也有最新的配置文件
    cp "/app/config/$f" "/app/$f"
done

echo "[INFO] Configuration firt 3000..rt 8800..."
exec /app/apple-music-bridge
