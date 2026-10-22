(() => {
  const html = document.documentElement.innerHTML;
  const out = {};
  out.len = html.length;
  const pats = {
    shikimori: /shikimoriId[^0-9]{0,24}(\d{2,9})/g,
    releaseId: /\/releases\/[^"'\\]*\/(\d{2,9})\//g,
    animeId: /"animeId"\s*:\s*(\d+)/g,
    id: /"id"\s*:\s*(\d{2,9})/g
  };
  for (const k in pats) {
    const a = [];
    let m;
    while ((m = pats[k].exec(html)) && a.length < 8) a.push(m[1]);
    out[k] = a;
  }
  let i = html.indexOf('shikimoriId');
  out.ctx = i >= 0 ? html.slice(Math.max(0, i - 120), i + 160) : '';
  return JSON.stringify(out);
})()
