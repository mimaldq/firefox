# 基于最轻量的Alpine Linux
FROM alpine:latest

# 安装所有必要组件：浏览器、虚拟显示、VNC、Web服务和进程管理
RUN apk add --no-cache \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    bash \
    curl \
    ttf-freefont \
    # 清理缓存以减小镜像体积
    && rm -rf /var/cache/apk/* \
    # 为noVNC创建便捷链接
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 创建非root用户（安全要求）
RUN adduser -D -u 1000 firefoxuser
USER firefoxuser
WORKDIR /home/firefoxuser

# 复制配置文件（supervisor配置和刷新脚本）
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
RUN chmod +x ./refresh.sh  # 赋予脚本执行权限

# Hugging Face Spaces 要求暴露的端口，必须与后续配置的端口一致
EXPOSE 7860

# 使用Supervisor启动所有服务
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]