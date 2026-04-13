#!/usr/bin/env bash
# /usr/local/bin/xray-tun-helper.sh

# ================= 配置区域 =================
# 默认值
DEFAULT_TUN_NAME="xray0"
DEFAULT_TUN_ADDR="10.0.0.1/30"
DEFAULT_MARK=255

# 优先级定义 (Priority)
# 5000:  Xray 出站流量 -> 走 Main 表 (防回环)
# 5500:  局域网流量 -> 走 Main 表 (保留局域网访问)
# 10000: 其他所有流量 -> 走 Table 100 (进 TUN)
PREF_MARK=5000
PREF_LAN=5500
PREF_TUN=10000
TABLE_TUN=100
# ===========================================

log() { echo "[Xray-TUN-Helper] $1"; }

# 1. 环境加载
CONF_DIR="${CONFIGURATION_DIRECTORY:-/etc/xray}"
ENV_FILE="${CONF_DIR}/.env.warp"

if [ -f "$ENV_FILE" ]; then
    # log "Loading environment from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
fi

ACTION=${1:-start}
TUN_NAME=${2:-${XRAY_TUN_INTERFACE:-$DEFAULT_TUN_NAME}}
MARK=${XRAY_OUTBOUND_MASK:-$DEFAULT_MARK}

# 如果 MARK 为 0，视为禁用 TUN，直接退出并尝试清理（如果是 stop 动作）
if [ "$MARK" -eq 0 ]; then
    if [ "$ACTION" == "stop" ]; then
        # 即使禁用也要尝试清理，防止残留
        ip rule del fwmark "$DEFAULT_MARK" lookup main pref $PREF_MARK >/dev/null 2>&1
        ip rule del from all lookup $TABLE_TUN pref $PREF_TUN >/dev/null 2>&1
        exit 0
    fi
    log "XRAY_OUTBOUND_MASK is 0. Script skipped."
    exit 0
fi

# ================= 核心函数 =================

# 清理函数：移除我们添加的所有规则
cleanup_tun() {
    local quiet="$1"
    [ "$quiet" != "quiet" ] && log "Cleaning up TUN rules..."

    # 1. 移除策略路由 (Rule)
    # 基于优先级删除，不管接口叫什么，只要占了我们的坑位就清理掉
    while ip rule show | grep -q "from all fwmark $(printf '0x%x' $MARK) lookup main"; do
        ip rule del fwmark "$MARK" lookup main pref $PREF_MARK >/dev/null 2>&1
    done
    
    # 暴力清理可能有残留的旧规则 (以防 mark 变了但 pref 没变)
    ip rule del pref $PREF_MARK >/dev/null 2>&1
    
    # 移除局域网直连规则
    while ip rule show | grep -q "lookup main"; do
        # 仅删除在这个优先级下的规则
        if ip rule show | grep -q "^$PREF_LAN:"; then
             ip rule del pref $PREF_LAN >/dev/null 2>&1
        else
             break
        fi
    done

    # 移除全局捕获规则
    ip rule del from all lookup $TABLE_TUN pref $PREF_TUN >/dev/null 2>&1

    # 2. 清空路由表 100
    ip route flush table $TABLE_TUN >/dev/null 2>&1

    [ "$quiet" != "quiet" ] && log "Cleanup complete."
}

setup_tun() {
    log "Preparing TUN setup..."

    # --- 关键修正：先清理 ---
    # 在检测网络环境前，必须先清除可能存在的旧规则，
    # 否则 ip route get 8.8.8.8 会被旧规则误导指向 xray0
    cleanup_tun "quiet"
    # -----------------------

    # 等待 TUN 设备就绪
    local max_retries=20 # 10秒
    local count=0
    while ! ip link show "$TUN_NAME" >/dev/null 2>&1; do
        sleep 0.5
        ((count++))
        if [ $count -ge $max_retries ]; then
            log "Error: Interface $TUN_NAME not found. Xray failed to start?"
            exit 1
        fi
    done

    # 配置 IP
    if ! ip addr show "$TUN_NAME" | grep -q "inet"; then
        log "Assigning IP $DEFAULT_TUN_ADDR to $TUN_NAME"
        ip addr add "$DEFAULT_TUN_ADDR" dev "$TUN_NAME"
    fi
    ip link set "$TUN_NAME" up

    # --- 获取主接口 ---
    # 现在的环境是干净的，可以直接查路由
    MAIN_IFACE=$(ip route get 8.8.8.8 | grep dev | awk '{print $5; exit}')
    
    # --- 安全兜底检查 ---
    if [ "$MAIN_IFACE" == "$TUN_NAME" ]; then
        log "CRITICAL ERROR: Main interface detected as $TUN_NAME!"
        log "This implies a routing loop or unclean state. Aborting."
        exit 1
    fi

    if [ -z "$MAIN_IFACE" ]; then
        log "Error: Could not detect main interface. No internet?"
        exit 1
    fi
    log "Detected Main Interface: $MAIN_IFACE"

    # --- 开始配置路由 ---
    
    # 1. 防回环：Xray 发出的流量 (mark) -> 查 Main 表
    ip rule add fwmark "$MARK" lookup main pref $PREF_MARK
    
    # 2. 局域网直连：主接口所在的网段 -> 查 Main 表 (不走 TUN)
    # 获取网段 CIDR (如 192.168.3.0/24)
    LAN_NET=$(ip -4 addr show "$MAIN_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -n 1)
    if [ -n "$LAN_NET" ]; then
        log "Bypassing TUN for Local Network: $LAN_NET"
        ip rule add to "$LAN_NET" lookup main pref $PREF_LAN
    else
        log "Warning: Could not detect LAN network on $MAIN_IFACE."
    fi

    # 3. 全局捕获：剩下所有流量 -> 查 Table 100
    ip rule add from all lookup $TABLE_TUN pref $PREF_TUN

    # 4. 设置 Table 100 默认路由
    ip route add default dev "$TUN_NAME" table $TABLE_TUN

    log "TUN setup successful. Rules applied."
}

# ================= 主逻辑 =================
case "$ACTION" in
    start)
        setup_tun
        ;;
    stop)
        cleanup_tun
        ;;
    *)
        echo "Usage: $0 {start|stop} [tun_interface]"
        exit 1
        ;;
esac
