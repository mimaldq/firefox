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
    # 字体包
    font-dejavu \
    font-noto-cjk \
    font-misc-misc \
    font-cursor-misc \
    # 字体配置工具（必需）
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

# 创建伪装首页目录结构
RUN mkdir -p /opt/www && \
    mkdir -p /opt/novnc-real

# 移动noVNC文件到隐藏目录
RUN mv /opt/novnc/* /opt/novnc-real/ && \
    rm -rf /opt/novnc && \
    mv /opt/novnc-real /opt/novnc && \
    ln -s /opt/novnc /opt/www/vnc

# 创建伪装首页
RUN cat > /opt/www/index.html << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>系统维护中</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif;
        }
        
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: white;
        }
        
        .maintenance-container {
            text-align: center;
            padding: 3rem;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 800px;
            margin: 2rem;
        }
        
        .logo {
            font-size: 3.5rem;
            margin-bottom: 1.5rem;
            animation: float 3s ease-in-out infinite;
        }
        
        @keyframes float {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-10px); }
        }
        
        h1 {
            font-size: 2.8rem;
            margin-bottom: 1rem;
            background: linear-gradient(45deg, #fff, #f0f0f0);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        
        .status {
            display: inline-block;
            padding: 0.5rem 1.5rem;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 30px;
            margin-bottom: 2rem;
            font-size: 1.1rem;
            font-weight: 500;
        }
        
        .status.active {
            color: #4ade80;
        }
        
        .status::before {
            content: "●";
            margin-right: 0.5rem;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        .info-box {
            background: rgba(255, 255, 255, 0.08);
            border-radius: 15px;
            padding: 2rem;
            margin: 2rem 0;
            text-align: left;
        }
        
        .info-box h3 {
            color: #d1d5db;
            margin-bottom: 1rem;
            font-size: 1.3rem;
        }
        
        .info-box ul {
            list-style: none;
            padding: 0;
        }
        
        .info-box li {
            padding: 0.5rem 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            display: flex;
            justify-content: space-between;
        }
        
        .info-box li:last-child {
            border-bottom: none;
        }
        
        .progress-container {
            margin: 2rem 0;
        }
        
        .progress-bar {
            height: 6px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 3px;
            overflow: hidden;
            margin-top: 0.5rem;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4ade80, #3b82f6);
            width: 76%;
            border-radius: 3px;
            animation: progress 2s ease-out;
        }
        
        @keyframes progress {
            from { width: 0; }
            to { width: 76%; }
        }
        
        .contact {
            margin-top: 2rem;
            padding-top: 2rem;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .contact p {
            margin: 0.5rem 0;
            color: #d1d5db;
        }
        
        .timer {
            font-size: 2rem;
            font-weight: bold;
            margin: 1rem 0;
            color: #fbbf24;
        }
        
        .hidden-admin {
            margin-top: 2rem;
            opacity: 0.3;
            font-size: 0.9rem;
            color: #9ca3af;
        }
        
        .hidden-admin a {
            color: #9ca3af;
            text-decoration: none;
        }
        
        .hidden-admin a:hover {
            color: #fff;
        }
        
        @media (max-width: 768px) {
            .maintenance-container {
                padding: 2rem 1.5rem;
                margin: 1rem;
            }
            
            h1 {
                font-size: 2rem;
            }
            
            .logo {
                font-size: 2.5rem;
            }
        }
    </style>
</head>
<body>
    <div class="maintenance-container">
        <div class="logo">🔧</div>
        <h1>系统维护升级中</h1>
        <div class="status active">维护进行中</div>
        
        <div class="info-box">
            <h3>系统状态</h3>
            <ul>
                <li>
                    <span>数据库服务</span>
                    <span style="color:#4ade80">● 正常运行</span>
                </li>
                <li>
                    <span>API网关</span>
                    <span style="color:#4ade80">● 正常运行</span>
                </li>
                <li>
                    <span>文件存储</span>
                    <span style="color:#f59e0b">◐ 维护中</span>
                </li>
                <li>
                    <span>用户认证</span>
                    <span style="color:#4ade80">● 正常运行</span>
                </li>
                <li>
                    <span>缓存服务</span>
                    <span style="color:#4ade80">● 正常运行</span>
                </li>
            </ul>
        </div>
        
        <div class="progress-container">
            <p>系统升级进度</p>
            <div class="progress-bar">
                <div class="progress-fill"></div>
            </div>
        </div>
        
        <div class="timer" id="countdown">00:00:00</div>
        
        <div class="info-box">
            <h3>维护详情</h3>
            <p>本次维护主要进行系统安全升级和性能优化，预计持续时间为4小时。维护期间，部分功能可能暂时无法使用。给您带来的不便，敬请谅解。</p>
        </div>
        
        <div class="contact">
            <p>📧 技术支持邮箱: support@example.com</p>
            <p>📞 紧急联系电话: +86 400-123-4567</p>
            <p>⏰ 预计恢复时间: 今日 22:00</p>
        </div>
        
        <div class="hidden-admin">
            <a href="/vnc/vnc.html" style="text-decoration:none;color:inherit">.</a>
        </div>
    </div>
    
    <script>
        // 倒计时功能
        function updateCountdown() {
            const now = new Date();
            const target = new Date();
            target.setHours(22, 0, 0, 0); // 设置为今天22:00
            
            if (now > target) {
                target.setDate(target.getDate() + 1); // 如果已经过了22:00，设为明天
            }
            
            const diff = target - now;
            
            const hours = Math.floor(diff / (1000 * 60 * 60));
            const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
            const seconds = Math.floor((diff % (1000 * 60)) / 1000);
            
            document.getElementById('countdown').textContent = 
                `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        }
        
        // 初始更新
        updateCountdown();
        
        // 每秒更新一次
        setInterval(updateCountdown, 1000);
        
        // 随机更新状态指示器
        function updateStatusIndicators() {
            const indicators = document.querySelectorAll('.status span');
            indicators.forEach(indicator => {
                if (Math.random() > 0.95) {
                    const colors = ['#4ade80', '#f59e0b', '#ef4444'];
                    const statuses = ['正常运行', '维护中', '故障'];
                    const randomIndex = Math.floor(Math.random() * 3);
                    
                    indicator.style.color = colors[randomIndex];
                    indicator.textContent = `● ${statuses[randomIndex]}`;
                    
                    // 2秒后恢复
                    setTimeout(() => {
                        indicator.style.color = '#4ade80';
                        indicator.textContent = '● 正常运行';
                    }, 2000);
                }
            });
        }
        
        setInterval(updateStatusIndicators, 5000);
        
        // 进度条动画
        let progress = 76;
        setInterval(() => {
            const progressBar = document.querySelector('.progress-fill');
            if (progress < 100) {
                progress += 0.1;
                progressBar.style.width = `${progress}%`;
            }
        }, 10000);
    </script>
</body>
</html>
EOF

# 设置noVNC默认跳转页面
RUN echo '<html><head><meta http-equiv="refresh" content="0;url=vnc.html"></head><body></body></html>' > /opt/novnc/index.html

# 为Firefox创建默认配置文件（如果/data/firefox没有挂载则使用这个）
RUN mkdir -p /default-firefox-profile && \
    mkdir -p /default-firefox-profile/firefox/default && \
    # 设置默认语言为中文优先，英文备用
    echo 'pref("intl.accept_languages", "zh-CN, zh, en-US, en");' > /default-firefox-profile/firefox/default/prefs.js && \
    # 设置字体偏好 - 使用Noto CJK字体
    echo 'pref("font.name.serif.zh-CN", "Noto Serif CJK SC");' >> /default-firefox-profile/firefox/default/prefs.js && \
    echo 'pref("font.name.sans-serif.zh-CN", "Noto Sans CJK SC");' >> /default-firefox-profile/firefox/default/prefs.js && \
    echo 'pref("font.name.monospace.zh-CN", "Noto Sans Mono CJK SC");' >> /default-firefox-profile/firefox/default/prefs.js && \
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
  <!-- 添加字体目录 -->
  <dir>/usr/share/fonts/dejavu</dir>
  <dir>/usr/share/fonts/noto-cjk</dir>
  <dir>/usr/share/fonts/misc</dir>
  <dir>/usr/share/fonts/cursor</dir>

  <!-- 字体别名定义 -->
  <alias>
    <family>sans-serif</family>
    <prefer>
      <family>Noto Sans CJK SC</family>
      <family>Noto Sans CJK TC</family>
      <family>Noto Sans CJK JP</family>
      <family>Noto Sans CJK KR</family>
      <family>DejaVu Sans</family>
    </prefer>
  </alias>

  <alias>
    <family>serif</family>
    <prefer>
      <family>Noto Serif CJK SC</family>
      <family>Noto Serif CJK TC</family>
      <family>Noto Serif CJK JP</family>
      <family>Noto Serif CJK KR</family>
      <family>DejaVu Serif</family>
    </prefer>
  </alias>

  <alias>
    <family>monospace</family>
    <prefer>
      <family>Noto Sans Mono CJK SC</family>
      <family>Noto Sans Mono CJK TC</family>
      <family>Noto Sans Mono CJK JP</family>
      <family>Noto Sans Mono CJK KR</family>
      <family>DejaVu Sans Mono</family>
    </prefer>
  </alias>

  <!-- 调整中日韩字体渲染 -->
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
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
  </match>
</fontconfig>
EOF

# 更新字体缓存
RUN fc-cache -fv

# 创建X11相关目录
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# 创建新的启动脚本
RUN cat > /usr/local/bin/start-with-nginx.sh << 'EOF'
#!/bin/bash

# 设置环境变量
export DISPLAY=${DISPLAY:-:99}
export DISPLAY_WIDTH=${DISPLAY_WIDTH:-1280}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-720}
export VNC_PASSWORD=${VNC_PASSWORD:-admin}
export VNC_PORT=${VNC_PORT:-5900}
export NOVNC_PORT=${NOVNC_PORT:-7860}
export DATA_DIR=${DATA_DIR:-/data}
export LANG=${LANG:-zh_CN.UTF-8}
export LC_ALL=${LC_ALL:-zh_CN.UTF-8}
export LANGUAGE=${LANGUAGE:-zh_CN:zh}
export QT_IM_MODULE=${QT_IM_MODULE:-xim}
export GTK_IM_MODULE=${GTK_IM_MODULE:-xim}

# 确保目录存在
mkdir -p /root/.vnc
mkdir -p /var/log/supervisor

# 验证字体是否已正确安装
echo "检查字体配置..."
fc-list | grep -i "noto\|dejavu" | head -10

# 更新字体缓存（确保运行时字体可用）
fc-cache -fv

# 创建VNC密码文件（如果不存在）
if [ ! -f /root/.vnc/passwd ]; then
    x11vnc -storepasswd "$VNC_PASSWORD" /root/.vnc/passwd > /dev/null 2>&1
    echo "VNC密码设置为: $VNC_PASSWORD"
fi

# 设置 Firefox 配置和本地存储目录
FIREFOX_DATA_DIR="${DATA_DIR}/firefox"

# 如果/data/firefox目录不存在或为空，使用默认配置
if [ ! -d "${FIREFOX_DATA_DIR}" ] || [ -z "$(ls -A ${FIREFOX_DATA_DIR} 2>/dev/null)" ]; then
    echo "使用默认Firefox配置文件..."
    # 确保目标目录存在
    mkdir -p "${FIREFOX_DATA_DIR}"
    # 复制默认配置到/data/firefox
    cp -r /default-firefox-profile/* "${FIREFOX_DATA_DIR}/" 2>/dev/null || true
    
    # 如果复制失败，创建基本结构
    if [ ! -d "${FIREFOX_DATA_DIR}/firefox/default" ]; then
        mkdir -p "${FIREFOX_DATA_DIR}/firefox/default"
        # 创建中文配置的prefs.js
        cat > "${FIREFOX_DATA_DIR}/firefox/default/prefs.js" << EOPREFS
// Firefox中文配置
pref("intl.accept_languages", "zh-CN, zh, en-US, en");
pref("font.name.serif.zh-CN", "Noto Serif CJK SC");
pref("font.name.sans-serif.zh-CN", "Noto Sans CJK SC");
pref("font.name.monospace.zh-CN", "Noto Sans Mono CJK SC");
pref("intl.charset.default", "UTF-8");
pref("intl.charset.detector", "universal");
pref("browser.download.dir", "/data/downloads");
pref("browser.download.folderList", 2);
pref("browser.download.useDownloadDir", true);
pref("browser.helperApps.neverAsk.saveToDisk", "application/octet-stream");
EOPREFS
        
        # 创建user.js
        echo '{"HomePage":"about:blank","StartPage":"about:blank"}' > "${FIREFOX_DATA_DIR}/firefox/default/user.js"
    fi
else
    echo "使用现有Firefox配置文件..."
    # 确保现有配置文件中有中文设置
    if [ -f "${FIREFOX_DATA_DIR}/firefox/default/prefs.js" ]; then
        # 检查是否已有中文语言设置
        if ! grep -q "zh-CN" "${FIREFOX_DATA_DIR}/firefox/default/prefs.js"; then
            echo "向现有配置添加中文支持..."
            echo 'pref("intl.accept_languages", "zh-CN, zh, en-US, en");' >> "${FIREFOX_DATA_DIR}/firefox/default/prefs.js"
        fi
    fi
fi

# 清理旧的.mozilla目录并创建软链接
rm -rf /root/.mozilla 2>/dev/null || true
ln -sf "${FIREFOX_DATA_DIR}" /root/.mozilla

# 创建其他必要的子目录
mkdir -p "${DATA_DIR}/downloads"
mkdir -p "${DATA_DIR}/logs"

# 启动Supervisor来管理所有进程
echo "======================================="
echo "启动容器配置:"
echo "======================================="
echo "显示: $DISPLAY"
echo "分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "VNC端口: $VNC_PORT"
echo "noVNC端口: $NOVNC_PORT"
echo "VNC密码: $VNC_PASSWORD"
echo "语言环境: $LANG"
echo "Firefox数据目录: ${FIREFOX_DATA_DIR}"
echo "下载目录: ${DATA_DIR}/downloads"
echo "======================================="
echo "访问伪装首页: http://localhost:${NOVNC_PORT}"
echo "访问VNC页面: http://localhost:${NOVNC_PORT}/vnc/vnc.html"
echo "======================================="

# 设置日志目录权限
chmod 755 /var/log/supervisor

# 启动DBus
dbus-daemon --system --fork

# 启动supervisord（前台运行）
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n
EOF

RUN chmod +x /usr/local/bin/start-with-nginx.sh

# 暴露端口
EXPOSE 7860 5900

# 声明挂载卷
VOLUME /data

# 启动入口（使用新的启动脚本）
CMD ["/usr/local/bin/start-with-nginx.sh"]
