#!/usr/bin/env sh
# --------------------------------------------------
# PAC 更新脚本（最终版）
#
# 模式说明：
#
# 【模式 A】配置了 GFWLIST_URL
#   - 使用 genpac
#   - 不注入自定义规则
#   - genpac 全权负责 FindProxyForURL
#
# 【模式 B】未配置 GFWLIST_URL
#   - 不使用 genpac
#   - 使用用户自定义规则
#   - 默认走代理
#
# --------------------------------------------------

set -e

WORKDIR="${WORKDIR:-/data}"
OUT_FILE="${OUT_FILE:-$WORKDIR/proxy.pac}"

PAC_PROXY="${PAC_PROXY:-SOCKS5 127.0.0.1:1080; DIRECT}"
PAC_COMPRESS="${PAC_COMPRESS:-true}"

GFWLIST_URL="${GFWLIST_URL:-}"

PAC_BLOCK_LIST="${PAC_BLOCK_LIST:-}"
PAC_DIRECT_LIST="${PAC_DIRECT_LIST:-}"

WEBHOOK_SUCCESS_URL="${WEBHOOK_SUCCESS_URL:-}"
WEBHOOK_SUCCESS_OPTIONS="${WEBHOOK_SUCCESS_OPTIONS:-}"
WEBHOOK_FAILURE_URL="${WEBHOOK_FAILURE_URL:-}"
WEBHOOK_FAILURE_OPTIONS="${WEBHOOK_FAILURE_OPTIONS:-}"

mkdir -p "$WORKDIR"

# ---------------- 工具函数 ----------------

log() {
  echo "[$(date '+%F %T')] $1"
}

notify_webhook() {
  local url="$1"
  shift
  [ -z "$url" ] && return
  curl -s -X POST -H "Content-Type: application/json" -d "$*" "$url" || true
}

fail() {
  log "FAILED"
  notify_webhook "$WEBHOOK_FAILURE_URL" "$WEBHOOK_FAILURE_OPTIONS"
  exit 1
}

trap fail ERR

# 去空格 + 拆分
normalize_list() {
  echo "$1" \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed '/^$/d'
}

# 转成 JS 数组
to_js_array() {
  normalize_list "$1" \
    | sed 's/^/"/;s/$/"/' \
    | paste -sd,
}

# ==================================================
# START
# ==================================================

log "START"

# ==================================================
# 模式 A：使用 genpac（有 GFWLIST_URL）
# ==================================================

if [ -n "$GFWLIST_URL" ]; then
  log "检测到 GFWLIST_URL，使用 genpac 模式"

  CMD="genpac --format=pac --pac-proxy=\"$PAC_PROXY\" --gfwlist-url=\"$GFWLIST_URL\""
  [ "$PAC_COMPRESS" = "true" ] && CMD="$CMD --pac-compress"

  sh -c "$CMD" > "$OUT_FILE"

  log "SUCCESS (genpac mode)"
  notify_webhook "$WEBHOOK_SUCCESS_URL" "$WEBHOOK_SUCCESS_OPTIONS"
  exit 0
fi

# ==================================================
# 模式 B：纯用户规则 PAC（无 genpac）
# ==================================================

log "未配置 GFWLIST_URL，使用纯用户规则 PAC"

block_js="$(to_js_array "$PAC_BLOCK_LIST")"
direct_js="$(to_js_array "$PAC_DIRECT_LIST")"

cat > "$OUT_FILE" <<EOF
// --------------------------------------------------
// User defined PAC (no genpac)
// --------------------------------------------------

function isMatch(host, list) {
    for (var i = 0; i < list.length; i++) {
        var rule = list[i];
        if (rule.indexOf('*') !== -1) {
            if (shExpMatch(host, rule)) return true;
        } else {
            if (host === rule || shExpMatch(host, "*." + rule)) return true;
        }
    }
    return false;
}

var BLOCK_LIST  = [${block_js}];
var DIRECT_LIST = [${direct_js}];
var PAC_PROXY   = "${PAC_PROXY}";

function FindProxyForURL(url, host) {

    // 0️⃣ 黑名单：直接丢弃
    if (BLOCK_LIST.length && isMatch(host, BLOCK_LIST)) {
        return "PROXY 0.0.0.0:0";
    }

    // 1️⃣ 强制直连
    if (DIRECT_LIST.length && isMatch(host, DIRECT_LIST)) {
        return "DIRECT";
    }

    // 2️⃣ 默认：走代理
    return PAC_PROXY;
}
EOF

log "SUCCESS (user rules mode)"
notify_webhook "$WEBHOOK_SUCCESS_URL" "$WEBHOOK_SUCCESS_OPTIONS"
