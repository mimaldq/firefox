#!/bin/bash

# 设置环境变量
export DISPLAY=${DISPLAY:-:99}
export DISPLAY_WIDTH=${DISPLAY_WIDTH:-1280}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-720}
export VNC_PASSWORD=${VNC_PASSWORD:-admin}
export VNC_PORT=${VNC_PORT:-5900}
export NOVNC_PORT=${NOVNC_PORT:-7860}
export DATA_DIR=${DATA_DIR:-/data}
export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}

# 确保目录存在
mkdir -p /root/.vnc

# 创建VNC密码文件（如果不存在）
if [ ! -f /root/.vnc/passwd ]; then
    x11vnc -storepasswd "$VNC_PASSWORD" /root/.vnc/passwd > /dev/null 2>&1
    echo "VNC password set to: $VNC_PASSWORD"
fi

# 如果挂载了/data目录，则创建子目录
if [ -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR/downloads"
    mkdir -p "$DATA_DIR/firefox-profile"
    mkdir -p "$DATA_DIR/config"
    mkdir -p "$DATA_DIR/logs"
    
    # 如果/data/firefox-profile中有配置文件，使用它
    if [ -d "$DATA_DIR/firefox-profile" ] && [ "$(ls -A $DATA_DIR/firefox-profile 2>/dev/null)" ]; then
        rm -rf /root/.mozilla 2>/dev/null || true
        ln -sf "$DATA_DIR/firefox-profile" /root/.mozilla
    fi
fi

# 启动Xvfb（虚拟显示服务器）
Xvfb $DISPLAY -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24 -ac +extension GLX +render -noreset &

# 等待Xvfb启动
sleep 2

# 启动Fluxbox窗口管理器
fluxbox &

# 启动Firefox
firefox --display=$DISPLAY &

# 启动x11vnc VNC服务器
x11vnc -display $DISPLAY -forever -shared -rfbauth /root/.vnc/passwd -rfbport $VNC_PORT -bg -noxdamage -noxrecord -noxfixes -nopw -wait 5 -shared -permitfiletransfer -tightfilexfer &

# 启动noVNC WebSocket代理
/opt/novnc/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT &

# 启动Supervisor来管理进程
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# 保持容器运行
echo "======================================="
echo "Container is running!"
echo "======================================="
echo "Access noVNC at: http://localhost:${NOVNC_PORT}"
echo "VNC password: ${VNC_PASSWORD}"
if [ -d "$DATA_DIR" ]; then
    echo ""
    echo "Data directory mounted at: ${DATA_DIR}"
    echo "  - Downloads: ${DATA_DIR}/downloads"
    echo "  - Firefox profile: ${DATA_DIR}/firefox-profile"
fi
echo "======================================="

# 保持容器运行
tail -f /dev/null
