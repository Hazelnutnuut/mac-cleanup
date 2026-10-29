#!/bin/bash
# 检查「照片」图库占用的空间，以及照片有没有存到 iCloud。只读，不修改任何东西。
# 需要先给「终端」完全磁盘访问权限（系统设置 → 隐私与安全性 → 完全磁盘访问权限）。
# 用法: bash scripts/check_photos_icloud.sh

LIB="$HOME/Pictures/Photos Library.photoslibrary"
DB="$LIB/database/Photos.sqlite"

if ! ls "$LIB" >/dev/null 2>&1; then
  echo "❌ 没有权限读取照片图库。"
  echo "请打开：系统设置 → 隐私与安全性 → 完全磁盘访问权限，把「终端」打开，"
  echo "然后完全退出终端（Command+Q）重新打开，再运行一次。"
  exit 1
fi

echo "========== 1. iCloud 账号 =========="
acct=$(defaults read MobileMeAccounts Accounts 2>/dev/null | grep -m1 AccountID | sed 's/.*= //; s/[";]//g')
if [ -n "$acct" ]; then echo "已登录 iCloud：$acct"; else echo "这台 Mac 没有登录 iCloud"; fi

echo
echo "========== 2. 照片图库里都是什么 =========="
show() { [ -e "$1" ] && printf "  %-8s %s\n" "$(du -sh "$1" 2>/dev/null | cut -f1)" "$2"; }
show "$LIB/originals"             "originals      → 照片/视频原图（真正的照片）"
show "$LIB/resources/derivatives" "derivatives    → 缩略图、预览图（可自动重建）"
show "$LIB/resources/renders"     "renders        → 编辑过的照片版本（滤镜、裁剪等）"
show "$LIB/resources"             "resources 合计 → 以上预览/编辑文件 + 其他缓存"
show "$LIB/database"              "database       → 照片目录数据库（相册、人物等信息）"
show "$LIB/scopes"                "scopes         → 共享相簿等的缓存"
show "$LIB"                       "【整个图库合计】"

echo
echo "========== 3. 有没有存在 iCloud 上 =========="
if ! command -v sqlite3 >/dev/null; then echo "  找不到 sqlite3，无法检查"; exit 0; fi
TMP=$(mktemp -d)
cp "$DB"* "$TMP"/ 2>/dev/null
Q() { sqlite3 "$TMP/Photos.sqlite" "$1" 2>/dev/null; }
total=$(Q "SELECT COUNT(*) FROM ZASSET WHERE ZTRASHEDSTATE=0;")
videos=$(Q "SELECT COUNT(*) FROM ZASSET WHERE ZTRASHEDSTATE=0 AND ZKIND=1;")
trash=$(Q "SELECT COUNT(*) FROM ZASSET WHERE ZTRASHEDSTATE=1;")
incloud=$(Q "SELECT COUNT(*) FROM ZASSET WHERE ZTRASHEDSTATE=0 AND ZCLOUDASSETGUID IS NOT NULL AND ZCLOUDLOCALSTATE=1;")
rm -rf "$TMP"
local_orig=$(find "$LIB/originals" -type f 2>/dev/null | wc -l | tr -d ' ')

if [ -z "$total" ]; then
  echo "  无法读取数据库（可以先退出「照片」App 再试一次）"; exit 0
fi
echo "  图库里共有：$total 项（其中视频 $videos 个）"
echo "  「最近删除」里还有：${trash:-0} 项（仍占空间）"
echo "  已上传到 iCloud：${incloud:-0} 项"
echo "  电脑上保存的原图文件：$local_orig 个"
echo
if [ "${incloud:-0}" -eq 0 ]; then
  echo "  👉 结论：照片【没有】存到 iCloud，只存在这台电脑上。"
  echo "     删除前请先备份，否则会永久丢失。"
elif [ "$incloud" -lt "$total" ]; then
  echo "  👉 结论：iCloud 照片已开启，但还有 $((total - incloud)) 项没有上传完。"
else
  echo "  👉 结论：所有照片都已存在 iCloud 上。"
fi
if [ "${incloud:-0}" -gt 0 ]; then
  if [ "$local_orig" -ge $((total * 9 / 10)) ]; then
    echo "     电脑上也保存着几乎全部原图 → 选的是「下载原件到此 Mac」，"
    echo "     改成「优化 Mac 储存空间」就能腾出空间。"
  else
    echo "     电脑上只保留部分原图 → 已经是「优化 Mac 储存空间」模式。"
  fi
fi

echo
echo "========== 4. Photo Booth =========="
show "$HOME/Pictures/Photo Booth Library" "Photo Booth 自拍（不会自动同步到 iCloud）"
