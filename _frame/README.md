# 共用框架

这三个文件是**全站 30 个页面共有的**横幅、导航、页脚。只写一份。

```
head.html   顶部横幅（书名、当前页名、作者出版社那一行）
nav.html    八个标签的导航栏
foot.html   页脚（页码说明、打印提示、版权与「请购买原书」）
```

## 改框架

改这里的文件，然后跑一次：

```bash
python3 _build.py            # 套用到全站
python3 _build.py --check    # 只看会改哪些页，不写
```

## 改页面内容

**直接编辑那个 HTML 文件就行，不用跑 `_build.py`。**

每个页面里有三对标记，脚本只替换标记**之间**的内容：

```html
<!-- #frame:foot -->
  …这里是脚本管的，手改会被覆盖…
<!-- /frame:foot -->
```

标记以外的一切都是页面自己的内容，脚本从不触碰。所以
`how-to-use.html` 的正文、`maps.html` 的地图和导读、
任何一节的文字，都可以照常直接改。

## 每页的差异写在哪

写在 `<body>` 标签上：

```html
<body data-pagename="地图 · 国家在哪里，为什么重要" data-tab="maps" data-chapter="c3">
```

| 属性 | 作用 |
|---|---|
| `data-pagename` | 横幅第二行的当前页名（必填） |
| `data-tab` | 哪个标签高亮：`guide plan vocab maps chars facts time howto`（必填） |
| `data-chapter` | 可选，`site.js` 用它拼「回第 N 章」的链接 |

子导航（`nv-sub`，第二行那些链接）每页都不同，属于页面内容，
写在 `<!-- /frame:nav -->` 之后、`</nav>` 之前。

## 为什么不用 JavaScript 生成框架

这个站主要**打印**给学生用，也常以 `file://` 直接打开。
如果横幅和页脚靠 JS 生成，一旦脚本没跑起来或打印时机不对，
页眉页脚就会缺失。用构建脚本预先写进 HTML，每个页面都是
自包含的，打印和离线都可靠。

## 改完记得检查

```bash
python3 _build.py --check    # 应该显示「需更新 0 个」
```
