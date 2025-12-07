# 第一阶段：构建Firefox
FROM alpine:edge AS firefox-builder
WORKDIR /tmp
# 安装Firefox及运行库[citation:7]
RUN apk update && \
    apk add --no-cache \
    firefox \
    ttf-freefont \
    dbus

# 第二阶段：构建最终运行镜像
FROM alpine:edge
WORKDIR /root

# 安装所有必需组件[citation:7]
RUN apk update && \
    apk add --no-cache \
    bash \
    fluxbox \
    xvfb \
    x11vnc \
    supervisor \
    novnc \
    websockify \
    ttf-freefont \
    font-noto-cjk

# 从构建阶段复制Firefox
COPY --from=firefox-builder /usr/lib/firefox /usr/lib/firefox
COPY --from=firefox-builder /usr/bin/firefox /usr/bin/firefox

# 确保Firefox可执行文件链接正确
RUN if [ -f /usr/bin/firefox ]; then \
        ln -sf /usr/bin/firefox /usr/local/bin/firefox 2>/dev/null || true; \
    elif [ -f /usr/lib/firefox/firefox ]; then \
        ln -sf /usr/lib/firefox/firefox /usr/bin/firefox 2>/dev/null || true; \
        ln -sf /usr/lib/firefox/firefox /usr/local/bin/firefox 2>/dev/null || true; \
    fi

# 复制启动脚本并准备环境
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    mkdir -p /usr/share/novnc && \
    cp -r /usr/share/webapps/novnc/* /usr/share/novnc/ 2>/dev/null || true && \
    mkdir -p /var/log

# 暴露noVNC和VNC的默认端口
EXPOSE 7860 5901

# 容器启动入口
ENTRYPOINT ["/entrypoint.sh"]
