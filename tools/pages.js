// Makes one page per weapon (web/w/<id>/index.html) from web/index.html, and web/sitemap.xml.
// Each weapon page is the same app with its own title, description and address, so opening a
// weapon is a real page view and search engines can list every weapon. Run by collect.ps1.
'use strict';
const fs = require('fs'), path = require('path');
const SITE = 'https://2ez4me.win';
const web = path.join(__dirname, '..', 'web');
const read = (f) => fs.readFileSync(path.join(web, f), 'utf8');
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

let tpl = read('index.html');

// ---- the site's own Korean wording and name rules (taken from app.js, so this text matches the site)
const appSrc = read('app.js');
const pick = (start, end) => { const a = appSrc.indexOf(start), b = appSrc.indexOf(end, a); if (a < 0 || b < 0) throw new Error('app.js changed: ' + start); return appSrc.slice(a + start.length, b); };
const T = new Function('return ' + pick('const T = ', ';\nconst CAT_ORDER'))().ko;
const P = new Function('return ' + pick('const P = ', ';\n'))();
const RARITY = new Function('return ' + pick('const RARITY = ', ';\n'))();
const HIDDEN = new Set(new Function('return ' + pick('const HIDDEN_SOCKETS = new Set(', ');'))());
const CJK = /[\u4e00-\u9fff]/;
const ATTACH = ['발', '배율', '계열'];
const gloss = JSON.parse(read('terms.json')).ko || {};
const glossKeys = Object.keys(gloss).sort((a, b) => b.length - a.length);
function glossTr(zh) {                       // same steps as glossTr() in app.js (Korean)
  if (!CJK.test(zh)) return zh;
  const s0 = zh.replace(/([A-Za-z])(\d+发)/g, '$1 $2').replace(/（/g, '(').replace(/）/g, ')').replace(/，/g, ',');
  const out = []; let i = 0;
  while (i < s0.length) {
    if (CJK.test(s0[i])) { const k = glossKeys.find((x) => s0.startsWith(x, i)); if (k) { out.push(['T', gloss[k]]); i += k.length; } else { out.push(['T', s0[i]]); i += 1; } }
    else { let j = i; while (j < s0.length && !CJK.test(s0[j])) j += 1; out.push(['A', s0.slice(i, j)]); i = j; }
  }
  let r = '';
  for (const [kind, tok] of out) {
    if (kind === 'T' && ATTACH.some((a) => tok.startsWith(a)) && /[0-9A-Za-z]$/.test(r)) { r += tok; continue; }
    if (r && !/[ (]$/.test(r) && !/^[ ),/]/.test(tok)) r += ' ';
    r += tok;
  }
  return r.replace(/\s+/g, ' ').trim();
}
const num = (n) => (n == null ? '-' : Math.round(n).toLocaleString('en-US'));
const MODE_ORDER = ['Single', 'Burst', 'Auto'];   // 단발, 점사, 연사
const modeText = (m) => Array.isArray(m) ? [...m].sort((a, b) => MODE_ORDER.indexOf(a) - MODE_ORDER.indexOf(b)).map((x) => T.mode[x] || x).join('/') : (m ? String(m).split(/[,/]/).map((x) => T.mode[x.trim()] || x.trim()).join('/') : '-');

// visible text about one weapon: base stats and the attachments each slot takes (global server data, else China)
function infoSection(id, title) {
  let srv = 'global', w, idx;
  try { w = JSON.parse(read(`data/global/w/${id}.json`)); } catch (e) { srv = 'cn'; }
  try { if (!w) w = JSON.parse(read(`data/cn/w/${id}.json`)); idx = JSON.parse(read(`data/${srv}/index.json`)); } catch (e) { return ''; }
  const names = idx.names || {};
  const tr = (zh) => (names[zh] && names[zh][0]) || glossTr(zh);
  const b = w.base || {}, st = T.stat, u = T.unit;
  const rows = [
    [st.damage, num(b.damage)], [st.armor, num(b.armor)], [st.rpm, b.rpm != null ? `${num(b.rpm)}${u.rpm}` : '-'],
    [st.capacity, num(b.capacity)], [st.mode, modeText(b.fireMode)], [st.velocity, b.velocity != null ? `${num(b.velocity)}m/s` : '-'],
    [st.range, b.range != null ? `${num(b.range)}m` : '-'], [st.recoil, num(b.recoil)], [st.handling, num(b.handling)],
    [st.stability, num(b.stability)], [st.hip, num(b.hip)], [st.sound, b.sound != null ? `${num(b.sound)}m` : '-'],
  ].filter(([, v]) => v !== '-');
  // every attachment a player can pick, grouped by slot (slots that come with other parts included)
  const bySlot = new Map();
  for (const [, sid, opts] of w.sockets || []) {
    if (HIDDEN.has(sid)) continue;
    const list = bySlot.get(sid) || [];
    for (const i of opts) { const p = w.parts[i]; if (p && p[P.sel] && !list.includes(i)) list.push(i); }
    bySlot.set(sid, list);
  }
  // slots with the same name in the game (e.g. two riser-sight sockets) are listed once
  const byLabel = new Map();
  for (const [sid, l] of bySlot) {
    if (!l.length) continue;
    const label = T.sock[sid] || idx.sockets[sid] || String(sid);
    const all = byLabel.get(label) || [];
    for (const i of l) if (!all.includes(i)) all.push(i);
    byLabel.set(label, all);
  }
  const slots = [...byLabel].map(([label, l]) => {
    const parts = [...new Set(l.sort((x, y) => (RARITY[w.parts[y][P.rar]] || 0) - (RARITY[w.parts[x][P.rar]] || 0)).map((i) => tr(w.parts[i][P.zh])))];
    return `<li><b>${esc(label)}</b> (${parts.length}): ${esc(parts.join(', '))}</li>`;
  });
  const server = T[srv];
  return `<section class="info" id="info" lang="ko">
  <h2>${esc(title)} 기본 능력치</h2>
  <p class="info-note">${esc(server)} · ${esc(idx.effectiveDate || '')} 패치 기준. 위 건스미스에서 부착물을 바꾸면 능력치와 총 가격이 바로 바뀝니다.</p>
  <table class="info-stats"><tbody>${rows.map(([k, v]) => `<tr><th>${esc(k)}</th><td>${esc(v)}</td></tr>`).join('')}</tbody></table>
  ${slots.length ? `<h2>${esc(title)} 장착 가능한 부착물</h2>
  <ul class="info-slots">${slots.join('')}</ul>` : ''}
</section>
`;
}
const terms = JSON.parse(read('terms.json')).ko || {};
const kinds = Object.keys(terms).sort((a, b) => b.length - a.length);
// Korean title of each weapon (the DB's stored name, e.g. "M4A1 돌격소총")
const weapons = new Map();
let lastmod = '';                         // newest patch date of the two servers
for (const server of ['global', 'cn']) {
  let idx; try { idx = JSON.parse(read(`data/${server}/index.json`)); } catch (e) { continue; }
  if (/^\d{4}-\d\d-\d\d$/.test(idx.effectiveDate || '') && idx.effectiveDate > lastmod) lastmod = idx.effectiveDate;
  for (const [id, zh] of idx.weapons || []) {
    if (weapons.has(id)) continue;
    let title = (idx.titles || {})[id];
    if (!title) {                       // not in the DB table yet: "AN94突击步枪" -> "AN94 돌격소총"
      const k = kinds.find((x) => zh.endsWith(x) && zh.length > x.length);
      title = k ? zh.slice(0, -k.length) + ' ' + terms[k] : zh;
    }
    weapons.set(id, title);
  }
}
if (!weapons.size) { console.log('pages: no weapon list'); process.exit(1); }

// plain links to every weapon page inside the weapon list of index.html, so the links are in the page
// itself (not only drawn by app.js): search engines find all weapon pages even without the sitemap
const links = [...weapons].map(([id, title]) =>
  `<a class="wcard" href="/w/${id}/" data-id="${id}"><img class="wimg" src="img/w/${id}.webp" alt="${esc(title)}" loading="lazy"><span class="wname">${esc(title)}</span></a>`).join('');
const grid = /(<div class="weapon-grid" id="weaponGrid">)[\s\S]*?(<\/div>)/;
if (!grid.test(tpl)) { console.log('pages: weapon list not found in index.html'); process.exit(1); }
// the weapon list is what the main page shows, so it is visible in the page itself (not hidden until app.js runs)
const withLinks = tpl.replace(grid, `$1${links}$2`).replace('<section id="armory" class="armory" hidden>', '<section id="armory" class="armory">');
if (withLinks !== tpl) { fs.writeFileSync(path.join(web, 'index.html'), withLinks); tpl = withLinks; }

const set = (html, re, value) => { if (!re.test(html)) throw new Error('template changed: ' + re); return html.replace(re, value); };
let made = 0;
for (const [id, title] of weapons) {
  const url = `${SITE}/w/${id}/`;
  const name = `${title} 건스미스 · 델타포스`;
  const desc = `델타포스 ${title} 부착물 조합과 능력치·가격을 중국·글로벌 서버 기준으로 바로 확인하는 건스미스 시뮬레이터.`;
  // weapon page: the gunsmith fills the screen from the start (the weapon text sits below it, never shown first)
  let h = tpl.replace('<section id="armory" class="armory">', '<section id="armory" class="armory" hidden>')
    .replace('<section id="smith" class="smith" hidden>', '<section id="smith" class="smith">');
  h = set(h, /<meta charset="utf-8">/, '<meta charset="utf-8">\n<base href="/">');
  h = set(h, /<title>[^<]*<\/title>/, `<title>${esc(name)}</title>`);
  h = set(h, /<meta name="description" content="[^"]*">/, `<meta name="description" content="${esc(desc)}">`);
  h = set(h, /<link rel="canonical" href="[^"]*">/, `<link rel="canonical" href="${url}">`);
  h = set(h, /<meta property="og:url" content="[^"]*">/, `<meta property="og:url" content="${url}">`);
  h = set(h, /<meta property="og:title" content="[^"]*">/, `<meta property="og:title" content="${esc(name)}">`);
  h = set(h, /<meta property="og:description" content="[^"]*">/, `<meta property="og:description" content="${esc(desc)}">`);
  h = set(h, /<meta property="og:image" content="[^"]*">/, `<meta property="og:image" content="${SITE}/img/w/${id}.png">`);
  h = set(h, /<\/main>/, infoSection(id, title) + '</main>');
  const dir = path.join(web, 'w', id), file = path.join(dir, 'index.html');
  let old = null; try { old = fs.readFileSync(file, 'utf8'); } catch (e) { /* new */ }
  if (old !== h) { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(file, h); made++; }
}
const urls = ['/', '/about.html', '/privacy.html', ...[...weapons.keys()].sort().map((id) => `/w/${id}/`)];
const sm = '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' +
  urls.map((u) => `  <url><loc>${SITE}${u}</loc>${lastmod && u !== '/privacy.html' && u !== '/about.html' ? `<lastmod>${lastmod}</lastmod>` : ''}</url>`).join('\n') + '\n</urlset>\n';
let oldSm = ''; try { oldSm = read('sitemap.xml'); } catch (e) { /* new */ }
if (oldSm !== sm) fs.writeFileSync(path.join(web, 'sitemap.xml'), sm);
// the same list as plain text (one address per line), a second sitemap format Google accepts
const txt = urls.map((u) => SITE + u).join('\n') + '\n';
let oldTxt = ''; try { oldTxt = read('sitemap.txt'); } catch (e) { /* new */ }
if (oldTxt !== txt) fs.writeFileSync(path.join(web, 'sitemap.txt'), txt);
console.log(`pages: ${weapons.size} weapons, ${made} written`);
