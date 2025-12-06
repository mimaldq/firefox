#!/bin/bash
echo "启动 Firefox，首页设置为 idx.google.com"
echo "请通过Web界面手动安装 'Auto Refresh Page' 插件来控制刷新。"

# 启动Firefox，并打开指定首页。--kiosk参数可使其全屏，不需要可移除。
exec firefox-esr --display=:99 --kiosk "https://idx.google.com"
