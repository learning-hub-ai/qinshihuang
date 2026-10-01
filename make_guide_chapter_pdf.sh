#!/usr/bin/env bash
# 把「读懂故事」打成 PDF —— 按章合成一份，一章的几节连在一起。
#
# 用法
# ----
#   ./make_guide_chapter_pdf.sh 2                # 第二章，含页脚
#   ./make_guide_chapter_pdf.sh 2 --no-footer    # 第二章，不印页脚
#   ./make_guide_chapter_pdf.sh all              # 所有已完成的章各出一份
#
# 产出在 print/ 下：
#   读懂故事-第N章.pdf
#
# ⚠ --no-footer 去掉页面里那块 <footer class="sitefoot">
#   （浏览器自己的页眉页脚一直用 --no-pdf-header-footer 关着）。
#
#   ⚠⚠ 和字词表不同：「读懂故事」页里**有成段的原文引用**
#   （第二章三节各约 200–330 字，单条最长 50 字），【找句子】整节就是三句原话。
#   所以这里去掉页脚，比在字词表上去掉更需要想清楚。留下来的署名是：
#     · 每页页头「景崇兰 著 · 简志刚 绘 · 人民文学出版社」
#       —— 著作权法第二十四条要的「指明作者姓名、作品名称」；
#     · 每一条引用后面都跟着页码（第二章三节共 46 处）。
#   页头那一行就够满足署名要求。但页脚里那句「不能代替原书 —— 请购买原书」
#   是**额外**的话，不是许可证或法律要求的署名 —— 去掉它不违规，
#   只是少了一句提醒。自家打印给孩子用没问题；
#   要是把 PDF 发给别的老师或家长，建议用带页脚的版本。
#
# 源文件一个字都不改，只在生成 PDF 时套一层打印样式。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/print"
TMP="$OUT/tmp"
NOFOOTER=0
CHAP=""

for arg in "$@"; do
  case "$arg" in
    --no-footer) NOFOOTER=1 ;;
    [1-6]|all)   CHAP="$arg" ;;
    *) echo "不认识的参数：$arg" >&2
       echo "用法：$0 <章号 1-6|all> [--no-footer]" >&2; exit 2 ;;
  esac
done
[[ -n "$CHAP" ]] || { echo "用法：$0 <章号 1-6|all> [--no-footer]" >&2; exit 2; }

mkdir -p "$TMP"

topdf() {   # topdf <相对路径> <输出 pdf>
  local src="$ROOT/$1" dst="$2" render="$ROOT/$1"
  [[ -f "$src" ]] || { echo "缺文件：$1" >&2; return 1; }

  # 临时副本必须放在**同一个目录**（guide/ 下），否则 ../site.css、
  # ../site.js 这些相对路径会失效，页面会失去全部样式。
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

build_chapter() {
  local n="$1"
  # 只取实际存在的节 —— 「读懂故事」还没写完，缺的节直接跳过
  local pages=()
  for f in "$ROOT"/guide/chapter${n}-section*.html; do
    [[ -f "$f" ]] && pages+=("guide/$(basename "$f")")
  done
  if (( ${#pages[@]} == 0 )); then
    echo "第 ${n} 章还没有「读懂故事」页面，跳过"
    return 0
  fi

  echo "第 ${n} 章 —— ${#pages[@]} 节"
  local parts=() i=0
  for p in "${pages[@]}"; do
    i=$((i+1))
    local pdf; pdf="$(printf '%s/g%02d.pdf' "$TMP" "$i")"
    printf '  [%d/%d] %-30s' "$i" "${#pages[@]}" "$(basename "$p")"
    topdf "$p" "$pdf"
    printf '%2s 页\n' "$(pdfinfo "$pdf" | awk '/^Pages/{print $2}')"
    parts+=("$pdf")
  done

  local dst="$OUT/读懂故事-第${n}章.pdf"
  if (( ${#parts[@]} == 1 )); then cp "${parts[0]}" "$dst"
  else pdfunite "${parts[@]}" "$dst"; fi
  rm -f "$TMP"/g*.pdf

  printf '  → %-26s %3s 页  %s\n\n' "$(basename "$dst")" \
    "$(pdfinfo "$dst" | awk '/^Pages/{print $2}')" "$(du -h "$dst" | cut -f1)"
}

if [[ "$CHAP" == "all" ]]; then
  for n in 1 2 3 4 5 6; do build_chapter "$n"; done
else
  build_chapter "$CHAP"
fi

rm -rf "$TMP"
