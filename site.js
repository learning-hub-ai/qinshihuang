/* ==========================================================================
   《秦始皇——一统中国》整本书阅读 — 唯一的一小段脚本
   --------------------------------------------------------------------------
   作用：让「返回」按钮回到**你实际来的那一页**。

   同一份字词表有两个入口：
     · 阅读指引（index.html）        —— 跟着书一节一节读
     · 字词表目录（vocab/index.html）—— 只看生字

   ⚠ 为什么不用 document.referrer：
     本站主要以 file:// 打开，Firefox 在本地文件之间**不传 referrer**
     （实测 document.referrer === ""），所以判断不出来源。

   改用「入口自己报身份」：
     两个目录页的链接都带 ?from=guide 或 ?from=vocab，
     这一页读 location.search 就知道从哪来。没有参数就用 HTML 里的默认值。

   ⚠ 没有 JS 也能用：默认值写死在 HTML 里是「⬆ 字词表目录」。
   ========================================================================== */
(function () {
  var a = document.getElementById('backlink');
  if (!a) return;

  var m = /[?&]from=([a-z]+)/.exec(location.search || '');
  if (!m) return;                      // 没带参数（直接打开、上一节/下一节）→ 用默认值
  if (m[1] !== 'guide') return;        // from=vocab 或其它值 → 默认值就是字词表目录

  // 从阅读指引来：回到它，并直接落在这一节所属的那一章
  var ch = (document.body.getAttribute('data-chapter') || '').trim();
  var name = { c1: '一', c2: '二', c3: '三', c4: '四', c5: '五', c6: '六' }[ch];

  a.setAttribute('href', '../index.html' + (ch ? '#' + ch : ''));
  a.textContent = '↩ 回阅读指引' + (name ? ' · 第' + name + '章' : '');
  a.className = 'nv-back';

  // 上一节 / 下一节也带上来源，否则翻一节就忘了自己是从阅读指引来的
  var links = document.querySelectorAll('.nv-sub a[href$=".html"]');
  for (var i = 0; i < links.length; i++) {
    var h = links[i].getAttribute('href');
    if (/^(chapter\d-section\d|appendix-chronology)\.html$/.test(h)) {
      links[i].setAttribute('href', h + '?from=guide');
    }
  }
})();
