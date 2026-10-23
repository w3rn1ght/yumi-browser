/*
 * Yumi: WebP polyfill for AniLibria on iOS 12.
 *
 * iOS 12 WebKit cannot decode WebP. The site serves all cover art as .webp,
 * so covers appear as broken images. webp-hero decodes the original bytes in
 * the page (same-origin fetch) and replaces each image with a PNG/JPEG data
 * URL. We decode only images near the viewport, one at a time (the decoder is
 * not re-entrant), and keep large images as JPEG to avoid iOS memory spikes.
 *
 * Loaded only on anilibria.fun/.top/.tv pages, after the document has loaded.
 */
(function () {
    if (window.__yumiWebpBooted) return;
    window.__yumiWebpBooted = true;

    if (!window.webpHero || !window.webpHero.WebpMachine) return;

    var machine = new window.webpHero.WebpMachine();
    var queue = [];
    var running = false;
    var scheduled = false;
    var seen = null;
    try { seen = new WeakSet(); } catch (e) { seen = null; }

    // For failed/small images: a neutral placeholder instead of a broken icon.
    var placeholder = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(
        '<svg xmlns="http://www.w3.org/2000/svg" width="320" height="450">' +
        '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">' +
        '<stop offset="0" stop-color="#1b1e24"/><stop offset="1" stop-color="#343943"/>' +
        '</linearGradient></defs>' +
        '<rect width="100%" height="100%" fill="url(#g)"/>' +
        '<text x="50%" y="50%" fill="#6f7684" font-family="-apple-system,sans-serif" ' +
        'font-size="18" text-anchor="middle">AniLibria</text></svg>'
    );

    // webp-hero's default decode() converts to PNG and returns a huge data URL.
    // Decode straight to a canvas instead, downscale large covers, and encode
    // posters as JPEG. This keeps iOS memory use low when scrolling a catalog.
    var decodeToCanvas = machine.decodeToCanvas;
    if (typeof decodeToCanvas === 'function') {
        machine.decode = function (data) {
            var canvas = document.createElement('canvas');
            return decodeToCanvas.call(machine, canvas, data).then(function () {
                try {
                    var source = canvas;
                    var maxWidth = 900;
                    if (canvas.width > maxWidth) {
                        var scaled = document.createElement('canvas');
                        var ratio = maxWidth / canvas.width;
                        scaled.width = maxWidth;
                        scaled.height = Math.max(1, Math.round(canvas.height * ratio));
                        scaled.getContext('2d').drawImage(canvas, 0, 0, scaled.width, scaled.height);
                        source = scaled;
                    }
                    if (source.width * source.height <= 220 * 220) {
                        // Logos/avatars often have transparency.
                        return source.toDataURL('image/png');
                    }
                    return source.toDataURL('image/jpeg', 0.82);
                } catch (e) {
                    try { return canvas.toDataURL(); } catch (e2) { return ''; }
                }
            });
        };
    }

    function isWebp(value) {
        return /\.webp(\b|$)/i.test(value || '');
    }

    function inView(img) {
        try {
            var r = img.getBoundingClientRect();
            var h = window.innerHeight || 800;
            return r.bottom > -180 && r.top < h + 420;
        } catch (e) {
            return true;
        }
    }

    function markSeen(img) {
        img.__yumiWebpSeen = true;
        if (seen) {
            try { seen.add(img); } catch (e) {}
        }
    }

    function alreadySeen(img) {
        if (img.__yumiWebpSeen) return true;
        if (seen) {
            try { return seen.has(img); } catch (e) {}
        }
        return false;
    }

    function scan() {
        var imgs = document.getElementsByTagName('img');
        for (var i = 0; i < imgs.length; i++) {
            var img = imgs[i];
            if (alreadySeen(img)) continue;
            var src = img.getAttribute('src') || '';
            var srcset = img.getAttribute('srcset') || '';
            if (!isWebp(src) && !isWebp(srcset)) continue;
            if (!inView(img)) continue;

            markSeen(img);
            if (srcset) {
                img.removeAttribute('srcset');
                img.removeAttribute('sizes');
            }
            queue.push(img);
            pump();
        }
    }

    function finish(img) {
        var src = img.getAttribute('src') || '';
        if (src.indexOf('data:image/') !== 0) {
            // Decode failed or image was not really WebP: hide the broken icon.
            if (isWebp(src)) img.src = placeholder;
        }
        try {
            img.classList.remove('poster-loading');
            img.classList.remove('opacity-0');
            img.classList.remove('invisible');
            img.classList.add('poster-loaded');
            img.style.opacity = '1';
        } catch (e) {}
        if (machine.cache) {
            var keys = Object.keys(machine.cache);
            if (keys.length > 12) machine.clearCache();
        }
        running = false;
        setTimeout(pump, 0);
    }

    function pump() {
        if (running || !queue.length) return;
        running = true;
        var img = queue.shift();
        var result = null;
        try {
            result = machine.polyfillImage(img);
        } catch (e) {
            result = null;
        }
        Promise.resolve(result).then(function () {
            finish(img);
        }, function () {
            finish(img);
        });
    }

    function schedule() {
        if (scheduled) return;
        scheduled = true;
        setTimeout(function () {
            scheduled = false;
            scan();
        }, 250);
    }

    function begin() {
        scan();
        setTimeout(scan, 500);
        setTimeout(scan, 1500);
        setTimeout(scan, 3500);
        window.addEventListener('scroll', schedule, true);
        window.addEventListener('resize', schedule, true);
        if (window.MutationObserver) {
            try {
                new MutationObserver(schedule).observe(document.documentElement, {
                    childList: true,
                    subtree: true
                });
            } catch (e) {}
        }
    }

    Promise.resolve(machine.webpSupport).then(function (supported) {
        if (!supported) begin();
    }, function () {
        begin();
    });
})();
