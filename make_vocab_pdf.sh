#!/usr/bin/env bash
# 把字词表打成 PDF —— 第一章到附录，按顺序合成一份。
#
# 用法
# ----
#   ./make_vocab_pdf.sh                        # 两份都做
#   ./make_vocab_pdf.sh detail                 # 只做详细版（17 节＋附录，带意思和组词）
#   ./make_vocab_pdf.sh compact                # 只做精简版（all.html，1908 条，只有拼音和页码）
#   ./make_vocab_pdf.sh detail --no-footer     # 不印页脚
#
# 产出在 print/ 下：
#   字词表-全书-详细版.pdf    目录 ＋ 17 节 ＋ 附录，每节从新的一页开始
#   字词表-全书-精简版.pdf    一张大表，适合快速过一遍或考前默写
#
# 为什么用 headless Chrome 而不是 wkhtmltopdf：
#   这台机器上只有 Chrome。而且页面的打印样式（@page A4 12mm、表头跨页重复、
#   tbody tr 不断开）本来就是按浏览器打印写的，Chrome 的结果和孩子自己
#   Ctrl+P 出来的完全一致。
#
# ⚠ 背景色必须印出来 —— ★重点是浅黄底、「只要会念」是浅灰底，
#   底色本身带信息。Chrome headless 默认会印背景，脚本里不另加开关；
#   若将来换工具，记得开 print-background。
#
# ⚠ --no-footer 去掉页面里那块 <footer class="sitefoot">
#   （浏览器自己的页眉页脚一直用 --no-pdf-header-footer 关着）。
#   site.css 写明「版权与『请购买原书』那一行 —— 屏幕和纸上都要出现」，
#   所以这是个有意识的取舍。这里去掉它仍然合规，因为：
#     · 仓库里这 18 份表**已经不含原书引文** —— 116 处「书上：」原句在
#       2026-09-29 就删掉了，只留在 source/vocab-with-quotes/（不进 git）；
#     · 每一份表的正文末尾都有自己的「词条来源」说明（18/18 页都有），
#       不依赖页脚；
#     · 每一页页头印着「景崇兰 著 · 简志刚 绘 · 人民文学出版社」——
#       著作权法第二十四条要的「指明作者姓名、作品名称」在页头已满足；
#     · 每个词条仍带页码，孩子照样要翻回原书。
#   源文件一个字都不改，只在生成 PDF 时套一层打印样式。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/print"
TMP="$OUT/tmp"
WHAT="all"
NOFOOTER=0
for arg in "$@"; do
  case "$arg" in
    detail|compact|all) WHAT="$arg" ;;
    --no-footer)        NOFOOTER=1 ;;
    *) echo "不认识的参数：$arg" >&2
       echo "用法：$0 [detail|compact|all] [--no-footer]" >&2; exit 2 ;;
  esac
done

# 详细版的页面顺序：目录在最前，然后六章十七节，最后附录年表
PAGES=(
  vocab/index.html
  vocab/chapter1-section1.html vocab/chapter1-section2.html vocab/chapter1-section3.html
  vocab/chapter2-section1.html vocab/chapter2-section2.html vocab/chapter2-section3.html
  vocab/chapter3-section1.html vocab/chapter3-section2.html vocab/chapter3-section3.html
  vocab/chapter4-section1.html vocab/chapter4-section2.html vocab/chapter4-section3.html
  vocab/chapter5-section1.html vocab/chapter5-section2.html vocab/chapter5-section3.html
  vocab/chapter6-section1.html vocab/chapter6-section2.html
  vocab/appendix-chronology.html
)

mkdir -p "$TMP"

topdf() {   # topdf <相对路径> <输出 pdf>
  local src="$ROOT/$1" dst="$2" render="$ROOT/$1"
  [[ -f "$src" ]] || { echo "缺文件：$1" >&2; return 1; }

  # 去页脚：临时副本必须放在**同一个目录**里（vocab/ 下），
  # 否则 ../site.css、../vocab.css、../site.js 这些相对路径会失效，
  # 表格会失去全部样式。原文件不动。
  if (( NOFOOTER )); then
    render="$ROOT/$(dirname "$1")/.tmp-nofooter-$(basename "$1")"
    sed 's#</head>#<style>@media print{.sitefoot{display:none!important;}}</style>\n</head>#' \
        "$src" > "$render"
  fi

  timeout 180 google-chrome --headless --disable-gpu --no-sandbox \
      --no-pdf-header-footer --print-to-pdf="$dst" "file://$render" >/dev/null 2>&1
  (( NOFOOTER )) && rm -f "$render"
  [[ -s "$dst" ]] || { echo "生成失败：$1" >&2; return 1; }
}

build_detail() {
  echo "详细版 —— ${#PAGES[@]} 个页面"
  local parts=() i=0
  for p in "${PAGES[@]}"; do
    i=$((i+1))
    local pdf; pdf="$(printf '%s/%02d.pdf' "$TMP" "$i")"
    printf '  [%2d/%2d] %-38s' "$i" "${#PAGES[@]}" "$(basename "$p")"
    topdf "$p" "$pdf"
    printf 'p.%s\n' "$(pdfinfo "$pdf" | awk '/^Pages/{print $2}')"
    parts+=("$pdf")
  done
  pdfunite "${parts[@]}" "$OUT/字词表-全书-详细版.pdf"
}

build_compact() {
  echo "精简版 —— vocab/all.html"
  topdf vocab/all.html "$OUT/字词表-全书-精简版.pdf"
}

case "$WHAT" in
  detail)  build_detail ;;
  compact) build_compact ;;
  all)     build_detail; build_compact ;;
  *) echo "用法：$0 [detail|compact|all]" >&2; exit 2 ;;
esac

rm -rf "$TMP"

echo
for f in "$OUT"/字词表-全书-*.pdf; do
  [[ -f "$f" ]] || continue
  printf '%-34s %4s 页  %s\n' "$(basename "$f")" \
    "$(pdfinfo "$f" | awk '/^Pages/{print $2}')" \
    "$(du -h "$f" | cut -f1)"
done
