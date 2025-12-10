# ============================================================================
# 阶段1: 占位构建器阶段 (为了保持多阶段构建结构清晰)
# ============================================================================
FROM alpine:latest AS builder

# 此阶段主要为保持结构，实际工作移至第二阶段以简化流程
RUN echo "Preparing for KasmVNC installation..." && \
    mkdir -p /tmp

# ============================================================================
# 阶段2: 最终运行时镜像
# ============================================================================
FROM alpine:latest

# 镜像元数据
LABEL org.opencontainers.image.title="Firefox with KasmVNC"
LABEL org.opencontainers.image.description="Lightweight Firefox browser with KasmVNC for web access and full data persistence"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.url="https://github.com/yourusername/firefox-kasmvnc"
LABEL org.opencontainers.image.source="https://github.com/yourusername/firefox-kasmvnc"

# 安装所有运行时依赖
RUN apk update && apk add --no-cache \
    # 核心应用
    firefox \
    xvfb \
    supervisor \
    bash \
    fluxbox \
    # 英文字体
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    # 系统工具
    file \
    findutils \
    coreutils \
    wget \
    # X11库 (VNC和Firefox需要)
    libx11 \
    libxext \
    libxi \
    libxrandr \
    libxfixes \
    libxdamage \
    libxcursor \
    libxtst \
    # 图形编码库
    libjpeg-turbo \
    libpng \
    libwebp \
    # 网络和安全库
    openssl \
    nettle \
    # KasmVNC运行依赖
    libvncserver \
    libvncclient \
    # 清理缓存
    && rm -rf /var/cache/apk/*

# 安装KasmVNC官方预编译包
# 注意：根据你的Alpine版本和架构选择正确的APK文件
# Alpine版本: 321 = 3.21.x, 320 = 3.20.x, 319 = 3.19.x, 318 = 3.18.x
# 架构: x86_64 (Intel/AMD) 或 aarch64 (ARM)
RUN wget -q https://github.com/kasmtech/KasmVNC/releases/download/v1.4.0/kasmvncserver_alpine_321_1.4.0_x86_64.apk -O /tmp/kasmvnc.apk && \
    apk add --allow-untrusted /tmp/kasmvnc.apk && \
    rm /tmp/kasmvnc.apk

# 设置英文语言环境
RUN apk add --no-cache locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.UTF-8 en_GB.UTF-8 \
    && rm -rf /var/cache/apk/*

# 创建必要的目录结构
RUN mkdir -p \
    /var/log/supervisor \
    /etc/supervisor/conf.d \
    /root/.vnc \
    /root/.fluxbox \
    /root/.mozilla \
    /data \
    /data/downloads \
    /data/bookmarks \
    /data/cache \
    /data/config \
    /data/tmp \
    /data/backups \
    && chmod -R 777 /data

# 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
COPY init-storage.sh /usr/local/bin/init-storage.sh
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/*.sh

# 创建Firefox配置模板
RUN mkdir -p /etc/firefox/template && \
    cat > /etc/firefox/template/prefs.js << 'EOF'
// Firefox preferences for containerized environment
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
user_pref("browser.tabs.remote.autostart", false);
user_pref("browser.tabs.remote.autostart.2", false);
EOF

# 创建默认书签文件
RUN cat > /data/bookmarks/bookmarks.html << 'EOF'
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Menu</H1>
<DL><p>
    <DT><H3 ADD_DATE="1640995200" LAST_MODIFIED="1640995200">Favorites</H3>
    <DL><p>
        <DT><A HREF="https://www.google.com" ADD_DATE="1640995200">Google</A>
        <DT><A HREF="https://github.com" ADD_DATE="1640995200">GitHub</A>
        <DT><A HREF="https://stackoverflow.com" ADD_DATE="1640995200">Stack Overflow</A>
    </DL><p>
</DL><p>
EOF

# 设置简单的Fluxbox菜单
RUN echo '[begin] (fluxbox)' > /root/.fluxbox/menu && \
    echo '[exec] (Firefox) {firefox}' >> /root/.fluxbox/menu && \
    echo '[exec] (Terminal) {xterm}' >> /root/.fluxbox/menu && \
    echo '[separator]' >> /root/.fluxbox/menu && \
    echo '[exit] (Exit)' >> /root/.fluxbox/menu && \
    echo '[end]' >> /root/.fluxbox/menu

# 配置Fluxbox以自动启动Firefox
RUN echo 'firefox &' > /root/.fluxbox/startup && \
    echo 'exec fluxbox' >> /root/.fluxbox/startup

# 暴露端口
# KasmVNC RFB端口 (传统VNC客户端)
EXPOSE 5901
# KasmVNC WebSocket端口 (网页客户端)
EXPOSE 7860

# 数据卷
VOLUME ["/data"]

# 容器启动入口
ENTRYPOINT ["/usr/local/bin/start.sh"]
