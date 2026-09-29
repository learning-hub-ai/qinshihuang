#!/usr/bin/env python3
"""把 _frame/ 里的共用横幅、导航、页脚写进每个页面。

用法
----
    python3 _build.py            # 套用到全站
    python3 _build.py --check    # 只检查，不写（看哪些页面会变）
    python3 _build.py index.html # 只处理指定页面

它怎么工作
----------
每个页面里有三对标记，脚本只替换标记**之间**的内容：

    <!-- #frame:head -->  …  <!-- /frame:head -->
    <!-- #frame:nav  -->  …  <!-- /frame:nav  -->
    <!-- #frame:foot -->  …  <!-- /frame:foot -->

标记以外的一切都是你的内容，脚本从不触碰。
所以 how-to-use.html 的正文、maps.html 的地图、任何一节，
都可以照常直接编辑，不需要跑这个脚本。

只有要改**所有页面共有的**横幅／导航／页脚时，才改 _frame/ 再跑一次。

每页的差异怎么表达
------------------
写在页面的 <body> 标签上，脚本读它来定制框架：

    <body data-pagename="地图 · 国家在哪里" data-tab="maps" data-chapter="c3">

    data-pagename  横幅第二行的当前页名（必填）
    data-tab       哪个标签高亮，见 TABS（必填）
    data-chapter   可选，site.js 用它拼「回第N章」的链接

子导航（nv-sub）每页都不同，属于页面内容，不在框架里 ——
它写在 <!-- /frame:nav --> 之后、</nav> 之前。
"""
import argparse
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
FRAME = os.path.join(ROOT, '_frame')

# 标签 key → 导航里的文字。key 写在 <body data-tab="...">
TABS = {
    'guide':   '📖 阅读指引',
    'plan':    '📅 阅读进度表',
    'vocab':   '📚 字词表',
    'maps':    '🗺 地图',
    'chars':   '👥 人物关系表',
    'facts':   '📊 秦始皇小档案',
    'time':    '🔍 一生时间轴',
    'howto':   '📘 使用说明',
}

# 这些页面的当前标签可点（材料页，点了回该分区首页）；
# 其余是分区首页本身，用不可点的 <span>
CLICKABLE_TAB = {
    'vocab': 'vocab/index.html',   # 字词表小节页 → 回字词表目录
    'guide': 'index.html',         # 读懂故事页   → 回阅读指引
}


def load(name):
    with open(os.path.join(FRAME, name), encoding='utf-8') as fh:
        return fh.read().rstrip('\n')


def rel_root(path):
    """页面到站点根目录的相对前缀：根目录是 ''，子目录是 '../'。"""
    depth = len(os.path.normpath(path).split(os.sep)) - 1
    return '../' * depth


def build_nav(tpl, tab, root, page):
    """把导航模板里当前标签那一项换成高亮形式。"""
    label = TABS[tab]
    if tab in CLICKABLE_TAB:
        href = root + CLICKABLE_TAB[tab]
        # 字词表分区首页自己不算材料页
        if page in ('vocab/index.html', 'vocab/star.html', 'vocab/all.html', 'index.html'):
            here = '<span class="nv-here">%s</span>' % label
        else:
            here = '<a class="nv-here" href="%s">%s</a>' % (href, label)
    else:
        here = '<span class="nv-here">%s</span>' % label

    pat = re.compile(r'<a href="[^"]*">%s</a>' % re.escape(label))
    out, n = pat.subn(here, tpl)
    if n != 1:
        raise SystemExit('nav: 在模板里找不到标签 %r（%s）' % (label, page))
    return out


def apply_frame(page, frames, check=False):
    """返回 (changed, message)。"""
    with open(page, encoding='utf-8') as fh:
        src = fh.read()

    body = re.search(r'<body([^>]*)>', src)
    if not body:
        return False, 'skip: 没有 <body>'
    attrs = body.group(1)

    name = re.search(r'data-pagename="([^"]*)"', attrs)
    tab = re.search(r'data-tab="([^"]*)"', attrs)
    if not name or not tab:
        return False, 'skip: <body> 缺 data-pagename 或 data-tab'
    if tab.group(1) not in TABS:
        return False, 'ERROR: data-tab=%r 不认识' % tab.group(1)

    root = rel_root(page)
    blocks = {
        'head': frames['head'].replace('{ROOT}', root)
                              .replace('{PAGENAME}', name.group(1)),
        'nav':  build_nav(frames['nav'], tab.group(1), root, page).replace('{ROOT}', root),
        'foot': frames['foot'].replace('{ROOT}', root),
    }
    # how-to-use 自己页面上，指向版权那节的链接用页内锚点
    if os.path.normpath(page) == 'how-to-use.html':
        blocks['foot'] = blocks['foot'].replace(
            'href="how-to-use.html#copyright">使用说明',
            'href="#copyright">上面这一节')

    out = src
    missing = []
    for key, block in blocks.items():
        pat = re.compile(r'(<!-- #frame:%s -->\n)(.*?)(\n\s*<!-- /frame:%s -->)'
                         % (key, key), re.S)
        if not pat.search(out):
            missing.append(key)
            continue
        out = pat.sub(lambda m: m.group(1) + block + m.group(3), out, count=1)
    if missing:
        return False, 'skip: 缺标记 %s' % ','.join(missing)

    if out == src:
        return False, 'ok（无变化）'
    if not check:
        with open(page, 'w', encoding='utf-8') as fh:
            fh.write(out)
    return True, 'updated' if not check else 'would update'


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('pages', nargs='*', help='要处理的页面（默认全站）')
    ap.add_argument('--check', action='store_true', help='只检查，不写文件')
    args = ap.parse_args()

    os.chdir(ROOT)
    frames = {k: load('%s.html' % k) for k in ('head', 'nav', 'foot')}

    pages = args.pages or sorted(
        glob.glob('*.html') + glob.glob('vocab/*.html') + glob.glob('guide/*.html'))

    changed = errors = 0
    for page in pages:
        try:
            did, msg = apply_frame(page, frames, args.check)
        except SystemExit as exc:
            did, msg = False, 'ERROR: %s' % exc
        if msg.startswith('ERROR'):
            errors += 1
        if did:
            changed += 1
        if did or msg.startswith(('ERROR', 'skip')):
            print('%-36s %s' % (page, msg), file=sys.stderr if errors else sys.stdout)

    print('\n%d 个页面，%s %d 个%s'
          % (len(pages), '需更新' if args.check else '已更新', changed,
             '，%d 个出错' % errors if errors else ''))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
