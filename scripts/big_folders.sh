#!/bin/bash
# 列出个人资料库（~/Library）里最占空间的文件夹，找出「系统数据」里藏着的大头。
# 只读，不删除任何东西。
# 用法: bash scripts/big_folders.sh [显示数量，默认 20]

N="${1:-20}"

echo "最占空间的 $N 个文件夹（~/Library）:"
echo "--------------------------------------------"
# 每个文件夹单独计算（du 一次算多个路径时会跳过已统计过的子文件夹）
for d in "$HOME"/Library/* \
         "$HOME"/Library/Application\ Support/* \
         "$HOME"/Library/Containers/* \
         "$HOME"/Library/Group\ Containers/*; do
  [ -e "$d" ] && du -sk "$d" 2>/dev/null
done | sort -nr | head -"$N" | while IFS=$'\t' read -r kb path; do
      short="~${path#"$HOME"}"
      awk -v k="$kb" -v p="$short" 'BEGIN{
        if (k>=1048576) printf "  %8.1f GB  %s\n", k/1048576, p;
        else            printf "  %8.0f MB  %s\n", k/1024, p }'
    done

echo
echo "常见可清理的大头:"
echo "  ~/Library/Application Support/MobileSync/Backup  → 旧的 iPhone/iPad 备份"
echo "  ~/Library/Developer                               → Xcode 编译缓存、模拟器"
echo "  ~/Library/Caches                                  → 应用缓存（mac_cleanup.sh 会清理）"
echo "  ~/Library/Containers/com.tencent.xinWeChat        → 微信聊天记录和文件"
echo "删除前请先确认里面没有你需要的东西。"
