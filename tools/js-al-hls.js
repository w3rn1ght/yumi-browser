(async () => {
  try {
    const r = await fetch('/api/sources?shikimoriId=10335', {cache: 'no-store'}).then(x => x.json());
    const ep = r.episodes[0];
    const body = {url: ep.sources[0].iframeUrl, episode: ep.number, shikimoriId: 10335, translation: ep.sources[0].dubbing};
    const resp = await fetch('/api/aniliberty/resolve', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    const data = await resp.json();
    const keys = Object.keys(data.links);
    const quality = keys.sort((a, b) => Number(b) - Number(a))[0];
    const src = data.links[quality].Src;
    const url = new URL(src, location.origin).href;
    const hr = await fetch(url);
    const text = await hr.text();
    return JSON.stringify({quality, url, status: hr.status, ct: hr.headers.get('content-type'), len: text.length, head: text.slice(0, 260)});
  } catch (e) { return 'ERR ' + e; }
})()
