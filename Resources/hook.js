/* Yumi hook — перехват медиапотоков и мелкая чистка страницы.
 * Работает во всех фреймах (main + iframes), на iOS 12.
 */
(function () {
  if (window.__yumiHooked) return;
  window.__yumiHooked = true;

  var MAX_URL = 4096;
  var seen = Object.create(null);

  function send(payload) {
    try {
      if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.yumi) return;
      window.webkit.messageHandlers.yumi.postMessage(payload);
    } catch (e) {}
  }

  function abs(u) {
    try { return new URL(u, document.baseURI || location.href).href; }
    catch (e) { return String(u || ''); }
  }

  function kindOf(u) {
    var s = u.split('#')[0].split('?')[0].toLowerCase();
    if (/\.m3u8$/.test(s)) return 'hls';
    if (/\.mpd$/.test(s)) return 'dash';
    if (/\.(mp4|m4v|mov)$/.test(s)) return 'mp4';
    if (/\.webm$/.test(s)) return 'webm';
    if (/\.(ts|m4s|aac)$/.test(s)) return null; /* сегменты не интересны */
    if (/(master|playlist|manifest|index)\.m3u8/.test(s)) return 'hls';
    return null;
  }

  function looksLikeAd(u) {
    var s = u.toLowerCase();
    return /(vast|preroll|pre-roll|midroll|doubleclick|googlesyndication|adfox|adservice|an\.yandex|adsystem|\/ads?\/|popunder|adsterra|propellerads)/.test(s);
  }

  function report(raw, why) {
    try {
      if (!raw || typeof raw !== 'string') return;
      if (raw.slice(0, 5) === 'blob:' || raw.slice(0, 5) === 'data:') return;
      var u = abs(raw);
      if (!/^https?:/i.test(u)) return;
      if (u.length > MAX_URL) return;
      var kind = kindOf(u);
      if (!kind) return;
      if (seen[u]) return;
      seen[u] = 1;
      var n = 0; for (var k in seen) { n++; if (n > 80) delete seen[k]; }
      send({
        type: 'stream',
        url: u,
        kind: kind,
        page: location.href,
        title: document.title || '',
        top: (window === window.top) ? 1 : 0,
        why: why || '',
        ad: looksLikeAd(u) ? 1 : 0
      });
    } catch (e) {}
  }

  function checkUrl(u, why) {
    if (!u) return;
    if (typeof u === 'object') {
      if (u.url) checkUrl(u.url, why);
      return;
    }
    report(u, why);
  }

  /* ---- fetch ---- */
  try {
    var nativeFetch = window.fetch;
    if (nativeFetch) {
      window.fetch = function (input) {
        try { checkUrl(input, 'fetch'); } catch (e) {}
        return nativeFetch.apply(this, arguments);
      };
    }
  } catch (e) {}

  /* ---- XHR ---- */
  try {
    var nativeOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method, url) {
      try { checkUrl(url, 'xhr'); } catch (e) {}
      return nativeOpen.apply(this, arguments);
    };
  } catch (e) {}

  /* ---- HTMLMediaElement.src ---- */
  try {
    var desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
    if (desc && desc.set && desc.get) {
      Object.defineProperty(HTMLMediaElement.prototype, 'src', {
        configurable: true,
        enumerable: desc.enumerable,
        get: desc.get,
        set: function (v) { try { checkUrl(v, 'media.src'); } catch (e) {} return desc.set.call(this, v); }
      });
    }
  } catch (e) {}

  /* ---- setAttribute('src') для video/source ---- */
  try {
    var nativeSetAttr = Element.prototype.setAttribute;
    Element.prototype.setAttribute = function (name, value) {
      try {
        if (String(name).toLowerCase() === 'src') {
          var tag = this.tagName ? this.tagName.toLowerCase() : '';
          if (tag === 'video' || tag === 'audio' || tag === 'source') checkUrl(value, 'setAttribute');
        }
      } catch (e) {}
      return nativeSetAttr.apply(this, arguments);
    };
  } catch (e) {}

  /* ---- window.open: нативные попапы обрабатывает WKUIDelegate ---- */

  /* ---- сканирование DOM ---- */
  function scan() {
    try {
      var list = document.querySelectorAll('video, audio, source');
      for (var i = 0; i < list.length; i++) {
        var el = list[i];
        var src = el.currentSrc || el.src || el.getAttribute('src');
        if (src) checkUrl(src, 'dom');
      }
    } catch (e) {}
  }
  var scanCount = 0;
  var scanTimer = setInterval(function () {
    scan();
    if (++scanCount > 40) clearInterval(scanTimer); /* первые ~2 минуты */
  }, 3000);
  try {
    document.addEventListener('DOMContentLoaded', scan);
    window.addEventListener('load', scan);
    var mo = new MutationObserver(function (muts) {
      for (var i = 0; i < muts.length; i++) {
        var nodes = muts[i].addedNodes || [];
        for (var j = 0; j < nodes.length; j++) {
          var n = nodes[j];
          if (n.nodeType !== 1) continue;
          var tag = n.tagName ? n.tagName.toLowerCase() : '';
          if (tag === 'video' || tag === 'audio' || tag === 'source') scan();
          else if (n.querySelector && n.querySelector('video,audio,source')) scan();
        }
      }
    });
    if (document.documentElement) {
      mo.observe(document.documentElement, { childList: true, subtree: true });
    }
  } catch (e) {}

  /* ---- хелпер: остановить всё медиа перед нативным плеером ---- */
  window.__yumiPauseAll = function () {
    try {
      var v = document.querySelectorAll('video, audio');
      for (var i = 0; i < v.length; i++) { try { v[i].pause(); } catch (e) {} }
    } catch (e) {}
  };

  /* ---- лёгкая косметика ---- */
  function makeup() {
    try {
      var css = 'ins.adsbygoogle,iframe[src*="doubleclick.net"],iframe[src*="googlesyndication.com"],' +
        'iframe[src*="adfox.ru"],iframe[src*="an.yandex.ru"],iframe[src*="ad.mail.ru"],' +
        '.adsbygoogle,#adfox,.adfox-banner,.popunder,[id^="adfox_"]{display:none!important;}' +
        '#yumi-badge{display:none!important;}';
      var st = document.createElement('style');
      st.type = 'text/css';
      st.appendChild(document.createTextNode(css));
      (document.head || document.documentElement).appendChild(st);
    } catch (e) {}
  }
  if (document.documentElement) makeup();
  else document.addEventListener('DOMContentLoaded', makeup);

  /* ---- самопроверка ---- */
  send({ type: 'hello', page: location.href, top: (window === window.top) ? 1 : 0 });
})();
