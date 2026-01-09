# 阶段1: 构建器 - 仅准备静态资产
FROM alpine:latest as builder

# 安装临时构建工具（这些不会进入最终镜像）
RUN apk add --no-cache git openssl

# 克隆 noVNC 及其依赖（主要的静态资产）
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /assets/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /assets/novnc/utils/websockify

# （可选）在第一阶段生成SSL证书
RUN mkdir -p /assets/novnc/utils/ssl && \
    cd /assets/novnc/utils/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout self.pem -out self.pem -days 3650 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null

# 阶段2: 最终运行时镜像
FROM alpine:latest

LABEL org.opencontainers.image.title="Lightweight Firefox with noVNC"
LABEL org.opencontainers.image.description="Ultra-lightweight Firefox browser with noVNC web access and VNC password support"
LABEL org.opencontainers.image.licenses="MIT"

# 首先更新包管理器
RUN apk update

# 安装所有运行时依赖（分步安装，便于调试）
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    supervisor \
    bash \
    fluxbox \
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    # 中文字体包
    wqy-zenhei \
    wqy-microhei \
    font-noto \
    font-noto-cjk \
    font-noto-sans-sc \
    font-noto-serif-sc \
    # 字体配置工具
    fontconfig \
    # DBus支持
    dbus

# 清理缓存
RUN rm -rf /var/cache/apk/*

# 创建必要的目录结构
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d /root/.vnc

# 关键优化：从构建器阶段仅复制准备好的静态资产
COPY --from=builder /assets/novnc /opt/novnc

# 复制本地配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 设置noVNC默认跳转页面
RUN echo '<html><head><meta http-equiv="refresh" content="0;url=vnc.html"></head><body></body></html>' > /opt/novnc/index.html

# 为Firefox创建默认配置文件（如果/data/firefox没有挂载则使用这个）
RUN mkdir -p /default-firefox-profile && \
    mkdir -p /default-firefox-profile/firefox/default && \
    # 设置默认语言为中文优先，英文备用
    echo 'pref("intl.accept_languages", "zh-CN, zh, en-US, en");' > /default-firefox-profile/firefox/default/prefs.js && \
    # 设置字体偏好
    echo 'pref("font.name.serif.zh-CN", "Noto Serif CJK SC");' >> /default-firefox-profile/firefox/default/prefs.js && \
    echo 'pref("font.name.sans-serif.zh-CN", "Noto Sans CJK SC");' >> /default-firefox-profile/firefox/default/prefs.js && \
    echo 'pref("font.name.monospace.zh-CN", "WenQuanYi Micro Hei Mono");' >> /default-firefox-profile/firefox/default/prefs.js && \
    # 设置编码支持
    echo 'pref("intl.charset.default", "UTF-8");' >> /default-firefox-profile/firefox/default/prefs.js && \
    echo 'pref("intl.charset.detector", "universal");' >> /default-firefox-profile/firefox/default/prefs.js && \
    # 下载目录设置
    echo 'pref("browser.download.dir", "/data/downloads");' >> /default-firefox-profile/firefox/default/prefs.js && \
    echo 'pref("browser.download.folderList", 2);' >> /default-firefox-profile/firefox/default/prefs.js && \
    echo 'pref("browser.download.useDownloadDir", true);' >> /default-firefox-profile/firefox/default/prefs.js && \
    # 其他基本设置
    echo '{"HomePage":"about:blank","StartPage":"about:blank"}' > /default-firefox-profile/firefox/default/user.js

# 创建自定义字体配置文件
RUN mkdir -p /etc/fonts/conf.d && \
    cat > /etc/fonts/conf.d/99-local.conf << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- 添加中文字体目录 -->
  <dir>/usr/share/fonts/wqy-zenhei</dir>
  <dir>/usr/share/fonts/wqy-microhei</dir>
  <dir>/usr/share/fonts/noto</dir>
  <dir>/usr/share/fonts/noto-cjk</dir>

  <!-- 中文别名定义 -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans CJK SC</family>
      <family>WenQuanYi Micro Hei</family>
      <family>WenQuanYi Zen Hei</family>
      <family>DejaVu Sans</family>
    </prefer>
  </alias>

  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif CJK SC</family>
      <family>WenQuanYi Zen Hei</family>
      <family>DejaVu Serif</family>
    </prefer>
  </alias>

  <alias>
    <family>monospace</family>
    <prefer>
      <family>WenQuanYi Micro Hei Mono</family>
      <family>Noto Sans Mono CJK SC</family>
      <family>DejaVu Sans Mono</family>
    </prefer>
  </alias>

  <!-- 调整中文渲染 -->
  <match target="font">
    <test name="lang" compare="contains">
      <string>zh</string>
      <string>zh-cn</string>
      <string>zh-tw</string>
      <string>ja</string>
      <string>ko</string>
    </test>
    <edit name="antialias" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="autohint" mode="assign">
      <bool>false</bool>
    </edit>
  </match>
</fontconfig>
EOF

# 更新字体缓存
RUN fc-cache -fv

# 创建X11相关目录
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# 暴露端口
EXPOSE 7860 5900

# 声明挂载卷
VOLUME /data

# 启动入口
CMD ["/usr/local/bin/start.sh"]
