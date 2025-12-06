# 使用 Debian Slim 作为基础镜像，在体积和兼容性间取得平衡
FROM debian:bookworm-slim

# 安装必要软件包，使用 --no-install-recommends 避免安装非必需依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    procps \
    # 可选：中文字体支持，如果不需要可以移除
    fonts-wqy-microhei \
    # 清理缓存以减小镜像层
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# 创建非 root 用户
RUN useradd -m -u 1000 -s /bin/bash firefoxuser

# 设置工作目录和用户
WORKDIR /home/firefoxuser
USER firefoxuser

# 复制配置文件
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
# 注意：我们不再将 firefox-prefs.js 复制到固定位置，而是依赖挂载卷或容器首次运行时生成
# COPY --chown=firefoxuser:firefoxuser firefox-prefs.js /home/firefoxuser/.mozilla/firefox/profiles.ini

RUN chmod +x ./refresh.sh

# 暴露 Hugging Face Spaces 要求的端口
EXPOSE 7860

# 启动命令保持不变
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
