#!/usr/bin/env sh
# --------------------------------------------------
# genpac 更新脚本
# 从 gfwlist 生成 PAC，并可选调用 webhook
# --------------------------------------------------

set -e

WORKDIR="${WORKDIR:-/data}"
OUT_FILE="${OUT_FILE:-$WORKDIR/proxy.pac}"

PAC_PROXY="${PAC_PROXY:-SOCKS5 127.0.0.1:1080; DIRECT}"
GFWLIST_URL="${GFWLIST_URL:-https://github.com/gfwlist/gfwlist/raw/master/gfwlist.txt}"
PAC_COMPRESS="${PAC_COMPRESS:-true}"
PAC_PRECISE="${PAC_PRECISE:-false}"

WEBHOOK_SUCCESS_URL="${WEBHOOK_SUCCESS_URL:-}"
WEBHOOK_SUCCESS_OPTIONS="${WEBHOOK_SUCCESS_OPTIONS:-}"
WEBHOOK_FAILURE_URL="${WEBHOOK_FAILURE_URL:-}"
WEBHOOK_FAILURE_OPTIONS="${WEBHOOK_FAILURE_OPTIONS:-}"

mkdir -p "$WORKDIR"

log() {
  echo "[$(date '+%F %T')] $1"
}

notify_webhook() {
  local url="$1"
  shift
  [ -z "$url" ] && return
  local data="$*"
  curl -s -X POST -H "Content-Type: application/json" -d "$data" "$url" || echo "Webhook failed"
}


fail() {
  log "FAILED"
  notify_webhook "$WEBHOOK_FAILURE_URL" "$WEBHOOK_FAILURE_OPTIONS"
  exit 1
}

trap fail ERR

log "START"

# 生成 PAC
CMD="genpac --format=pac --pac-proxy=\"$PAC_PROXY\" --gfwlist-url=\"$GFWLIST_URL\""
[ "$PAC_COMPRESS" = "true" ] && CMD="$CMD --pac-compress"
[ "$PAC_PRECISE" = "true" ] && CMD="$CMD --pac-precise"

sh -c "$CMD" > "$OUT_FILE"

log "SUCCESS"
notify_webhook "$WEBHOOK_SUCCESS_URL" "$WEBHOOK_SUCCESS_OPTIONS"

