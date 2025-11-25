#!/usr/bin/env bash
set -euo pipefail

# /usr/local/bin/geo-update.sh


# === 帮助函数 ===
usage() {
  echo "Usage: $0 --target <path> --command <cmd>"
  echo "  -t, --target      Directory to store data files (Required)"
  echo "  -c, --command     Command to execute if data changes (Required)"
  exit 1
}

# === 默认配置 ===
GIT_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download"
FILES_NAME="geoip.dat geosite.dat"
TARGET_DIR=""
RESTART_CMD=""

# === 参数解析 ===
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--target)
      TARGET_DIR="$2"
      shift 2
      ;;
    -c|--command)
      RESTART_CMD="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

# === 校验必填项 ===
if [[ -z "$TARGET_DIR" || -z "$RESTART_CMD" ]]; then
  echo "Error: --target-dir and --command are required."
  usage
fi

# === 核心逻辑 ===
UPDATED=false
mkdir -p "$TARGET_DIR"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT ERR

for file in $FILES_NAME; do
  echo "[Processing] $file ..."
  remote_sha256=$(curl -fsL "${GIT_URL}/${file}.sha256sum" | awk 'NR==1{print $1}') || {
    echo "  [Error] Remote data download failed! Please check your network and try again."
    exit 1
  }

  if [ -f "${TARGET_DIR}/${file}" ]; then
    local_sha256=$(sha256sum "${TARGET_DIR}/${file}" | awk '{print $1}')
    if [[ "${local_sha256,,}" == "${remote_sha256,,}" ]]; then
      echo "  [Skip] $file is up-to-date (Hash: $local_sha256)."
      continue
    fi
  fi

  echo "  [Update] New version detected. Downloading..."
  if ! curl -fsL -o "${TMP_DIR}/${file}" "${GIT_URL}/${file}"; then
    echo "  [Error] Remote data download failed! Please check your network and try again."
    exit 1
  fi
  
  download_sha256=$(sha256sum "${TMP_DIR}/${file}" | awk '{print $1}')
  if [[ "${download_sha256,,}" != "${remote_sha256,,}" ]]; then
    echo "  [Error] Hash mismatch for $file! Aborting."
    rm -f "${TMP_DIR}/${file}"
    exit 1
  fi

  if mv -f "${TMP_DIR}/${file}" "${TARGET_DIR}/${file}" 2>&1; then
    chmod 644 "${TARGET_DIR}/${file}"
    echo "  [Success] $file updated successfully."
    UPDATED=true
  else
    echo "  [Error] File move failed."
    exit 1
  fi
done

if [ "$UPDATED" = true ]; then
  echo "[Trigger] Data changed. Executing restart command..."
  echo "  > $RESTART_CMD"
  
  # 使用 eval 或 bash -c 执行传入的命令字符串
  # 这里为了兼容性，直接执行命令字符串
  /bin/bash -c "$RESTART_CMD"
fi

