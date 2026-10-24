/*
 * GitHub compatibility layer for iOS 12 / Safari 12.
 *
 * GitHub's current Primer CSS relies on :where(), :is(), @layer and other
 * features that Safari 12 either ignores or parses only partially. The
 * marketing header then expands to several screens and pushes the repository
 * far below the fold. This script adds a small reader-mode stylesheet and,
 * when the layout is clearly broken, hides the global header and adds a tiny
 * navigation bar with direct links (including Releases) so files can still be
 * reached and downloaded.
 */
(function () {
    var CSS = `
body{margin:0!important;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif!important;
font-size:15px!important;line-height:1.5!important;-webkit-text-size-adjust:100%!important;}
a{color:#0969da!important;text-decoration:none!important;}
a:hover{text-decoration:underline!important;}
img{max-width:100%!important;height:auto!important;}
svg{max-width:100%!important;}
svg.octicon,svg[aria-hidden="true"]{width:16px!important;height:16px!important;vertical-align:text-bottom!important;
display:inline-block!important;flex:none!important;}
pre,code{white-space:pre-wrap!important;word-break:break-word!important;font-family:ui-monospace,Menlo,monospace!important;}
h1{font-size:24px!important;}h2{font-size:20px!important;}h3{font-size:17px!important;}
ul,ol{padding-left:24px!important;}
table{width:100%!important;border-collapse:collapse!important;}
td,th{padding:6px 8px!important;border-bottom:1px solid #eaeef2!important;vertical-align:middle!important;}
details{display:block!important;}
summary{cursor:pointer!important;}
.sr-only,.visuallyHidden__TIbnmb,a[href="#start-of-content"]{position:absolute!important;width:1px!important;height:1px!important;
padding:0!important;margin:-1px!important;overflow:hidden!important;clip:rect(0,0,0,0)!important;white-space:nowrap!important;border:0!important;}
#yumi-gh-bar{position:-webkit-sticky!important;position:sticky!important;top:0!important;z-index:9999!important;
background:#24292f!important;padding:8px 12px!important;font:14px/1.3 -apple-system,sans-serif!important;
display:flex!important;align-items:center!important;flex-wrap:wrap!important;}
#yumi-gh-bar a{color:#fff!important;text-decoration:none!important;font-weight:600;margin-right:16px;}
#yumi-gh-bar a:last-child{margin-right:0;}
html.yumi-gh-broken,html.yumi-gh-broken body{background:#fff!important;color:#1f2328!important;}
html.yumi-gh-broken body *{color:#1f2328!important;}
html.yumi-gh-broken a,html.yumi-gh-broken a *{color:#0969da!important;}
html.yumi-gh-broken pre,html.yumi-gh-broken code{background:#f6f8fa!important;color:#1f2328!important;}
html.yumi-gh-broken [data-marketing-header="true"],
html.yumi-gh-broken header.HeaderMktg,
html.yumi-gh-broken header.AppHeader,
html.yumi-gh-broken .Header,
html.yumi-gh-broken .js-header-wrapper,
html.yumi-gh-broken header[role="banner"]{display:none!important;}
html.yumi-gh-broken main,html.yumi-gh-broken #js-repo-pjax-container{display:block!important;
max-width:980px!important;margin:0 auto!important;padding:16px!important;}
html.yumi-gh-broken .container-xl,html.yumi-gh-broken .container-lg,html.yumi-gh-broken .container{
max-width:980px!important;margin:0 auto!important;padding-left:16px!important;padding-right:16px!important;}
html.yumi-gh-broken .d-flex{display:flex!important;}
html.yumi-gh-broken .flex-column{flex-direction:column!important;}
html.yumi-gh-broken .flex-items-center{align-items:center!important;}
html.yumi-gh-broken .flex-justify-between{justify-content:space-between!important;}
html.yumi-gh-broken .flex-wrap{flex-wrap:wrap!important;}
html.yumi-gh-broken .mr-2{margin-right:8px!important;}
html.yumi-gh-broken .ml-2{margin-left:8px!important;}
html.yumi-gh-broken .p-3{padding:16px!important;}
html.yumi-gh-broken .border{border:1px solid #d0d7de!important;}
html.yumi-gh-broken .rounded{border-radius:6px!important;}
html.yumi-gh-broken .Box{border:1px solid #d0d7de!important;border-radius:6px!important;margin-bottom:16px!important;}
html.yumi-gh-broken .Box-header{padding:12px 16px!important;background:#f6f8fa!important;border-bottom:1px solid #d0d7de!important;}
html.yumi-gh-broken .Box-row{padding:12px 16px!important;border-bottom:1px solid #eaeef2!important;}
html.yumi-gh-broken .Box-row:last-child{border-bottom:0!important;}
html.yumi-gh-broken table[class*="OverviewTable"] thead th:first-child{display:none!important;}
html.yumi-gh-broken .react-directory-row-name-cell-small-screen{display:none!important;}
html.yumi-gh-broken .react-directory-row-name-cell-large-screen{display:table-cell!important;}
`;
    var appliedClass = 'yumi-gh-broken';

    function headerElement() {
        return document.querySelector('[data-marketing-header="true"], header.HeaderMktg, ' +
            'header.AppHeader, header[role="banner"]');
    }

    function layoutBroken() {
        var header = headerElement();
        var main = document.querySelector('main');
        var headerHeight = header
            ? Math.max(header.getBoundingClientRect().height, header.scrollHeight || 0)
            : 0;
        if (!main) return headerHeight > 220;
        var mainTop = main.getBoundingClientRect().top;
        return headerHeight > 220 || mainTop > 450;
    }

    function makeLink(href, text) {
        var a = document.createElement('a');
        a.href = href;
        a.textContent = text;
        return a;
    }

    function currentLogin() {
        try {
            var meta = document.querySelector('meta[name="user-login"]');
            return meta ? (meta.getAttribute('content') || '').trim() : '';
        } catch (e) {
            return '';
        }
    }

    function repositoriesURL() {
        var login = currentLogin();
        return login
            ? 'https://github.com/' + login + '?tab=repositories'
            : 'https://github.com/settings/repositories';
    }

    function releaseInfo() {
        var m = location.pathname.match(/^\/([^\/]+)\/([^\/]+)\/releases(?:\/tag\/([^\/?#]+))?/);
        if (!m) return null;
        var tag = '';
        if (m[3]) {
            try { tag = decodeURIComponent(m[3]); } catch (e) { tag = m[3]; }
        }
        if (!tag) {
            var links = document.querySelectorAll('a[href*="/releases/tag/"]');
            for (var i = 0; i < links.length; i++) {
                var hm = (links[i].getAttribute('href') || '').match(/\/releases\/tag\/([^\/?#]+)/);
                if (hm) {
                    try { tag = decodeURIComponent(hm[1]); } catch (e) { tag = hm[1]; }
                    break;
                }
            }
        }
        return { owner: m[1], repo: m[2], tag: tag };
    }

    function addAsset(out, seen, href, name) {
        if (!href) return;
        if (href.indexOf('http') !== 0) {
            href = location.origin + (href.charAt(0) === '/' ? '' : '/') + href;
        }
        if (href.indexOf('/releases/download/') < 0) return;
        if (seen[href]) return;
        seen[href] = 1;
        if (!name) {
            var clean = href.split('?')[0].split('#')[0];
            name = clean.split('/').pop();
            try { name = decodeURIComponent(name); } catch (e) {}
        }
        out.push({ url: href, name: name });
    }

    function assetsFromDOM() {
        var out = [], seen = {};
        var links = document.querySelectorAll('a[href*="/releases/download/"]');
        for (var i = 0; i < links.length; i++) {
            addAsset(out, seen, links[i].href || links[i].getAttribute('href'),
                     (links[i].textContent || '').trim());
        }
        return out;
    }

    function parseAssetsHTML(html) {
        var out = [], seen = {};
        var re = /href="([^"]*\/releases\/download\/[^"]+)"/g;
        var m;
        while ((m = re.exec(html))) {
            addAsset(out, seen, m[1].replace(/&amp;/g, '&'), '');
        }
        return out;
    }

    function sendAssets(assets, error) {
        try {
            window.webkit.messageHandlers.yumi.postMessage({
                type: 'github-assets',
                page: location.href,
                assets: assets || [],
                error: error || ''
            });
        } catch (e) {}
    }

    function scanAssets() {
        if (window.__yumiAssetsScanning) return;
        window.__yumiAssetsScanning = true;

        var info = releaseInfo();
        if (!info) {
            window.__yumiAssetsScanning = false;
            sendAssets([], 'Открой страницу релиза GitHub');
            return;
        }

        var fromDOM = assetsFromDOM();
        if (fromDOM.length) {
            window.__yumiAssetsScanning = false;
            sendAssets(fromDOM, '');
            return;
        }

        var urls = [], seenURL = {};
        var fragments = document.querySelectorAll('include-fragment[src*="expanded_assets"]');
        for (var i = 0; i < fragments.length; i++) {
            var src = fragments[i].src || fragments[i].getAttribute('src');
            if (src && !seenURL[src]) {
                seenURL[src] = 1;
                urls.push(src);
            }
        }
        if (!urls.length && info.tag) {
            urls.push('/' + info.owner + '/' + info.repo +
                      '/releases/expanded_assets/' + encodeURIComponent(info.tag));
        }
        if (!urls.length) {
            urls.push('/' + info.owner + '/' + info.repo + '/releases/expanded_assets/latest');
        }

        var remaining = urls.length;
        var all = [], seen = {};
        var done = function () {
            remaining -= 1;
            if (remaining > 0) return;
            window.__yumiAssetsScanning = false;
            sendAssets(all, all.length ? '' : 'Ассеты не найдены');
        };

        for (var u = 0; u < urls.length; u++) {
            (function (assetURL) {
                try {
                    var xhr = new XMLHttpRequest();
                    xhr.open('GET', assetURL, true);
                    xhr.setRequestHeader('Accept', 'text/html');
                    xhr.onload = function () {
                        if (xhr.status >= 200 && xhr.status < 400) {
                            var parsed = parseAssetsHTML(xhr.responseText || '');
                            for (var k = 0; k < parsed.length; k++) {
                                if (!seen[parsed[k].url]) {
                                    seen[parsed[k].url] = 1;
                                    all.push(parsed[k]);
                                }
                            }
                        }
                        done();
                    };
                    xhr.onerror = done;
                    xhr.send();
                } catch (e) {
                    done();
                }
            })(urls[u]);
        }
    }

    function addAssetsButton(bar) {
        if (!releaseInfo()) return;
        var a = makeLink('#', 'Скачать');
        a.id = 'yumi-gh-assets';
        a.addEventListener('click', function (event) {
            event.preventDefault();
            event.stopPropagation();
            if (a.getAttribute('data-busy') === '1') return;
            a.setAttribute('data-busy', '1');
            a.textContent = 'Ищу…';
            scanAssets();
            setTimeout(function () {
                a.removeAttribute('data-busy');
                a.textContent = 'Скачать';
            }, 8000);
        });
        bar.appendChild(a);
    }

    function ensureBar() {
        var bar = document.getElementById('yumi-gh-bar');
        if (!bar) {
            bar = document.createElement('div');
            bar.id = 'yumi-gh-bar';
            if (document.body) document.body.insertBefore(bar, document.body.firstChild);
            else return;
        }
        while (bar.firstChild) bar.removeChild(bar.firstChild);

        bar.appendChild(makeLink('https://github.com/', 'GitHub'));
        bar.appendChild(makeLink(repositoriesURL(), 'Репозитории'));

        var isDotCom = location.hostname === 'github.com' || location.hostname === 'www.github.com';
        var match = location.pathname.match(/^\/([^\/]+)\/([^\/]+)/);
        if (isDotCom && match && !/^(login|signup|settings|notifications|explore|topics|collections|sponsors|marketplace|orgs|users|search|new|pulls|issues)$/.test(match[1])) {
            bar.appendChild(makeLink('https://github.com/' + match[1] + '/' + match[2] + '/releases', 'Релизы'));
        }
        addAssetsButton(bar);

        var login = currentLogin();
        if (login) {
            bar.appendChild(makeLink('https://github.com/' + login, 'Профиль'));
        } else {
            bar.appendChild(makeLink('https://github.com/login', 'Вход'));
        }
    }

    function installOldDesignFallback() {
        if (window.__yumiOldDesignHooked) return;
        window.__yumiOldDesignHooked = true;
        document.addEventListener('click', function (event) {
            var el = event.target;
            while (el && el !== document.body) {
                if (el.tagName === 'A' || el.tagName === 'BUTTON') break;
                el = el.parentNode;
            }
            if (!el) return;
            var text = (el.textContent || '').toLowerCase();
            if (text.indexOf('old design') >= 0 ||
                text.indexOf('switch to old') >= 0 ||
                text.indexOf('старый дизайн') >= 0 ||
                text.indexOf('старом дизайне') >= 0) {
                event.preventDefault();
                event.stopPropagation();
                location.href = repositoriesURL();
            }
        }, true);
    }

    function apply() {
        try {
            var broken = layoutBroken();
            if (broken) document.documentElement.classList.add(appliedClass);
            if (!document.getElementById('yumi-gh-style')) {
                var style = document.createElement('style');
                style.id = 'yumi-gh-style';
                style.textContent = CSS;
                (document.head || document.documentElement).appendChild(style);
            }
            ensureBar();
            installOldDesignFallback();
        } catch (e) {}
    }

    apply();
    setTimeout(apply, 700);
    setTimeout(apply, 2200);
})();
