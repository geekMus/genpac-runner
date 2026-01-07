#!/usr/bin/env sh
# --------------------------------------------------
# genpac 更新脚本（增强版）
#
# 支持：
# - PAC_DIRECT_LIST   强制直连
# - PAC_PROXY_LIST    强制代理
# - PAC_BLOCK_LIST    黑名单（PROXY 0.0.0.0:0）
# - 通配符 *.example.com
# - 自动去除列表空格
# - GFWLIST_URL 可选（不填则全代理）
# --------------------------------------------------

set -e

WORKDIR="${WORKDIR:-/data}"
OUT_FILE="${OUT_FILE:-$WORKDIR/proxy.pac}"

PAC_PROXY="${PAC_PROXY:-SOCKS5 127.0.0.1:1080; DIRECT}"
GFWLIST_URL="${GFWLIST_URL:-}"
PAC_COMPRESS="${PAC_COMPRESS:-true}"
PAC_PRECISE="${PAC_PRECISE:-false}"

PAC_DIRECT_LIST="${PAC_DIRECT_LIST:-}"
PAC_PROXY_LIST="${PAC_PROXY_LIST:-}"
PAC_BLOCK_LIST="${PAC_BLOCK_LIST:-}"

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
  normalize_list "$1" | sed 's/^/"/;s/$/"/' | paste -sd,
}

# ---------------- 开始 ----------------

log "START"

direct_js="$(to_js_array "$PAC_DIRECT_LIST")"
proxy_js="$(to_js_array "$PAC_PROXY_LIST")"
block_js="$(to_js_array "$PAC_BLOCK_LIST")"

USER_RULES_PAC="$WORKDIR/user_rules.pac"

# ---------------- 用户规则头 ----------------

cat > "$USER_RULES_PAC" <<EOF
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
var PROXY_LIST  = [${proxy_js}];
var PAC_PROXY   = "${PAC_PROXY}";
EOF

# ---------------- 无 gfwlist：全代理 ----------------

if [ -z "$GFWLIST_URL" ]; then
  log "未指定 GFWLIST_URL，生成全代理 PAC"

  cat > "$OUT_FILE" <<EOF
$(cat "$USER_RULES_PAC")

function FindProxyForURL(url, host) {

    // 0️⃣ 黑名单
    if (BLOCK_LIST.length && isMatch(host, BLOCK_LIST)) {
        return "PROXY 0.0.0.0:0";
    }

    // 1️⃣ 强制直连
    if (DIRECT_LIST.length && isMatch(host, DIRECT_LIST)) {
        return "DIRECT";
    }

    // 2️⃣ 强制代理
    if (PROXY_LIST.length && isMatch(host, PROXY_LIST)) {
        return PAC_PROXY;
    }

    // 3️⃣ 默认
    return PAC_PROXY;
}
EOF

  log "SUCCESS"
  notify_webhook "$WEBHOOK_SUCCESS_URL" "$WEBHOOK_SUCCESS_OPTIONS"
  exit 0
fi

# ---------------- 使用 genpac ----------------

log "使用 gfwlist: $GFWLIST_URL"

CMD="genpac --format=pac --pac-proxy=\"$PAC_PROXY\" --gfwlist-url=\"$GFWLIST_URL\""
[ "$PAC_COMPRESS" = "true" ] && CMD="$CMD --pac-compress"
[ "$PAC_PRECISE" = "true" ] && CMD="$CMD --pac-precise"

GENPAC_PAC="$WORKDIR/genpac.pac"
sh -c "$CMD" > "$GENPAC_PAC"

# ---------------- 注入用户规则 ----------------

MERGED_PAC="$WORKDIR/genpac_with_user.pac"

awk '
/function FindProxyForURL/ {
  print;
  print "    // ---- 用户自定义规则 ----";
  print "    if (BLOCK_LIST.length && isMatch(host, BLOCK_LIST)) return \"PROXY 0.0.0.0:0\";";
  print "    if (DIRECT_LIST.length && isMatch(host, DIRECT_LIST)) return \"DIRECT\";";
  print "    if (PROXY_LIST.length && isMatch(host, PROXY_LIST)) return PAC_PROXY;";
  next
}
{ print }
' "$GENPAC_PAC" > "$MERGED_PAC"

cat "$USER_RULES_PAC" "$MERGED_PAC" > "$OUT_FILE"

log "SUCCESS"
notify_webhook "$WEBHOOK_SUCCESS_URL" "$WEBHOOK_SUCCESS_OPTIONS"
