#!/bin/bash
# 按「多久没用」给 /Applications 里的 App 排名，帮你找出可以删除的 App。只读，不删除任何东西。
# 用法: bash scripts/rank_apps.sh

now=$(date +%s)
for app in /Applications/*.app /Applications/*/*.app "$HOME"/Applications/*.app; do
  [ -d "$app" ] || continue
  name=$(basename "$app" .app)
  last=$(mdls -raw -name kMDItemLastUsedDate "$app" 2>/dev/null)
  cnt=$(mdls -raw -name kMDItemUseCount "$app" 2>/dev/null)
  case "$cnt" in ''|*null*) cnt=0 ;; esac
  case "$last" in ''|*null*) days=99999 ;;
    *) ts=$(date -j -f "%Y-%m-%d %H:%M:%S %z" "$last" +%s 2>/dev/null) || ts=$now
       days=$(( (now - ts) / 86400 )) ;;
  esac
  kb=$(du -sk "$app" 2>/dev/null | cut -f1)
  printf "%s\t%s\t%s\t%s\n" "$days" "$cnt" "${kb:-0}" "$name"
done | sort -t$'\t' -k1,1nr -k2,2n | awk -F'\t' '
BEGIN { print "排名  多久没用     打开次数  大小       建议          App"
        print "----------------------------------------------------------------" }
{ d=$1; c=$2; kb=$3
  dl = (d==99999) ? "从未/未知" : d "天"
  sz = (kb>=1048576) ? sprintf("%.1fGB", kb/1048576) : sprintf("%dMB", kb/1024)
  s  = (d>=180) ? "★可考虑删除" : (d>=60) ? "用得少" : "常用,保留"
  printf "%-5d %-12s %-9s %-10s %-13s %s\n", NR, dl, c, sz, s, $4 }'
