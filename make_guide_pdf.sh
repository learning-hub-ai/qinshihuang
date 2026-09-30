#!/usr/bin/env bash
# 把根目录的七个页面打成一份 PDF —— 按「什么时候用」排，和导航栏同一个逻辑。
#
# 用法
# ----
#   ./make_guide_pdf.sh            # 合成一份总册
#   ./make_guide_pdf.sh --split    # 另外再各存一份单页 PDF
#
# 产出在 print/ 下：
#   秦始皇-阅读手册.pdf            七个页面合成一册
#   单页/<页名>.pdf                 --split 时另存
#
# 顺序（和 how-to-use.html 里的六步读书法一致，不是字母序）：
#   1 使用说明      先读这个，讲清楚怎么用
#   2 阅读进度表    六周计划，读之前排时间
#   3 阅读指引      六章十七节总表，读的过程中查
#   4 地图          开读前先认地方
#   5 人物关系表    读的过程中查人
#   6 秦始皇小档案  每章开读前扫一眼年份
#   7 一生时间轴    整本读完之后回头看
#
# 为什么用 headless Chrome：见 make_vocab_pdf.sh 里的说明（同样的理由）。
# ⚠ 背景色要印出来 —— 章节表的分章底色、地图页的图例都靠底色区分。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/print"
TMP="$OUT/tmp"
SPLIT=0
[[ "${1:-}" == "--split" ]] && SPLIT=1

# 顺序即用途顺序；第二栏是单页 PDF 的文件名
PAGES=(
  "how-to-use.html|1-使用说明"
  "reading-plan.html|2-阅读进度表"
  "index.html|3-阅读指引"
  "maps.html|4-地图"
  "characters.html|5-人物关系表"
  "fact-sheet.html|6-秦始皇小档案"
  "timeline.html|7-一生时间轴"
)

mkdir -p "$TMP"

topdf() {   # topdf <html> <pdf>
  local src="$ROOT/$1" dst="$2"
  [[ -f "$src" ]] || { echo "缺文件：$1" >&2; return 1; }
  timeout 180 google-chrome --headless --disable-gpu --no-sandbox \
      --no-pdf-header-footer --print-to-pdf="$dst" "file://$src" >/dev/null 2>&1
  [[ -s "$dst" ]] || { echo "生成失败：$1" >&2; return 1; }
}

parts=()
i=0
for row in "${PAGES[@]}"; do
  html="${row%%|*}"; label="${row##*|}"
  i=$((i+1))
  pdf="$(printf '%s/%02d.pdf' "$TMP" "$i")"
  printf '  [%d/%d] %-20s' "$i" "${#PAGES[@]}" "$html"
  topdf "$html" "$pdf"
  printf '%2s 页  %s\n' "$(pdfinfo "$pdf" | awk '/^Pages/{print $2}')" "$label"
  parts+=("$pdf")
  if (( SPLIT )); then
    mkdir -p "$OUT/单页"
    cp "$pdf" "$OUT/单页/${label}.pdf"
  fi
done

pdfunite "${parts[@]}" "$OUT/秦始皇-阅读手册.pdf"
rm -rf "$TMP"

echo
printf '%-28s %4s 页  %s\n' "秦始皇-阅读手册.pdf" \
  "$(pdfinfo "$OUT/秦始皇-阅读手册.pdf" | awk '/^Pages/{print $2}')" \
  "$(du -h "$OUT/秦始皇-阅读手册.pdf" | cut -f1)"
(( SPLIT )) && echo "单页另存在 print/单页/"
