# 使用 Ubuntu 22.04 基础镜像
FROM ubuntu:22.04

# 设置工作目录
WORKDIR /app

# 安装基础依赖和 Python
RUN set -eux; \
    apt-get update || (sleep 5 && apt-get update); \
    apt-get install -y --no-install-recommends \
        wget \
        curl \
        ca-certificates \
        git \
        ffmpeg \
        g++ \
        make \
        cmake \
        zlib1g-dev \
        coreutils \
        unzip \
        python3 \
        python3-pip \
        python3-venv \
    || (apt-get update && apt-get install -y --no-install-recommends \
        wget \
        curl \
        ca-certificates \
        git \
        ffmpeg \
        g++ \
        make \
        cmake \
        zlib1g-dev \
        coreutils \
        unzip \
        python3 \
        python3-pip \
        python3-venv); \
    rm -rf /var/lib/apt/lists/*

# 复制源代码
COPY . /app/

# 删除不需要的文件（downloader 压缩包）
RUN rm -f /app/downloader-linux-x64.zip /app/downloader-mac-arm.zip

# 创建虚拟环境并安装依赖
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install -r requirements.txt

# 设置环境变量使用虚拟环境
ENV PATH="/opt/venv/bin:$PATH"

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
    # 清理
    rm -rf /app/build; \
    apt-get purge -y g++ make cmake git wget curl; \
    apt-get autoremove -y

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

# 设置环境变量
ENV PYTHONUNBUFFERED=1

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8800/docs || exit 1

# 使用 entrypoint 脚本
ENTRYPOINT ["/app/entrypoint.sh"]
