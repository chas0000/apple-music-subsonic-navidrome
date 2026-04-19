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

# ===============================
# 初始化 user.txt（如果不存在则创建空文件）
# ===============================
if [ ! -f "/app/config/user.txt" ]; then
    echo "[INFO] Creating empty user.txt..."
    touch /app/config/user.txt
else
    echo "[INFO] Using existing user.txt"
fi
cp /app/config/user.txt /app/user.txt

echo "[INFO] Configuration files ready"

# ===============================
# 初始化数据库文件（如果不存在则创建）
# ===============================
mkdir -p /app/data
if [ ! -f "/app/data/apple_music_bridge.db" ]; then
    echo "[INFO] Initializing database..."
    touch /app/data/apple_music_bridge.db
else
    echo "[INFO] Using existing database"
fi

echo "[INFO] Database ready"

# ===============================
# 启动主应用
# ===============================
echo "[INFO] Starting Apple Music Bridge on port 8800..."
exec python3 /app/main.py
