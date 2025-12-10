# 阶段1: 构建器 - 准备静态资产与编译KasmVNC
FROM alpine:latest as builder

# 1.1 构建KasmVNC
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxtst-dev \
    libtool \
    automake \
    autoconf \
    openssl-dev \
    nettle-dev \
    xorgproto \
    libx11-dev \
    libxext-dev \
    libxi-dev \
    libxrandr-dev \
    libxfixes-dev \
    libxdamage-dev \
    libxcursor-dev

RUN cd /tmp && \
    git clone https://github.com/kasmtech/KasmVNC.git --depth 1 && \
    cd KasmVNC && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_VIEWER=OFF && \
    make -j$(nproc) && \
    make DESTDIR=/opt/kasmvnc install

# 1.2 克隆noVNC（仅作为备选或测试）
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify

# 阶段2: 最终运行时镜像
FROM alpine:latest

LABEL org.opencontainers.image.title="Firefox with KasmVNC"
LABEL org.opencontainers.image.description="Lightweight Firefox with KasmVNC for web access"
LABEL org.opencontainers.image.licenses="MIT"

# 2.1 安装运行时依赖
RUN apk add --no-cache \
    firefox \
    xvfb \
    supervisor \
    bash \
    fluxbox \
    # 字体
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    # 工具
    file \
    findutils \
    coreutils \
    # X11库 (KasmVNC运行时需要)
    libjpeg-turbo \
    libpng \
    libwebp \
    libxtst \
    libx11 \
    libxext \
    libxi \
    libxrandr \
    libxfixes \
    libxdamage \
    libxcursor \
    # 其他
    openssl \
    nettle \
    && rm -rf /var/cache/apk/*

# 2.2 设置语言环境
RUN apk add --no-cache locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.UTF-8 en_GB.UTF-8 \
    && rm -rf /var/cache/apk/*

# 2.3 创建目录结构
RUN mkdir -p \
    /var/log/supervisor \
    /etc/supervisor/conf.d \
    /root/.vnc \
    /root/.fluxbox \
    /data \
    /data/downloads \
    /data/bookmarks \
    /data/cache \
    /data/config \
    /data/tmp \
    && chmod -R 777 /data

# 2.4 从构建器阶段复制文件
# 复制KasmVNC
COPY --from=builder /opt/kasmvnc/usr/local/ /usr/local/
# 复制noVNC作为备选（可选）
COPY --from=builder /opt/novnc /opt/novnc

# 2.5 创建KasmVNC符号链接和确保目录存在
RUN ln -sf /usr/local/bin/kasmvncserver /usr/bin/ \
    && ln -sf /usr/local/share/kasmvnc /usr/local/share/ \
    && mkdir -p /usr/local/share/kasmvnc/web

# 2.6 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
COPY init-storage.sh /usr/local/bin/init-storage.sh
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/*.sh

# 2.7 创建Firefox配置模板
RUN mkdir -p /etc/firefox/template && \
    cat > /etc/firefox/template/prefs.js << 'EOF'
user_pref("browser.cache.disk.parent_directory", "/data/cache");
user_pref("browser.download.dir", "/data/downloads");
user_pref("browser.download.folderList", 2);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.bookmarks.file", "/data/bookmarks/bookmarks.html");
user_pref("dom.storage.default_quota", 5242880);
user_pref("dom.storage.enabled", true);
user_pref("dom.indexedDB.enabled", true);
user_pref("intl.accept_languages", "en-US, en");
user_pref("font.language.group", "en-US");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.page", 0);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
EOF

# 2.8 设置Fluxbox菜单（简化版）
RUN echo '[begin] (fluxbox)' > /root/.fluxbox/menu && \
    echo '[exec] (Firefox) {firefox}' >> /root/.fluxbox/menu && \
    echo '[exec] (Terminal) {xterm}' >> /root/.fluxbox/menu && \
    echo '[separator]' >> /root/.fluxbox/menu && \
    echo '[exit] (Exit)' >> /root/.fluxbox/menu && \
    echo '[end]' >> /root/.fluxbox/menu

# 2.9 暴露端口
EXPOSE 5901  # KasmVNC RFB端口
EXPOSE 7860  # KasmVNC WebSocket端口

VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/start.sh"]
