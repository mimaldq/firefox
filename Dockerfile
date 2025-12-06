FROM debian:bullseye-slim

# 安装所有必要软件包（使用 --no-install-recommends 避免安装非必须推荐包）
RUN apt-get update && apt-get install -y --no-install-recommends \
    firefox-esr \
    xvfb \
    x11vnc \
    websockify \
    novnc \
    supervisor \
    bash \
    # 使用较小的字体包
    fonts-dejavu-core \
    # 清理缓存以减小镜像体积
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 创建非root用户和必要的目录
RUN useradd -m -u 1000 -s /bin/bash firefoxuser \
    && mkdir -p /home/firefoxuser/.mozilla/firefox/default-release \
    && chown -R firefoxuser:firefoxuser /home/firefoxuser

USER firefoxuser
WORKDIR /home/firefoxuser

# 复制配置文件
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
COPY --chown=firefoxuser:firefoxuser firefox-prefs.js /home/firefoxuser/.mozilla/firefox/default-release/user.js

RUN chmod +x ./refresh.sh

# Hugging Face Spaces 强制要求暴露 7860 端口
EXPOSE 7860

# 使用Supervisor启动所有服务
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
