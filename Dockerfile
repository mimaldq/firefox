# 第一阶段：构建阶段 (Builder)
FROM alpine:latest AS builder

# 安装所有必要的包
RUN apk add --no-cache \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    bash \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# 第二阶段：运行阶段 (Runner) - 我们只从这里开始复制
FROM alpine:latest

# 只安装最最基础的运行时依赖
# 注意：这里不再安装 firefox-esr 等大型包
RUN apk add --no-cache \
    # 基础库
    bash \
    # Firefox 运行时可能需要的少量核心库（根据第一阶段安装情况精简）
    libstdc++ \
    gcompat \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# 从 builder 阶段精确复制我们需要的应用程序文件
COPY --from=builder /usr/bin/firefox-esr /usr/bin/firefox-esr
COPY --from=builder /usr/lib/firefox-esr/ /usr/lib/firefox-esr/
COPY --from=builder /usr/share/firefox-esr/ /usr/share/firefox-esr/

COPY --from=builder /usr/bin/xvfb-run /usr/bin/xvfb-run
COPY --from=builder /usr/bin/xvfb /usr/bin/xvfb
COPY --from=builder /usr/bin/x11vnc /usr/bin/x11vnc
COPY --from=builder /usr/share/novnc/ /usr/share/novnc/
COPY --from=builder /usr/bin/websockify /usr/bin/websockify
COPY --from=builder /usr/bin/supervisord /usr/bin/supervisord
COPY --from=builder /etc/supervisord.conf /etc/supervisord.conf
COPY --from=builder /etc/supervisor/ /etc/supervisor/

# 复制可能需要的库文件（这是一个常见痛点，可能需要反复调试）
COPY --from=builder /usr/lib/ /usr/lib/

# 创建用户和目录（逻辑与之前一致）
RUN adduser -D -u 1000 firefoxuser \
    && mkdir -p /home/firefoxuser/.mozilla/firefox/default-release \
    && chown -R firefoxuser:firefoxuser /home/firefoxuser \
    # 创建必要的符号链接
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

USER firefoxuser
WORKDIR /home/firefoxuser

# 复制你自己的配置文件
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
COPY --chown=firefoxuser:firefoxuser firefox-prefs.js ./
RUN chmod +x ./refresh.sh

EXPOSE 7860
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
