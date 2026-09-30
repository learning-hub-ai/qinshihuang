#!/usr/bin/env bash
# 把字词表打成 PDF —— 第一章到附录，按顺序合成一份。
#
# 用法
# ----
#   ./make_vocab_pdf.sh              # 两份都做
#   ./make_vocab_pdf.sh detail       # 只做详细版（17 节＋附录，带意思和组词）
#   ./make_vocab_pdf.sh compact      # 只做精简版（all.html，1908 条，只有拼音和页码）
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

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/print"
TMP="$OUT/tmp"
WHAT="${1:-all}"

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
  local src="$ROOT/$1" dst="$2"
  [[ -f "$src" ]] || { echo "缺文件：$1" >&2; return 1; }
  timeout 180 google-chrome --headless --disable-gpu --no-sandbox \
      --no-pdf-header-footer --print-to-pdf="$dst" "file://$src" >/dev/null 2>&1
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
