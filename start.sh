#!/bin/bash

# 由于目录结构调整，实际启动脚本已更改为start-with-nginx.sh
# 这个文件是为了向后兼容，实际调用新的启动脚本

echo "⚠️  注意：启动脚本已更新，现在使用start-with-nginx.sh"
echo "🔧 正在启动容器..."

# 检查新脚本是否存在
if [ -f "/usr/local/bin/start-with-nginx.sh" ]; then
    exec /usr/local/bin/start-with-nginx.sh
else
    echo "❌ 错误：找不到启动脚本 /usr/local/bin/start-with-nginx.sh"
    echo "💡 请检查Docker镜像构建是否成功"
    exit 1
fi
