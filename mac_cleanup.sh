#!/bin/bash
# =============================================================
#  mac_cleanup.sh —— macOS 内存 + 存储空间 自动清理脚本
#
#  自动清理（安全项目）:
#    - 用户缓存 ~/Library/Caches（App 会自动重建）
#    - 7 天以前的用户日志 ~/Library/Logs
#    - Xcode DerivedData（如有）
#    - Homebrew / npm / pip 缓存（如有安装）
#    - 释放闲置内存（sudo purge，需管理员密码）
#
#  只列出、不自动删除（需要你自己确认）:
#    - 占内存最多的程序
#    - 废纸篓、下载文件夹里的大文件、超过 500MB 的大文件
#
#  用法:
#    bash mac_cleanup.sh             # 前台运行一次
#    bash mac_cleanup.sh --dry-run   # 只扫描，不删除任何东西
#    bash mac_cleanup.sh --bg        # 放到后台运行，结果写入报告
#    bash mac_cleanup.sh --install   # 设为每周日 03:00 自动在后台运行
#    bash mac_cleanup.sh --uninstall # 取消自动运行
# =============================================================

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
REPORT_DIR="$HOME/CleanupReports"
REPORT="$REPORT_DIR/report_$(date +%Y%m%d_%H%M%S).txt"
PLIST="$HOME/Library/LaunchAgents/com.user.maccleanup.plist"
DRY_RUN=0

mkdir -p "$REPORT_DIR"

# ---------- 参数处理 ----------
case "$1" in
  --dry-run) DRY_RUN=1 ;;
  --bg)
    nohup bash "$SCRIPT_PATH" --run-bg >/dev/null 2>&1 &
    echo "已在后台运行（PID $!）。完成后报告在: $REPORT_DIR"
    exit 0 ;;
  --run-bg) exec >>"$REPORT" 2>&1 ;;
  --install)
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.user.maccleanup</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>$SCRIPT_PATH</string><string>--run-bg</string>
  </array>
  <key>StartCalendarInterval</key><dict>
    <key>Weekday</key><integer>0</integer>
    <key>Hour</key><integer>3</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
</dict></plist>
EOF
    launchctl unload "$PLIST" 2>/dev/null
    launchctl load "$PLIST" && echo "已设置：每周日 03:00 自动后台清理。报告在 $REPORT_DIR"
    exit 0 ;;
  --uninstall)
    launchctl unload "$PLIST" 2>/dev/null; rm -f "$PLIST"
    echo "已取消自动清理。"; exit 0 ;;
esac

# ---------- 工具函数 ----------
human() {  # KB -> 可读大小
  awk -v k="$1" 'BEGIN{ if(k>=1048576) printf "%.1f GB", k/1048576;
                        else if(k>=1024) printf "%.1f MB", k/1024;
                        else printf "%d KB", k }'
}
size_kb() { du -sk "$1" 2>/dev/null | awk '{print $1+0}'; }
free_disk_kb() { df -k / | awk 'NR==2{print $4}'; }

TOTAL_FREED=0
clean_dir_contents() {  # 清空目录内容（保留目录本身）
  local dir="$1" label="$2"
  [ -d "$dir" ] || return
  local before; before=$(size_kb "$dir")
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [模拟] $label: 可清理 $(human "$before")"
    return
  fi
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
  local after; after=$(size_kb "$dir")
  local freed=$((before - after))
  TOTAL_FREED=$((TOTAL_FREED + freed))
  echo "  ✓ $label: 释放 $(human "$freed")"
}

echo "=================================================="
echo " Mac 清理报告  $(date '+%Y-%m-%d %H:%M:%S')"
[ "$DRY_RUN" -eq 1 ] && echo " （模拟模式：不会删除任何文件）"
echo "=================================================="

DISK_BEFORE=$(free_disk_kb)

# ================= 1. 运行内存 (RAM) =================
echo
echo "【一、运行内存】"
memory_pressure 2>/dev/null | grep -i "free percentage" | sed 's/^/  /'

echo
echo "  占内存最多的 15 个程序（可考虑关闭的会标 ★）:"
printf "  %-8s %-10s %s\n" "PID" "内存" "程序"
ps -axo pid=,rss=,comm= | sort -k2 -nr | head -15 | while read -r pid rss cmd; do
  name=$(basename "$cmd")
  mark=""
  # 系统核心进程不建议关；/Applications 下的普通 App 可以考虑关
  case "$cmd" in
    /Applications/*|"$HOME"/Applications/*) mark="★" ;;
  esac
  printf "  %-8s %-10s %s %s\n" "$pid" "$(human "$rss")" "$name" "$mark"
done
echo "  提示：★ 为普通应用，不用时可手动退出（Cmd+Q）。脚本不会自动关闭程序，以免丢失未保存的内容。"

# ================= 2. 自动清理安全项目 =================
echo
echo "【二、自动清理（安全项目）】"

clean_dir_contents "$HOME/Library/Caches" "用户缓存"

if [ -d "$HOME/Library/Logs" ]; then
  before=$(size_kb "$HOME/Library/Logs")
  if [ "$DRY_RUN" -eq 0 ]; then
    find "$HOME/Library/Logs" -type f -mtime +7 -delete 2>/dev/null
    after=$(size_kb "$HOME/Library/Logs")
    freed=$((before - after)); TOTAL_FREED=$((TOTAL_FREED + freed))
    echo "  ✓ 7 天前的日志: 释放 $(human "$freed")"
  else
    echo "  [模拟] 日志目录共 $(human "$before")（只会删 7 天前的）"
  fi
fi

clean_dir_contents "$HOME/Library/Developer/Xcode/DerivedData" "Xcode DerivedData"

if command -v brew >/dev/null 2>&1; then
  if [ "$DRY_RUN" -eq 0 ]; then brew cleanup -s >/dev/null 2>&1 && echo "  ✓ Homebrew 缓存已清理"
  else echo "  [模拟] 会执行 brew cleanup"; fi
fi
if command -v npm >/dev/null 2>&1; then
  clean_dir_contents "$HOME/.npm/_cacache" "npm 缓存"
fi
if [ -d "$HOME/Library/Caches/pip" ]; then :; fi  # pip 缓存已包含在用户缓存里

# 释放闲置内存：需要 sudo；后台运行时无法输入密码，会自动跳过
if [ "$DRY_RUN" -eq 0 ]; then
  if sudo -n true 2>/dev/null; then
    sudo purge && echo "  ✓ 已释放闲置内存 (purge)"
  elif [ -t 0 ]; then
    echo "  释放闲置内存需要管理员密码:"
    sudo purge && echo "  ✓ 已释放闲置内存 (purge)"
  else
    echo "  - 后台模式无法输入密码，跳过 purge（macOS 本身也会自动管理内存）"
  fi
fi

# ================= 3. 只列出，需要你确认 =================
echo
echo "【三、建议你手动检查（未自动删除）】"

TRASH_KB=$(size_kb "$HOME/.Trash")
echo "  废纸篓: $(human "${TRASH_KB:-0}")  → 确认无用后可在访达中「清倒废纸篓」"

DL_KB=$(size_kb "$HOME/Downloads")
echo "  下载文件夹: $(human "${DL_KB:-0}")"

echo
echo "  个人目录下超过 500MB 的文件（前 20 个）:"
find "$HOME" -xdev -type f -size +500M \
  -not -path "$HOME/Library/*" -not -path "$HOME/.Trash/*" 2>/dev/null \
  | head -200 | while read -r f; do
      printf "%s\t%s\n" "$(size_kb "$f")" "$f"
    done | sort -nr | head -20 | while IFS=$'\t' read -r kb f; do
      printf "  %-10s %s\n" "$(human "$kb")" "$f"
    done

echo
echo "  个人目录下最大的文件夹:"
du -sk "$HOME"/* "$HOME"/.[!.]* 2>/dev/null | sort -nr | head -10 | while read -r kb d; do
  printf "  %-10s %s\n" "$(human "$kb")" "$d"
done

# ================= 汇总 =================
DISK_AFTER=$(free_disk_kb)
echo
echo "=================================================="
if [ "$DRY_RUN" -eq 0 ]; then
  echo " 本次共清理: $(human "$TOTAL_FREED")"
fi
echo " 硬盘可用空间: $(human "$DISK_BEFORE") → $(human "$DISK_AFTER")"
echo "=================================================="
