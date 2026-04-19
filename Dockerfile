# 最小化运行时镜像
FROM python:3.11-alpine

# 安装基础依赖
RUN apk add --no-cache \
    curl \
    unzip

WORKDIR /app

# 复制编译好的二进制文件（由 GitHub Actions 或本地编译提供）
COPY dist/apple-music-bridge /app/apple-music-bridge

# 安装运行时依赖
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache \
        ffmpeg \
        gpac \
        wget

# 安装 mp4decrypt (Bento4)
RUN wget -q "https://www.bok.net/Bento4/binaries/Bento4-SDK-1-6-0-639.x86_64-unknown-linux.zip" -O /tmp/bento4.zip && \
    unzip -j /tmp/bento4.zip "Bento4-SDK-1-6-0-639.x86_64-unknown-linux/bin/mp4decrypt" -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/mp4decrypt && \
    rm -f /tmp/bento4.zip && \
    apk del wget

# 下载并配置 downloader（根据架构）
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        ARCH="amd64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        ARCH="arm64"; \
    else \
        ARCH="amd64"; \
    fi && \
    echo "Downloading downloader for $ARCH" && \
    LATEST_URL=$(curl -s https://api.github.com/repos/chas0000/AMDL-docker/releases/latest | grep "browser_download_url.*amdl-${ARCH}.tar.gz" | cut -d '"' -f 4) && \
    curl -L -o /tmp/downloader.tar.gz "$LATEST_URL" && \
    tar -xzf /tmp/downloader.tar.gz -C /tmp/ && \
    cp /tmp/amdl-${ARCH}/sdl /app/downloader && \
    cp /tmp/amdl-${ARCH}/sky_config.yaml /app/sky_config.yaml && \
    chmod +x /app/downloader && \
    rm -rf /tmp/downloader.tar.gz /tmp/amdl-${ARCH}

# 创建备份目录并备份配置文件
RUN mkdir -p /app/backup && \
    cp /app/sky_config.yaml /app/backup/sky_config.yaml

# 创建必要的目录
RUN mkdir -p ./temp_cache ./music


# 复制 entrypoint 脚本
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# 暴露端口
EXPOSE 8800
EXPOSE 3000

# 设置环境变量
ENV PYTHONUNBUFFERED=1

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8800/docs || exit 1

# 使用 entrypoint 脚本
ENTRYPOINT ["/app/entrypoint.sh"]
