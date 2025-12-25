#!/usr/bin/env sh
set -e

echo "[entrypoint] genpac-runner 启动中..."

# --------------------------
# 设置时区
# --------------------------
if [ -n "$TZ" ]; then
  echo "[entrypoint] 设置时区为: $TZ"
  cp /usr/share/zoneinfo/$TZ /etc/localtime || true
fi

# 确保 update.sh 可执行
chmod +x /update.sh

# --------------------------
# 启动时立即生成一次 PAC
# --------------------------
echo "[entrypoint] 启动时立即生成 PAC"
/update.sh || true

# --------------------------
# 配置 cron 定时任务
# --------------------------
if [ -n "$CRON_SCHEDULE" ]; then
    echo "[entrypoint] 设置 cron 规则: $CRON_SCHEDULE"
    # 动态生成 crontab
    echo "$CRON_SCHEDULE /update.sh >> /data/cron.log 2>&1" > /etc/crontabs/root
fi

# --------------------------
# 启动 cron
# --------------------------
echo "[entrypoint] 启动 cron 服务"
crond

# --------------------------
# 启动 HTTP 服务，仅暴露 /proxy.pac
# UTF-8 显示，默认浏览器 inline
# --------------------------
echo "[entrypoint] 启动 HTTP 服务，监听 8080"

# 这里使用 Python 简单服务
exec python3 -u /serve_proxy.py
