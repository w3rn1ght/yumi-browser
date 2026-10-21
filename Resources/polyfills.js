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
    g.structuredClone = function (obj) { return JSON.parse(JSON.stringify(obj)); };
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
              try { ro._cb([{ target: el, contentRect: r }], ro); } catch (e) {}
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
    g.ResizeObserver.prototype.observe = function (el) { this._map.set(el, null); };
    g.ResizeObserver.prototype.unobserve = function (el) { this._map.delete(el); };
    g.ResizeObserver.prototype.disconnect = function () { this._map.clear(); };
  }
})();
