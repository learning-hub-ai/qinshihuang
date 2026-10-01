#!/usr/bin/env bash
# 把根目录的七个页面打成一份 PDF —— 按「什么时候用」排，和导航栏同一个逻辑。
#
# 用法
# ----
#   ./make_guide_pdf.sh                  # 合成一份总册
#   ./make_guide_pdf.sh --split          # 另外再各存一份单页 PDF
#   ./make_guide_pdf.sh --no-footer      # 不印页脚（每页省 2 行）
#   ./make_guide_pdf.sh --no-footer --split
#
# 产出在 print/ 下：
#   秦始皇-阅读手册.pdf            七个页面合成一册
#   单页/<页名>.pdf                 --split 时另存
#
# ⚠ --no-footer 去掉的是页面里那块 <footer class="sitefoot">
#   （不是浏览器自己的页眉页脚 —— 那个一直用 --no-pdf-header-footer 关着）。
#   site.css 里写明「版权与『请购买原书』那一行 —— 屏幕和纸上都要出现」，
#   所以这是个有意识的取舍。这一册里去掉它仍然合规，因为：
#     · 每一页的页头都印着「景崇兰 著 · 简志刚 绘 · 人民文学出版社」
#       —— 著作权法第二十四条要的「指明作者姓名、作品名称」在页头已经满足；
#     · 第 1–2 页「使用说明」正文里有完整的版权与引用声明，不靠页脚；
#     · 这七个页面基本不含原书引文，是自编材料。
#   字词表（含引文、每条标页码）不要这样做 —— 那里页脚要留着。
#   源文件一个字都不改，只在生成 PDF 时套一层打印样式。
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
NOFOOTER=0
for arg in "$@"; do
  case "$arg" in
    --split)     SPLIT=1 ;;
    --no-footer) NOFOOTER=1 ;;
    *) echo "不认识的参数：$arg" >&2
       echo "用法：$0 [--split] [--no-footer]" >&2; exit 2 ;;
  esac
done

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
  local src="$ROOT/$1" dst="$2" render="$ROOT/$1"
  [[ -f "$src" ]] || { echo "缺文件：$1" >&2; return 1; }

  # 去页脚：在同一个目录里放一份临时副本（必须同目录，否则
  # site.css、assets/ 这些相对路径会失效），只多注入一条打印样式。
  # 原文件不动。
  if (( NOFOOTER )); then
    render="$ROOT/.tmp-nofooter-$(basename "$1")"
    sed 's#</head>#<style>@media print{.sitefoot{display:none!important;}}</style>\n</head>#' \
        "$src" > "$render"
  fi

  timeout 180 google-chrome --headless --disable-gpu --no-sandbox \
      --no-pdf-header-footer --print-to-pdf="$dst" "file://$render" >/dev/null 2>&1
  local rc=$?
  (( NOFOOTER )) && rm -f "$render"
  [[ -s "$dst" ]] || { echo "生成失败：$1" >&2; return 1; }
  return $rc
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
