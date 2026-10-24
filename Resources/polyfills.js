/* Yumi polyfills — минимум для WebKit iOS 12 (Safari 12).
 * Никакого синтаксиса новее ES2017: сам файл должен парситься на iOS 12.
 */
(function () {
  var g = (typeof globalThis !== 'undefined') ? globalThis
        : (typeof window !== 'undefined' ? window : this);
  if (!g) return;

  try {
    if (!g.globalThis) Object.defineProperty(g, 'globalThis', { value: g, configurable: true, writable: true });
  } catch (e) {}

  /* ---------- Promise ---------- */
  if (typeof Promise !== 'undefined') {
    if (!Promise.prototype['finally']) {
      Promise.prototype['finally'] = function (cb) {
        var C = this.constructor || Promise;
        return this.then(function (v) {
          return C.resolve(cb()).then(function () { return v; });
        }, function (err) {
          return C.resolve(cb()).then(function () { throw err; });
        });
      };
    }
    if (!Promise.allSettled) {
      Promise.allSettled = function (list) {
        return Promise.all(Array.prototype.map.call(list, function (p) {
          return Promise.resolve(p).then(function (value) {
            return { status: 'fulfilled', value: value };
          }, function (reason) {
            return { status: 'rejected', reason: reason };
          });
        }));
      };
    }
    if (!Promise.any) {
      Promise.any = function (list) {
        return new Promise(function (resolve, reject) {
          var arr = Array.prototype.slice.call(list), left = arr.length, errors = [];
          if (!left) return reject(new Error('AggregateError: no promises'));
          arr.forEach(function (p, i) {
            Promise.resolve(p).then(resolve, function (e) { errors[i] = e; if (--left === 0) reject(errors[0]); });
          });
        });
      };
    }
  }

  /* ---------- Object ---------- */
  if (!Object.fromEntries) {
    Object.fromEntries = function (iter) {
      var o = {};
      if (!iter) return o;
      if (typeof Symbol !== 'undefined' && iter[Symbol.iterator]) {
        var it = iter[Symbol.iterator](), step;
        while (!(step = it.next()).done) o[step.value[0]] = step.value[1];
      } else {
        Array.prototype.forEach.call(iter, function (pair) { o[pair[0]] = pair[1]; });
      }
      return o;
    };
  }
  if (!Object.hasOwn) {
    Object.hasOwn = function (obj, key) { return Object.prototype.hasOwnProperty.call(obj, key); };
  }
  if (!Object.is) {
    Object.is = function (a, b) { return a === b ? (a !== 0 || 1 / a === 1 / b) : (a !== a && b !== b); };
  }

  /* ---------- Array ---------- */
  if (!Array.prototype.flat) {
    Array.prototype.flat = function (depth) {
      var d = depth === undefined ? 1 : depth;
      var out = [];
      (function walk(arr, level) {
        Array.prototype.forEach.call(arr, function (x) {
          if (Array.isArray(x) && level > 0) walk(x, level - 1);
          else out.push(x);
        });
      })(this, d);
      return out;
    };
  }
  if (!Array.prototype.flatMap) {
    Array.prototype.flatMap = function (fn, ctx) {
      return Array.prototype.flat.call(Array.prototype.map.call(this, fn, ctx), 1);
    };
  }
  if (!Array.prototype.at) {
    Array.prototype.at = function (i) {
      i = Math.trunc(i) || 0;
      if (i < 0) i += this.length;
      return (i < 0 || i >= this.length) ? undefined : this[i];
    };
  }
  if (!Array.prototype.findLast) {
    Array.prototype.findLast = function (fn, ctx) {
      for (var i = this.length - 1; i >= 0; i--) if (fn.call(ctx, this[i], i, this)) return this[i];
      return undefined;
    };
  }
  if (!Array.prototype.findLastIndex) {
    Array.prototype.findLastIndex = function (fn, ctx) {
      for (var i = this.length - 1; i >= 0; i--) if (fn.call(ctx, this[i], i, this)) return i;
      return -1;
    };
  }
  if (!Array.prototype.toSorted) {
    Array.prototype.toSorted = function (cmp) { return Array.prototype.slice.call(this).sort(cmp); };
  }

  /* ---------- String ---------- */
  if (!String.prototype.at) {
    String.prototype.at = function (i) {
      i = Math.trunc(i) || 0;
      if (i < 0) i += this.length;
      return (i < 0 || i >= this.length) ? undefined : this.charAt(i);
    };
  }
  if (!String.prototype.replaceAll) {
    String.prototype.replaceAll = function (search, repl) {
      if (search instanceof RegExp) {
        if (!search.global) throw new TypeError('replaceAll must be called with a global RegExp');
        return this.replace(search, repl);
      }
      return this.split(String(search)).join(repl);
    };
  }
  if (!String.prototype.matchAll) {
    String.prototype.matchAll = function (re) {
      var rx = new RegExp(re.source, re.flags.indexOf('g') >= 0 ? re.flags : re.flags + 'g');
      var str = String(this), out = [], m;
      while ((m = rx.exec(str)) !== null) {
        out.push(m);
        if (m[0] === '') rx.lastIndex++;
      }
      return out[Symbol.iterator]();
    };
  }
  if (!String.prototype.trimStart) {
    String.prototype.trimStart = String.prototype.trimLeft || function () { return this.replace(/^\s+/, ''); };
  }
  if (!String.prototype.trimEnd) {
    String.prototype.trimEnd = String.prototype.trimRight || function () { return this.replace(/\s+$/, ''); };
  }

  /* ---------- DOM ---------- */
  if (typeof Element !== 'undefined') {
    if (!Element.prototype.replaceChildren) {
      Element.prototype.replaceChildren = function () {
        while (this.firstChild) this.removeChild(this.firstChild);
        for (var i = 0; i < arguments.length; i++) {
          var n = arguments[i];
          this.appendChild(typeof n === 'string' ? document.createTextNode(n) : n);
        }
      };
    }
    if (!Element.prototype.toggleAttribute) {
      Element.prototype.toggleAttribute = function (name, force) {
        var has = this.hasAttribute(name);
        var want = force === undefined ? !has : !!force;
        if (want && !has) this.setAttribute(name, '');
        if (!want && has) this.removeAttribute(name);
        return want;
      };
    }
    if (!Element.prototype.replaceWith) {
      Element.prototype.replaceWith = function () {
        var parent = this.parentNode;
        if (!parent) return;
        var frag = document.createDocumentFragment();
        for (var i = 0; i < arguments.length; i++) {
          var n = arguments[i];
          frag.appendChild(typeof n === 'string' ? document.createTextNode(n) : n);
        }
        parent.replaceChild(frag, this);
      };
    }
  }
  if (typeof NodeList !== 'undefined' && NodeList.prototype && !NodeList.prototype.forEach) {
    NodeList.prototype.forEach = Array.prototype.forEach;
  }

  /* ---------- misc globals ---------- */
  if (!g.queueMicrotask) {
    g.queueMicrotask = function (fn) {
      Promise.resolve().then(function () {
        try { fn(); } catch (e) { setTimeout(function () { throw e; }, 0); }
      });
    };
  }
  if (!g.requestIdleCallback) {
    g.requestIdleCallback = function (cb) {
      var start = Date.now();
      return setTimeout(function () {
        cb({ didTimeout: false, timeRemaining: function () { return Math.max(0, 50 - (Date.now() - start)); } });
      }, 1);
    };
    g.cancelIdleCallback = function (id) { clearTimeout(id); };
  }
  if (typeof AbortController === 'undefined') {
    g.AbortController = function () {
      var signal = { aborted: false, onabort: null, addEventListener: function (t, fn) { if (t === 'abort') this.onabort = fn; }, removeEventListener: function () {} };
      this.signal = signal;
      this.abort = function () {
        if (signal.aborted) return;
        signal.aborted = true;
        var ev = { type: 'abort', target: signal };
        if (typeof signal.onabort === 'function') signal.onabort(ev);
      };
    };
    g.AbortSignal = function () {};
  }
  if (typeof structuredClone === 'undefined') {
    var yumiClone = function (value, seen) {
      if (value === null || typeof value !== 'object') return value;
      if (typeof Blob !== 'undefined' && value instanceof Blob) return value;
      if (!seen) { try { seen = new WeakMap(); } catch (e) { seen = null; } }
      if (seen) {
        var hit = seen.get(value);
        if (hit) return hit;
      }
      var out, i;
      if (value instanceof Date) out = new Date(value.getTime());
      else if (value instanceof RegExp) out = new RegExp(value.source, value.flags);
      else if (typeof ArrayBuffer !== 'undefined' && value instanceof ArrayBuffer) out = value.slice(0);
      else if (typeof ArrayBuffer !== 'undefined' && ArrayBuffer.isView(value)) {
        if (typeof DataView !== 'undefined' && value instanceof DataView) {
          out = new DataView(value.buffer.slice(0));
        } else {
          out = new value.constructor(value.length);
          out.set(value);
        }
      } else if (typeof Map !== 'undefined' && value instanceof Map) {
        out = new Map();
        if (seen) seen.set(value, out);
        value.forEach(function (v, k) { out.set(yumiClone(k, seen), yumiClone(v, seen)); });
        return out;
      } else if (typeof Set !== 'undefined' && value instanceof Set) {
        out = new Set();
        if (seen) seen.set(value, out);
        value.forEach(function (v) { out.add(yumiClone(v, seen)); });
        return out;
      } else if (Array.isArray(value)) {
        out = [];
        if (seen) seen.set(value, out);
        for (i = 0; i < value.length; i++) out[i] = yumiClone(value[i], seen);
        return out;
      } else {
        out = {};
        if (seen) seen.set(value, out);
        for (i in value) {
          if (Object.prototype.hasOwnProperty.call(value, i)) out[i] = yumiClone(value[i], seen);
        }
        return out;
      }
      if (seen) seen.set(value, out);
      return out;
    };
    g.structuredClone = function (obj) { return yumiClone(obj, null); };
  }
  if (typeof WeakRef === 'undefined') {
    g.WeakRef = function (o) { this.deref = function () { return o; }; };
  }
  if (typeof FinalizationRegistry === 'undefined') {
    g.FinalizationRegistry = function () {};
    g.FinalizationRegistry.prototype.register = function () {};
    g.FinalizationRegistry.prototype.unregister = function () {};
  }
  if (typeof crypto === 'undefined') g.crypto = {};
  if (crypto && !crypto.randomUUID) {
    crypto.randomUUID = function () {
      var b = new Uint8Array(16);
      if (crypto.getRandomValues) crypto.getRandomValues(b);
      else for (var i = 0; i < 16; i++) b[i] = Math.floor(Math.random() * 256);
      b[6] = (b[6] & 0x0f) | 0x40;
      b[8] = (b[8] & 0x3f) | 0x80;
      var h = Array.prototype.map.call(b, function (x) { return ('0' + x.toString(16)).slice(-2); }).join('');
      return h.slice(0, 8) + '-' + h.slice(8, 12) + '-' + h.slice(12, 16) + '-' + h.slice(16, 20) + '-' + h.slice(20);
    };
  }

  /* ---------- IntersectionObserver (нативный есть с iOS 12.2) ---------- */
  if (typeof IntersectionObserver === 'undefined') {
    var ioList = [];
    var ioScan = function () {
      var vh = window.innerHeight || 800, vw = window.innerWidth || 400;
      ioList.slice().forEach(function (io) {
        io._targets.slice().forEach(function (entry) {
          var el = entry.target, r;
          try { r = el.getBoundingClientRect(); } catch (e) { return; }
          var visible = r.top < vh && r.bottom > 0 && r.left < vw && r.right > 0;
          var ratio = 0;
          if (visible && r.width && r.height) {
            var h = Math.min(r.bottom, vh) - Math.max(r.top, 0);
            var w = Math.min(r.right, vw) - Math.max(r.left, 0);
            ratio = Math.max(0, Math.min(1, (h * w) / (r.width * r.height)));
          }
          var was = !!entry.isIntersecting;
          entry.isIntersecting = visible;
          entry.intersectionRatio = ratio;
          entry.boundingClientRect = r;
          if (was !== visible || ratio > 0) {
            try { io._cb([entry], io); } catch (e) {}
          }
        });
      });
    };
    var ioQueue = function () {
      if (ioScan._q) return;
      ioScan._q = true;
      setTimeout(function () { ioScan._q = false; ioScan(); }, 100);
    };
    g.IntersectionObserver = function (cb, opts) {
      this._cb = cb;
      this._targets = [];
      this.root = (opts && opts.root) || null;
      this.thresholds = (opts && opts.threshold) || [0];
      ioList.push(this);
    };
    g.IntersectionObserver.prototype.observe = function (el) {
      this._targets.push({ target: el, isIntersecting: false, intersectionRatio: 0 });
      ioQueue();
      if (!ioScan._hooked) {
        ioScan._hooked = true;
        window.addEventListener('scroll', ioQueue, true);
        window.addEventListener('resize', ioQueue, true);
        setInterval(ioQueue, 1000);
      }
    };
    g.IntersectionObserver.prototype.unobserve = function (el) {
      this._targets = this._targets.filter(function (t) { return t.target !== el; });
    };
    g.IntersectionObserver.prototype.disconnect = function () { this._targets = []; };
    g.IntersectionObserver.prototype.takeRecords = function () { return []; };
  }

  /* ---------- ResizeObserver (нет в iOS 12) ---------- */
  if (typeof ResizeObserver === 'undefined') {
    var roList = [];
    var roTimer = null;
    var roScan = function () {
      roList.slice().forEach(function (ro) {
        ro._map.forEach(function (last, el) {
          var r = el.getBoundingClientRect();
          if (!last || last.width !== r.width || last.height !== r.height) {
            ro._map.set(el, { width: r.width, height: r.height });
            if (last) {
              var box = { width: r.width, height: r.height };
              try {
                ro._cb([{
                  target: el,
                  contentRect: { x: r.x, y: r.y, top: r.top, left: r.left, bottom: r.bottom,
                                 right: r.right, width: r.width, height: r.height },
                  borderBoxSize: [box], contentBoxSize: [box], devicePixelContentBoxSize: [box]
                }], ro);
              } catch (e) {}
            }
          }
        });
      });
    };
    g.ResizeObserver = function (cb) {
      this._cb = cb;
      this._map = new Map();
      roList.push(this);
      if (!roTimer) roTimer = setInterval(roScan, 500);
    };
    g.ResizeObserver.prototype.observe = function (el) {
      this._map.set(el, null);
      var self = this;
      setTimeout(function () {
        var r = el.getBoundingClientRect();
        var box = { width: r.width, height: r.height };
        self._map.set(el, box);
        try {
          self._cb([{
            target: el,
            contentRect: { x: r.x, y: r.y, top: r.top, left: r.left, bottom: r.bottom,
                           right: r.right, width: r.width, height: r.height },
            borderBoxSize: [box], contentBoxSize: [box], devicePixelContentBoxSize: [box]
          }], self);
        } catch (e) {}
      }, 0);
    };
    g.ResizeObserver.prototype.unobserve = function (el) { this._map.delete(el); };
    g.ResizeObserver.prototype.disconnect = function () { this._map.clear(); };
  }

  /* ---------- Captcha / modern-widget compatibility ----------
   * reCAPTCHA, hCaptcha, Turnstile and SmartCaptcha are transpiled to
   * ES2017, but they probe a lot of newer browser APIs. Missing APIs often
   * turn into an empty widget or a silent failure, so add conservative
   * fallbacks. Native implementations are never replaced.
   */
  try {
    if (!g.AggregateError) {
      g.AggregateError = function (errors, message) {
        var e = new Error(message || 'All promises were rejected');
        e.name = 'AggregateError';
        e.errors = errors || [];
        return e;
      };
    }

    if (typeof Node !== 'undefined' && !('isConnected' in Node.prototype)) {
      Object.defineProperty(Node.prototype, 'isConnected', {
        configurable: true,
        get: function () {
          try { return document.documentElement.contains(this); } catch (e) { return false; }
        }
      });
    }

    var makeIterable = function (proto) {
      if (!proto || typeof Symbol === 'undefined' || !Symbol.iterator) return;
      if (!proto[Symbol.iterator]) proto[Symbol.iterator] = Array.prototype[Symbol.iterator];
    };
    try { makeIterable(NodeList.prototype); } catch (e) {}
    try { makeIterable(HTMLCollection.prototype); } catch (e) {}
    try { makeIterable(DOMTokenList.prototype); } catch (e) {}
    try { makeIterable(NamedNodeMap.prototype); } catch (e) {}
    try { makeIterable(FileList.prototype); } catch (e) {}
    try { makeIterable(TouchList.prototype); } catch (e) {}

    if (typeof Element !== 'undefined') {
      if (!Element.prototype.append) {
        Element.prototype.append = function () {
          var frag = document.createDocumentFragment();
          for (var i = 0; i < arguments.length; i++) {
            var n = arguments[i];
            frag.appendChild(typeof n === 'string' ? document.createTextNode(n) : n);
          }
          this.appendChild(frag);
        };
      }
      if (!Element.prototype.prepend) {
        Element.prototype.prepend = function () {
          var frag = document.createDocumentFragment();
          for (var i = 0; i < arguments.length; i++) {
            var n = arguments[i];
            frag.appendChild(typeof n === 'string' ? document.createTextNode(n) : n);
          }
          this.insertBefore(frag, this.firstChild);
        };
      }
      if (!Element.prototype.before) {
        Element.prototype.before = function () {
          var parent = this.parentNode;
          if (!parent) return;
          var frag = document.createDocumentFragment();
          for (var i = 0; i < arguments.length; i++) {
            var n = arguments[i];
            frag.appendChild(typeof n === 'string' ? document.createTextNode(n) : n);
          }
          parent.insertBefore(frag, this);
        };
      }
      if (!Element.prototype.after) {
        Element.prototype.after = function () {
          var parent = this.parentNode;
          if (!parent) return;
          var frag = document.createDocumentFragment();
          for (var i = 0; i < arguments.length; i++) {
            var n = arguments[i];
            frag.appendChild(typeof n === 'string' ? document.createTextNode(n) : n);
          }
          parent.insertBefore(frag, this.nextSibling);
        };
      }
      if (!Element.prototype.getAttributeNames) {
        Element.prototype.getAttributeNames = function () {
          var out = [];
          for (var i = 0; i < this.attributes.length; i++) out.push(this.attributes[i].name);
          return out;
        };
      }
      if (!Element.prototype.getAnimations) {
        Element.prototype.getAnimations = function () { return []; };
      }
      if (!Element.prototype.setPointerCapture) {
        Element.prototype.setPointerCapture = function () {};
      }
      if (!Element.prototype.releasePointerCapture) {
        Element.prototype.releasePointerCapture = function () {};
      }
      if (!Element.prototype.hasPointerCapture) {
        Element.prototype.hasPointerCapture = function () { return false; };
      }
      if (!Element.prototype.animate) {
        Element.prototype.animate = function (keyframes, options) {
          var el = this;
          var duration = 0, delay = 0;
          if (typeof options === 'number') duration = options;
          else if (options) {
            duration = Number(options.duration) || 0;
            delay = Number(options.delay) || 0;
          }
          var apply = function () {
            var frame = null;
            if (Array.isArray(keyframes)) frame = keyframes[keyframes.length - 1] || null;
            else if (keyframes && typeof keyframes === 'object') frame = keyframes;
            if (!frame) return;
            for (var key in frame) {
              if (key === 'offset' || key === 'easing' || key === 'composite') continue;
              var value = frame[key];
              try {
                if (key === 'cssText') el.style.cssText = value;
                else if (key.indexOf('-') >= 0) el.style.setProperty(key, value);
                else el.style[key] = value;
              } catch (e) {}
            }
          };
          var resolveFinished = null;
          var finished = new Promise(function (resolve) { resolveFinished = resolve; });
          var timer = null;
          var anim = {
            finished: finished,
            ready: Promise.resolve(),
            onfinish: null,
            oncancel: null,
            playState: 'running',
            currentTime: 0,
            startTime: 0,
            playbackRate: 1,
            effect: {
              target: el,
              getComputedTiming: function () { return { duration: duration, delay: delay }; }
            },
            cancel: function () {
              if (timer) clearTimeout(timer);
              anim.playState = 'idle';
            },
            finish: function () {
              if (timer) clearTimeout(timer);
              apply();
              anim.playState = 'finished';
              anim.currentTime = duration + delay;
              try {
                if (typeof anim.onfinish === 'function') {
                  anim.onfinish({ type: 'finish', target: anim });
                }
              } catch (e) {}
              if (resolveFinished) resolveFinished(anim);
            },
            play: function () { anim.playState = 'running'; },
            pause: function () { anim.playState = 'paused'; },
            reverse: function () {},
            commitStyles: function () {},
            persist: function () {},
            updatePlaybackRate: function (rate) { anim.playbackRate = Number(rate) || 1; }
          };
          if (duration <= 0 && delay <= 0) {
            anim.finish();
          } else {
            timer = setTimeout(function () { anim.finish(); }, Math.max(0, duration + delay));
          }
          return anim;
        };
      }
    }

    if (typeof DocumentFragment !== 'undefined' && Element.prototype.replaceChildren) {
      if (!DocumentFragment.prototype.replaceChildren) {
        DocumentFragment.prototype.replaceChildren = Element.prototype.replaceChildren;
      }
    }

    if (typeof Document !== 'undefined' && !Document.prototype.getAnimations) {
      Document.prototype.getAnimations = function () { return []; };
    }

    if (!document.timeline) {
      document.timeline = { currentTime: 0 };
    }

    if (!g.CSS) g.CSS = {};
    if (!g.CSS.escape) {
      g.CSS.escape = function (value) {
        return String(value).replace(/[^a-zA-Z0-9_\u00A0-\uFFFF-]/g, function (ch) {
          return '\\' + ch.charCodeAt(0).toString(16) + ' ';
        });
      };
    }

    if (!g.requestAnimationFrame) {
      g.requestAnimationFrame = function (fn) { return setTimeout(function () { fn(Date.now()); }, 16); };
      g.cancelAnimationFrame = function (id) { clearTimeout(id); };
    }

    if (!g.performance) g.performance = {};
    if (!g.performance.now) {
      var perfStart = Date.now();
      g.performance.now = function () { return Date.now() - perfStart; };
    }
    if (!g.performance.mark) g.performance.mark = function () {};
    if (!g.performance.measure) g.performance.measure = function () {};
    if (!g.performance.getEntriesByName) g.performance.getEntriesByName = function () { return []; };
    if (!g.performance.getEntriesByType) g.performance.getEntriesByType = function () { return []; };

    if (!g.PerformanceObserver) {
      g.PerformanceObserver = function (callback) { this._callback = callback; };
      g.PerformanceObserver.prototype.observe = function () {};
      g.PerformanceObserver.prototype.disconnect = function () {};
      g.PerformanceObserver.prototype.takeRecords = function () { return []; };
      g.PerformanceObserver.supportedEntryTypes = [];
    }
    if (!g.ReportingObserver) {
      g.ReportingObserver = function (callback) { this._callback = callback; };
      g.ReportingObserver.prototype.observe = function () {};
      g.ReportingObserver.prototype.disconnect = function () {};
      g.ReportingObserver.prototype.takeRecords = function () { return []; };
    }

    var makeTarget = function (obj) {
      if (!obj.addEventListener) obj.addEventListener = function () {};
      if (!obj.removeEventListener) obj.removeEventListener = function () {};
      if (!obj.dispatchEvent) obj.dispatchEvent = function () { return true; };
      return obj;
    };

    if (!g.visualViewport) {
      var vv = makeTarget({
        width: g.innerWidth || 0,
        height: g.innerHeight || 0,
        offsetLeft: 0,
        offsetTop: 0,
        pageLeft: g.pageXOffset || 0,
        pageTop: g.pageYOffset || 0,
        scale: 1
      });
      var updateVV = function () {
        vv.width = g.innerWidth || 0;
        vv.height = g.innerHeight || 0;
        vv.pageLeft = g.pageXOffset || 0;
        vv.pageTop = g.pageYOffset || 0;
      };
      g.addEventListener('resize', updateVV, false);
      g.addEventListener('scroll', updateVV, false);
      try { Object.defineProperty(g, 'visualViewport', { value: vv, configurable: true }); }
      catch (e) { g.visualViewport = vv; }
    }

    if (typeof screen !== 'undefined' && !screen.orientation) {
      var orientation = makeTarget({
        type: (g.innerWidth || 0) > (g.innerHeight || 0) ? 'landscape-primary' : 'portrait-primary',
        angle: 0,
        lock: function () { return Promise.reject(new Error('Orientation lock is not supported')); },
        unlock: function () {}
      });
      try { Object.defineProperty(screen, 'orientation', { value: orientation, configurable: true }); }
      catch (e) { screen.orientation = orientation; }
    }

    if (typeof document !== 'undefined' && !document.fonts) {
      var fonts = makeTarget({
        ready: Promise.resolve(),
        status: 'loaded',
        check: function () { return true; },
        load: function () { return Promise.resolve([]); }
      });
      try { Object.defineProperty(document, 'fonts', { value: fonts, configurable: true }); }
      catch (e) { document.fonts = fonts; }
    }

    if (typeof HTMLFormElement !== 'undefined' && !HTMLFormElement.prototype.requestSubmit) {
      HTMLFormElement.prototype.requestSubmit = function (submitter) {
        if (submitter && submitter.form !== this) throw new Error('Submitter is not owned by this form');
        if (this.reportValidity && !this.reportValidity()) return;
        this.submit();
      };
    }

    // Safari 12 predates the Storage Access API. ITP is disabled in Yumi, so
    // storage is available; expose the API for widgets that feature-detect it.
    if (typeof document !== 'undefined' && !document.hasStorageAccess) {
      document.hasStorageAccess = function () { return Promise.resolve(true); };
    }
    if (typeof document !== 'undefined' && !document.requestStorageAccess) {
      document.requestStorageAccess = function () { return Promise.resolve(); };
    }
    if (typeof g.crossOriginIsolated === 'undefined') {
      g.crossOriginIsolated = false;
    }

    if (typeof PointerEvent === 'undefined') {
      var PointerEventFallback = function (type, init) {
        var e = new MouseEvent(type, init || {});
        try {
          Object.defineProperty(e, 'pointerId', { value: (init && init.pointerId) || 1 });
          Object.defineProperty(e, 'width', { value: (init && init.width) || 1 });
          Object.defineProperty(e, 'height', { value: (init && init.height) || 1 });
          Object.defineProperty(e, 'pressure', { value: (init && init.pressure) || 0 });
          Object.defineProperty(e, 'tiltX', { value: (init && init.tiltX) || 0 });
          Object.defineProperty(e, 'tiltY', { value: (init && init.tiltY) || 0 });
          Object.defineProperty(e, 'pointerType', { value: (init && init.pointerType) || 'touch' });
          Object.defineProperty(e, 'isPrimary', { value: init && init.isPrimary !== false });
          if (Object.setPrototypeOf) Object.setPrototypeOf(e, PointerEventFallback.prototype);
        } catch (err) {}
        return e;
      };
      PointerEventFallback.prototype = Object.create(MouseEvent.prototype);
      PointerEventFallback.prototype.constructor = PointerEventFallback;
      g.PointerEvent = PointerEventFallback;
    }

    if (typeof Touch === 'undefined') {
      g.Touch = function (init) {
        init = init || {};
        this.identifier = init.identifier || 0;
        this.target = init.target || null;
        this.clientX = init.clientX || 0;
        this.clientY = init.clientY || 0;
        this.screenX = init.screenX || 0;
        this.screenY = init.screenY || 0;
        this.pageX = init.pageX || 0;
        this.pageY = init.pageY || 0;
        this.radiusX = init.radiusX || 0;
        this.radiusY = init.radiusY || 0;
        this.rotationAngle = init.rotationAngle || 0;
        this.force = init.force || 0;
      };
    }

    if (typeof navigator !== 'undefined') {
      var defineNav = function (name, value) {
        try { Object.defineProperty(navigator, name, { value: value, configurable: true }); }
        catch (e) { try { navigator[name] = value; } catch (e2) {} }
      };
      if (!navigator.permissions) {
        defineNav('permissions', {
          query: function () {
            return Promise.resolve({
              state: 'prompt', onchange: null,
              addEventListener: function () {}, removeEventListener: function () {}
            });
          }
        });
      }
      if (!navigator.mediaDevices) {
        defineNav('mediaDevices', {
          getUserMedia: function () { return Promise.reject(new Error('Media devices are not supported')); },
          enumerateDevices: function () { return Promise.resolve([]); },
          addEventListener: function () {}, removeEventListener: function () {}
        });
      }
      if (!navigator.connection) {
        defineNav('connection', makeTarget({
          effectiveType: '4g', type: 'wifi', downlink: 10, downlinkMax: 100,
          rtt: 50, saveData: false
        }));
      }
      if (!navigator.deviceMemory) defineNav('deviceMemory', 4);
      if (navigator.maxTouchPoints === undefined) defineNav('maxTouchPoints', 5);
      if (navigator.webdriver === undefined) defineNav('webdriver', false);
    }

    if (g.AbortSignal && !g.AbortSignal.timeout) {
      g.AbortSignal.timeout = function (ms) {
        var controller = new AbortController();
        setTimeout(function () { controller.abort(); }, Math.max(0, Number(ms) || 0));
        return controller.signal;
      };
    }
    if (g.AbortSignal && !g.AbortSignal.abort) {
      g.AbortSignal.abort = function () {
        var controller = new AbortController();
        controller.abort();
        return controller.signal;
      };
    }

    if (g.WebAssembly && !g.WebAssembly.instantiateStreaming) {
      g.WebAssembly.instantiateStreaming = function (source, imports) {
        return Promise.resolve(source).then(function (response) {
          return response.arrayBuffer();
        }).then(function (buffer) {
          return g.WebAssembly.instantiate(buffer, imports);
        });
      };
    }
    if (g.WebAssembly && !g.WebAssembly.compileStreaming) {
      g.WebAssembly.compileStreaming = function (source) {
        return Promise.resolve(source).then(function (response) {
          return response.arrayBuffer();
        }).then(function (buffer) {
          return g.WebAssembly.compile(buffer);
        });
      };
    }

    if (!g.createImageBitmap) {
      g.createImageBitmap = function (source) {
        return new Promise(function (resolve, reject) {
          try {
            if (typeof Blob !== 'undefined' && source instanceof Blob) {
              var img = new Image();
              var url = URL.createObjectURL(source);
              img.onload = function () { URL.revokeObjectURL(url); resolve(img); };
              img.onerror = function (e) { URL.revokeObjectURL(url); reject(e); };
              img.src = url;
              return;
            }
            resolve(source);
          } catch (e) { reject(e); }
        });
      };
    }

    if (!g.OffscreenCanvas) {
      g.OffscreenCanvas = function (width, height) {
        var canvas = document.createElement('canvas');
        canvas.width = width || 0;
        canvas.height = height || 0;
        canvas.convertToBlob = function (options) {
          options = options || {};
          return new Promise(function (resolve, reject) {
            try {
              canvas.toBlob(function (blob) { blob ? resolve(blob) : reject(new Error('toBlob failed')); },
                            options.type || 'image/png', options.quality);
            } catch (e) { reject(e); }
          });
        };
        canvas.transferToImageBitmap = function () { return canvas; };
        return canvas;
      };
    }
  } catch (e) {
    /* A missing optional API must never break the page. */
    try { g.__yumiPolyError = (e && e.stack) || String(e); } catch (e2) {}
  }
})();
