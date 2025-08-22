#!/usr/bin/env bash
set -euo pipefail
DOWNLOAD_URLS=(
  "https://gitee.com/tdh-gitee/cursor-free-vip/releases/download/preview/"
  # 可以添加更多备用地址
)

DOWNLOAD_URL=""
OUTPUT=""
INVITE_CODE=""
SAVE_PATH="${HOME}/.agent-vip"
SAVE_FORMAT="json"
INVITE_KEY="code"  # 如需改键名可直接改这里
DESKTOP_DIR=""  # 将在后面动态获取

# 检测系统类型和架构
detect_system() {
  local os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  if [[ $os_name == *"mingw"* ]]; then
    os_name="windows"
  fi
  
  local raw_hw_name=$(uname -m)
  case "$raw_hw_name" in
    "amd64"|"x86_64") hw_name="amd64" ;;
    "arm64"|"aarch64") hw_name="arm64" ;;
    "i686") hw_name="386" ;;
    "armv7l") hw_name="arm" ;;
    *) echo "不支持的硬件架构: $raw_hw_name"; exit 1 ;;
  esac
  
  echo "${os_name}_${hw_name}"
}

# 获取正确的桌面路径（处理Windows环境下的路径问题）
get_desktop_path() {
  local os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  
  if [[ $os_name == *"mingw"* || $os_name == "msys" ]]; then
    # Windows环境下，尝试获取正确的桌面路径
    if [[ -n "$USERPROFILE" ]]; then
      # 将反斜杠转换为正斜杠，确保路径一致性
      echo "${USERPROFILE}/Desktop" | sed 's|\\|/|g'
    elif [[ -n "$HOME" && "$HOME" != "/c"* ]]; then
      echo "${HOME}/Desktop"
    else
      # 如果HOME路径有问题，尝试从环境变量获取
      local userprofile=$(env | grep -i userprofile | cut -d'=' -f2)
      if [[ -n "$userprofile" ]]; then
        echo "${userprofile}/Desktop" | sed 's|\\|/|g'
      else
        echo "/c/Users/$(whoami)/Desktop"
      fi
    fi
  else
    # 非Windows环境，使用标准HOME路径
    echo "${HOME}/Desktop"
  fi
}

# 检测可用的下载地址（简化版本，跳过检测直接使用配置的地址）
detect_available_url() {
  local system_info=$(detect_system)
  
  # echo "检测系统类型: $system_info"
  # echo "跳过地址检测，直接使用配置的地址"
  
  # 直接使用第一个配置的地址
  DOWNLOAD_URL="${DOWNLOAD_URLS[0]}"
  # echo "使用地址: $DOWNLOAD_URL"
}

# 位置参数：若第一个参数不是以 -- 开头，则作为邀请码
if [[ $# -ge 1 && "${1:-}" != --* ]]; then
  INVITE_CODE="${1}"
  shift 1
fi

# 长参数解析
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) OUTPUT="${2:-}"; shift 2;;
    --invite-code) INVITE_CODE="${2:-}"; shift 2;;
    --save-path) SAVE_PATH="${2:-}"; shift 2;;
    --save-format) SAVE_FORMAT="${2:-}"; shift 2;;
    *) echo "未知参数: $1"; exit 1;;
  esac
done

# 自动检测可用的下载地址
detect_available_url

# 推导输出文件名（基于检测到的 URL 和系统类型）
if [[ -z "${OUTPUT}" ]]; then
  system_info=$(detect_system)
  DESKTOP_DIR=$(get_desktop_path)
  if [[ $system_info == windows* ]]; then
    OUTPUT="${DESKTOP_DIR}/Cursor Free VIP_windows.exe"
  elif [[ $system_info == darwin* ]]; then
    OUTPUT="${DESKTOP_DIR}/Cursor Free VIP_darwin.dmg"
  else
    OUTPUT="${DESKTOP_DIR}/Cursor Free VIP_linux_${system_info#*_}"
  fi
fi

  # 下载函数（curl 或 wget）
download_file() {
  local url="$1" out="$2"
  local system_info=$(detect_system)
  local filename=""
  
  # 根据系统类型确定文件名
  if [[ $system_info == windows* ]]; then
    filename="Cursor Free VIP_windows.exe"
  elif [[ $system_info == darwin* ]]; then
    filename="Cursor Free VIP_darwin.dmg"
  else
    filename="Cursor Free VIP_linux_${system_info#*_}"
  fi
  
  # URL 编码文件名中的空格
  local encoded_filename=$(echo "$filename" | sed 's/ /%20/g')
  local full_url="${url}${encoded_filename}"
  # echo "下载地址: $full_url"
  
  if command -v curl >/dev/null 2>&1; then
    curl -L --retry 3 --connect-timeout 15 -o "$out" "$full_url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$out" "$full_url"
  else
    echo "未找到 curl 或 wget，请先安装其中之一"; exit 1
  fi
}

# 保存邀请码
save_invite() {
  local code="$1" path="$2" fmt="$3"
  [[ -z "$code" ]] && return 0
  mkdir -p "$(dirname "$path")" || true
  case "$fmt" in
    json)
      printf '{ "%s": "%s" }\n' "${INVITE_KEY}" "${code}" > "$path"
      ;;
    plain)
      printf '%s\n' "${code}" > "$path"
      ;;
    *)
      echo "不支持的保存格式：$fmt（仅支持 json|plain）"; exit 1;;
  esac
  # echo "邀请码已保存到：$path"
}

# 确保输出目录存在
mkdir -p "$(dirname "$OUTPUT")" || true

# echo "开始下载：$DOWNLOAD_URL"
download_file "$DOWNLOAD_URL" "$OUTPUT"
if [[ ! -s "$OUTPUT" ]]; then
  echo "下载失败或文件为空：$OUTPUT"; exit 1
fi
# echo "已下载到：$OUTPUT"

# 如传入邀请码则保存
if [[ -n "$INVITE_CODE" ]]; then
  save_invite "$INVITE_CODE" "$SAVE_PATH" "$SAVE_FORMAT"
# else
#   echo "未提供邀请码，跳过保存邀请码"
fi

echo ""
echo "已下载到：$OUTPUT"