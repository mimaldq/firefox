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

# 验证中文字体是否已正确安装
echo "检查字体配置..."
fc-list | grep -i "chinese\|中文\|noto\|wqy" | head -10

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
        cat > "${FIREFOX_DATA_DIR}/firefox/default/prefs.js" << EOF
// Firefox中文配置
pref("intl.accept_languages", "zh-CN, zh, en-US, en");
pref("font.name.serif.zh-CN", "Noto Serif CJK SC");
pref("font.name.sans-serif.zh-CN", "Noto Sans CJK SC");
pref("font.name.monospace.zh-CN", "WenQuanYi Micro Hei Mono");
pref("intl.charset.default", "UTF-8");
pref("intl.charset.detector", "universal");
pref("browser.download.dir", "/data/downloads");
pref("browser.download.folderList", 2);
pref("browser.download.useDownloadDir", true);
pref("browser.helperApps.neverAsk.saveToDisk", "application/octet-stream");
EOF
        
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

# 设置Xvfb显示分辨率
echo "设置显示分辨率为: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
X_SCREEN="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24"

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
echo "通过noVNC访问: http://localhost:${NOVNC_PORT}"
echo "======================================="

# 设置日志目录权限
chmod 755 /var/log/supervisor

# 启动DBus
dbus-daemon --system --fork

# 启动supervisord（前台运行）
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf -n
