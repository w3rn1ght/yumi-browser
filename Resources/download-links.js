/*
 * Yumi: collect download candidates from the current page.
 * Returns a JSON array of {url, name, file}. "file" is 1 for a direct file
 * link and 0 for an intermediate download page. Must parse on iOS 12.
 */
(function () {
    var out = [], seen = {};
    var fileExtensions = /^(apk|apks|xapk|ipa|deb|dmg|pkg|exe|msi|zip|7z|rar|tar|gz|tgz|xz|bz2|iso|img|bin|torrent|epub|mobi|fb2|cbz|cbr|djvu)$/;

    function candidate(href, text) {
        if (!href) return;
        var url;
        try { url = new URL(href, document.baseURI || location.href); }
        catch (e) { return; }
        if (url.protocol !== 'http:' && url.protocol !== 'https:') return;

        var path = (url.pathname || '').toLowerCase();
        var extension = path.split('.').pop() || '';
        var isFile = fileExtensions.test(extension);
        var isPage = /\/(download|dwn|dl)(\/|$)/.test(path) ||
                     /[?&](download|file)=/.test(url.search);
        if (!isFile && !isPage) return;

        var key = url.href;
        if (seen[key]) return;
        seen[key] = 1;

        var label = (text || '').replace(/\s+/g, ' ').trim();
        if (!label) {
            label = path.split('/').pop() || 'download';
            try { label = decodeURIComponent(label); } catch (e) {}
        }
        if (label.length > 110) label = label.slice(0, 110);

        out.push({ url: key, name: label, file: isFile ? 1 : 0 });
    }

    var links = document.querySelectorAll('a[href]');
    for (var i = 0; i < links.length; i++) {
        candidate(links[i].href || links[i].getAttribute('href'), links[i].textContent);
    }

    var dataNodes = document.querySelectorAll('[data-href], [data-url], [data-download]');
    for (var j = 0; j < dataNodes.length; j++) {
        var node = dataNodes[j];
        candidate(node.getAttribute('data-href'), node.textContent);
        candidate(node.getAttribute('data-url'), node.textContent);
        candidate(node.getAttribute('data-download'), node.textContent);
    }

    return JSON.stringify(out.slice(0, 50));
})();
