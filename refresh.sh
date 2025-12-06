#!/bin/bash
# refresh.sh - 专用于保持 idx.google.com 登录状态
TARGET_URL="https://idx.google.com"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-3600}" # 默认3600秒（1小时）

echo "=== 自动刷新脚本已启动 ==="
echo "目标地址：${TARGET_URL}"
echo "刷新间隔：${REFRESH_INTERVAL}秒"
echo "Web访问地址：https://你的空间地址.hf.space" # Hugging Face会提供此域名

while true; do
    CURRENT_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    echo "--- [${CURRENT_TIME}] 开始刷新周期 ---"
    
    # 启动Firefox访问目标网站，超时设置为60秒
    echo "正在加载页面..."
    timeout 60 firefox-esr --display=:99 "${TARGET_URL}" &
    FIREFOX_PID=$!
    
    # 等待页面加载和潜在的登录（首次运行时需要手动登录）
    sleep 60
    
    # 温和地结束Firefox进程，为下一轮释放内存（关键步骤！）
    echo "结束Firefox进程，释放资源..."
    kill $FIREFOX_PID 2>/dev/null
    wait $FIREFOX_PID 2>/dev/null
    
    echo "本轮刷新完成。等待 ${REFRESH_INTERVAL} 秒后开始下一轮..."
    echo ""
    sleep $REFRESH_INTERVAL
done