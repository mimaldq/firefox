#!/bin/bash
set -e

echo "===== Firefox + noVNC 容器启动中 ====="

# 创建必要的目录
mkdir -p ~/.vnc
mkdir -p /var/log
mkdir -p ~/.fluxbox

# VNC密码设置（非交互方式）
if [ -n "$VNC_PASSWORD" ]; then
    echo "正在设置VNC密码..."
    
    # 方法1：使用vncpasswd（如果可用）
    if command -v vncpasswd > /dev/null 2>&1; then
        echo "$VNC_PASSWORD" | vncpasswd -f > ~/.vnc/passwd 2>/dev/null
    fi
    
    # 方法2：使用x11vnc的非交互模式
    if [ ! -f ~/.vnc/passwd ] || [ ! -s ~/.vnc/passwd ]; then
        echo "使用x11vnc创建密码文件..."
        # 创建临时文件存储密码
        echo "$VNC_PASSWORD" > /tmp/vncpwd.txt
        # 使用非交互模式创建密码文件
        x11vnc -storepasswd "$VNC_PASSWORD" ~/.vnc/passwd 2>&1 || true
        
        # 如果还是失败，使用备用方案
        if [ ! -f ~/.vnc/passwd ]; then
            echo "使用备用密码创建方法..."
            # 创建一个基本的密码文件（可能需要trim到8个字符）
            TRUNC_PWD=$(echo "$VNC_PASSWORD" | cut -c1-8)
            echo "$TRUNC_PWD" > ~/.vnc/passwd.tmp
            x11vnc -storepasswd "$TRUNC_PWD" ~/.vnc/passwd 2>&1 || true
        fi
    fi
    
    # 检查密码文件是否创建成功
    if [ -f ~/.vnc/passwd ] && [ -s ~/.vnc/passwd ]; then
        chmod 600 ~/.vnc/passwd
        VNC_AUTH_OPT="-passwdfile ~/.vnc/passwd"
        echo "✓ VNC密码设置成功"
    else
        echo "⚠ VNC密码文件创建失败，使用无密码连接"
        VNC_AUTH_OPT="-nopw"
    fi
else
    echo "⚠ 未设置VNC_PASSWORD，使用无密码连接"
    VNC_AUTH_OPT="-nopw"
fi

# 显示配置信息
echo "配置信息:"
echo "  noVNC端口: ${NOVNC_PORT}"
echo "  VNC端口: ${VNC_PORT}"
echo "  分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}"

# 生成Supervisor配置文件
cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
logfile_maxbytes=1MB
logfile_backups=1
loglevel=info
pidfile=/tmp/supervisord.pid

[program:xvfb]
command=Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} -ac +extension GLX +render -noreset
autorestart=true
startsecs=2
startretries=10
stdout_logfile=/var/log/xvfb.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/xvfb.err.log
stderr_logfile_maxbytes=1MB

[program:fluxbox]
command=fluxbox
autorestart=true
environment=DISPLAY=:0
startsecs=3
startretries=10
stdout_logfile=/var/log/fluxbox.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/fluxbox.err.log
stderr_logfile_maxbytes=1MB

[program:x11vnc]
command=x11vnc -display :0 -forever -shared -rfbport ${VNC_PORT} ${VNC_AUTH_OPT} -noxdamage -bg -o /var/log/x11vnc.log
autorestart=true
startsecs=3
startretries=10
stdout_logfile=/var/log/x11vnc.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/x11vnc.err.log
stderr_logfile_maxbytes=1MB

[program:novnc]
command=websockify --web /usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT}
autorestart=true
startsecs=3
startretries=10
stdout_logfile=/var/log/novnc.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/novnc.err.log
stderr_logfile_maxbytes=1MB
EOF

# 创建Fluxbox配置
cat > ~/.fluxbox/init << EOF
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: false
background: none
[begin] (fluxbox)
[exec] (Firefox) {firefox --display=:0 --no-remote --new-instance --width=${DISPLAY_WIDTH} --height=${DISPLAY_HEIGHT}}
[end]
EOF

# 设置noVNC首页
cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html

echo "================================"
echo "容器启动完成!"
echo "访问地址: http://<主机IP>:${NOVNC_PORT}"
echo "VNC端口: ${VNC_PORT}"
[ -n "$VNC_PASSWORD" ] && [ -f ~/.vnc/passwd ] && echo "VNC密码: 已设置"
echo "================================"

# 启动所有服务
exec /usr/bin/supervisord -c /etc/supervisord.conf
