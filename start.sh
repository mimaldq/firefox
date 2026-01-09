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

# 确保目录存在
mkdir -p /root/.vnc
mkdir -p /var/log/supervisor

# 静默更新字体缓存
fc-cache -fv > /dev/null 2>&1

# 创建VNC密码文件（如果不存在）
if [ ! -f /root/.vnc/passwd ]; then
    x11vnc -storepasswd "$VNC_PASSWORD" /root/.vnc/passwd > /dev/null 2>&1
fi

# 设置 Firefox 配置和本地存储目录
FIREFOX_DATA_DIR="${DATA_DIR}/firefox"

# 如果/data/firefox目录不存在或为空，使用默认配置
if [ ! -d "${FIREFOX_DATA_DIR}" ] || [ -z "$(ls -A ${FIREFOX_DATA_DIR} 2>/dev/null)" ]; then
    # 确保目标目录存在
    mkdir -p "${FIREFOX_DATA_DIR}"
    # 静默复制默认配置
    cp -r /default-firefox-profile/* "${FIREFOX_DATA_DIR}/" 2>/dev/null || true
fi

# 清理旧的.mozilla目录并创建软链接
rm -rf /root/.mozilla 2>/dev/null || true
ln -sf "${FIREFOX_DATA_DIR}" /root/.mozilla

# 创建其他必要的子目录
mkdir -p "${DATA_DIR}/downloads"
mkdir -p "${DATA_DIR}/logs"

# 启动DBus
dbus-daemon --system --fork > /dev/null 2>&1

# 静默启动supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n
