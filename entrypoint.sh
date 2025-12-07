#!/bin/bash
set -e

echo "===== Firefox + noVNC 容器启动中 ====="

# 设置默认环境变量（可在运行容器时用 -e 覆盖）
: ${NOVNC_PORT:=7860}
: ${VNC_PORT:=5901}
: ${DISPLAY_WIDTH:=1280}
: ${DISPLAY_HEIGHT:=720}
: ${DISPLAY_DEPTH:=24}

echo "配置信息:"
echo "  noVNC端口: ${NOVNC_PORT}"
echo "  VNC端口: ${VNC_PORT}"
echo "  分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}"

# 创建必要的目录
mkdir -p ~/.fluxbox /var/log

# 检查Firefox，如果意外缺失则尝试安装
if ! command -v firefox > /dev/null 2>&1; then
    echo "正在安装Firefox..."
    apk add --no-cache firefox 2>/dev/null || true
fi

# 生成Supervisor配置文件（管理多个后台进程）
cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true

[program:xvfb]
command=Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}
autorestart=true
stdout_logfile=/var/log/xvfb.log
stderr_logfile=/var/log/xvfb.err.log

[program:fluxbox]
command=fluxbox
autorestart=true
environment=DISPLAY=:0
stdout_logfile=/var/log/fluxbox.log
stderr_logfile=/var/log/fluxbox.err.log

# 核心：启动x11vnc，使用 -nopw 参数强制无密码连接[citation:2]
[program:x11vnc]
command=x11vnc -display :0 -forever -shared -rfbport ${VNC_PORT} -nopw -noxdamage
autorestart=true
stdout_logfile=/var/log/x11vnc.log
stderr_logfile=/var/log/x11vnc.err.log

# 核心：启动noVNC，将VNC端口转换为WebSocket[citation:2][citation:5]
[program:novnc]
command=websockify --web /usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT}
autorestart=true
stdout_logfile=/var/log/novnc.log
stderr_logfile=/var/log/novnc.err.log
EOF

# 创建极简的Fluxbox桌面配置，自动启动Firefox
cat > ~/.fluxbox/init << 'EOF'
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: false
background: none
[begin] (fluxbox)
[exec] (Firefox) {firefox --display=:0 --no-remote --new-instance}
[end]
EOF

# 设置noVNC的默认访问页面
if [ -f /usr/share/novnc/vnc.html ]; then
    cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html
elif [ -f /usr/share/webapps/novnc/vnc.html ]; then
    cp /usr/share/webapps/novnc/vnc.html /usr/share/novnc/index.html
fi

echo "================================"
echo "容器启动完成!"
echo "访问地址: http://<你的主机IP>:${NOVNC_PORT}"
echo "无密码访问"
echo "================================"

# 启动所有服务
exec /usr/bin/supervisord -c /etc/supervisord.conf
