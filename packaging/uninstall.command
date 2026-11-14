#!/bin/bash
set -eu
if [ "$(/usr/bin/id -u)" -ne 0 ]; then
    echo '卸载罗技电量桥接需要管理员授权。请输入这台 Mac 的管理员密码。'
    exec /usr/bin/sudo /bin/bash "$0"
fi
# Stop the shared agent in all currently logged-in graphical sessions.
for user_uid in $(/usr/bin/who | /usr/bin/awk '{print $1}' | /usr/bin/sort -u | while IFS= read -r user_name; do /usr/bin/id -u "$user_name" 2>/dev/null || true; done); do
    /bin/launchctl bootout "gui/$user_uid/local.logitech.batterybridge" 2>/dev/null || true
done
/bin/rm -f '/Library/LaunchAgents/local.logitech.batterybridge.plist'
/bin/rm -rf '/Applications/LogitechBatteryBridge.app'
/usr/sbin/pkgutil --forget local.logitech.batterybridge.pkg 2>/dev/null || true
echo '已卸载程序并移除自动启动。用户目录中的日志和历史配置备份已保留。'
