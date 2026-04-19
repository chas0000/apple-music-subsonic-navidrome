# 最小化运行时镜像
FROM python:3.11-alpine

# 安装编译依赖
RUN apk add --no-cache \
    gcc \
    g++ \
    make \
    cmake \
    git \
    wget \
    curl \
    unzip \
    freetype-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    zlib-dev \
    linux-headers

WORKDIR /app

# 复制编译好的二进制文件（由 GitHub Actions 或本地编译提供）
COPY dist/apple-music-bridge /app/apple-music-bridge

# 构建 GPAC 和 Bento4
RUN set -eux; \
    mkdir -p /app/build; \
    \
    # Build GPAC
    git clone --depth=1 https://github.com/gpac/gpac.git /app/build/gpac; \
    cd /app/build/gpac; \
    ./configure; \
    make -j$(nproc); \
    make install; \
    MP4BOX_PATH=$(command -v MP4Box); \
    if [ -n "$MP4BOX_PATH" ]; then ln -sf "$MP4BOX_PATH" "$(dirname "$MP4BOX_PATH")/mp4box"; fi; \
    \
    # Build Bento4
    git clone --depth=1 https://github.com/axiomatic-systems/Bento4.git /app/build/Bento4; \
    mkdir -p /app/build/Bento4/cmakebuild; \
    cd /app/build/Bento4/cmakebuild; \
    cmake -DCMAKE_BUILD_TYPE=Release ..; \
    make -j$(nproc); \
    mv ./mp4decrypt /usr/local/bin/mp4decrypt; \
    \
    # 清理编译工具和源码
    rm -rf /app/build; \
    apk del gcc g++ make cmake git wget

# 验证 MP4Box 和 mp4decrypt 安装
RUN echo "Verifying MP4Box installation..." && \
    which mp4box && mp4box -version && \
    echo "Verifying mp4decrypt installation..." && \
    which mp4decrypt && mp4decrypt --version

# 安装运行时依赖（ffmpeg）
RUN apk add --no-cache ffmpeg

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
