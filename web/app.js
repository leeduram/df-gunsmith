'use strict';
/* Delta Force web gunsmith. Reads data/{server}/index.json and data/{server}/w/{weaponId}.json */

// ---------------------------------------------------------------- text
const T = {
  ko: {
    cn: '중국 서버', global: '글로벌 서버', armory: '총기 선택', all: '전체', filter: '필터', onSale: '판매 중', parts: '부착물',
    back: '뒤로', price: '가격', effects: '부착물 효과', initial: '초기 속성', base: '기본', remove: '장착 해제', locked: '고정됨',
    sortDefault: '필터', fBuff: '버프 속성', fType: '유형', fOk: '확인', fBack: '뒤로',
    fAttr: { range: '최적 사거리', recoil: '반동 제어', handling: '조작 속도', stability: '안정성', hip: '지향 사격 정밀도', rpm: '발사 속도' },
    fCat: { railBipod: '양각대', functional: '전술 장비' }, fNone: '조건에 맞는 부착물이 없습니다.', noParts: '장착할 수 있는 부착물이 없습니다.',
    banner: '{server} · {date} 패치 기준', bannerPending: '{server} · 현재 라이브', total: '총 가격', noPrice: '글로벌 시세 없음', cnMark: '중섭', cnNote: '중섭 시세 포함', priceAt: '시세 {at}',
    pendingCn: '중국 서버에 {date} 패치가 적용되기 전입니다. {date} 패치 기준 수치를 미리 표시합니다.',
    pendingGlobal: '글로벌 서버에는 아직 {date} 패치(중국 서버 기준)가 적용되지 않았습니다. 글로벌 패치가 감지되면 자동으로 전환됩니다.',
    updated: '{date} 패치 기준 · 갱신 {at}', updatedLive: '갱신 {at}', magCap: '{n}발 탄창 용량', loading: '불러오는 중…', fail: '데이터를 불러오지 못했습니다.',
    stat: { damage: '기본 대미지', range: '최적 사거리', recoil: '반동 제어', handling: '조작 속도', stability: '안정성', hip: '지향사격 정밀도',
      armor: '아머 관통', rpm: '발사 속도', capacity: '용량', mode: '발포 모드', velocity: '포구 속도', sound: '총성 전파 거리',
      rangeEff: '최적 사거리 및 포구 속도' },
    unit: { rpm: '발/분' },
    mode: { '全自动': '연사', '单发': '단발', '连发': '점사', '泵动': '펌프', '半自动': '반자동', '栓动': '볼트', Auto: '연사', Burst: '점사', Single: '단발' },
    cat: { assaultRifle: '돌격소총', submachineGun: '기관단총', marksmanRifle: '지정사수소총', sniperRifle: '저격소총',
      lightMachineGun: '경기관총', shotgun: '산탄총', pistol: '권총', specialWeapon: '특수 무기' },
    sock: { 1: '리어 그립', 2: '배럴', 3: '개머리판', 4: '핸드가드', 5: '탄창', 6: '총구', 8: '포어 그립', 9: '가늠자', 10: '레일 양각대',
      11: '조준경', 12: '탄창', 14: '전술 장비', 17: '상단 레일', 18: '하단 레일', 19: '좌측 레일', 20: '우측 레일', 21: '조준경 마운트',
      22: '고유 부품', 28: '개머리판 패드', 29: '치크 패드', 30: '리어 그립 패치', 31: '오프셋 조준기', 32: '상단 패치', 34: '좌측 패치',
      35: '우측 패치', 36: '배럴 양각대', 37: '핸드가드 키트', 38: '개머리판 키트', 40: '상부 조준기', 41: '높이조절 조준기',
      43: '그립 마운트', 44: '탄창 마운트', 45: '차광막', 46: '상단 핸드가드', 47: '가스 블록', 48: '해머', 49: '방아쇠',
      50: '높이조절 조준기', 51: '방열판', 52: '볼트', 53: '리어 그립', 54: '차징 핸들', 64: '핸드가드 조준기', 65: '핸드가드',
      66: '탄창', 67: '개머리판', 68: '리어 그립', 69: '높이조절 조준기', 72: '배럴', 73: '탄약', 76: '강화 노리쇠', 77: '총구',
      55: '활 스트링', 56: '그립 패널', 57: '림', 58: '활 조준기', 59: '애로우 레스트', 60: '스테빌라이저', 61: '탄창', 62: '레버', 74: '활 스트링' }
  },
  en: {
    cn: 'China Server', global: 'Global Server', armory: 'Armory', all: 'All', filter: 'Filter', onSale: 'On Sale', parts: 'Attachments',
    back: 'Back', price: 'Price', effects: 'Attachment Effects', initial: 'Base Stats', base: 'Default', remove: 'Detach', locked: 'Fixed',
    sortDefault: 'Filter', fBuff: 'Buff Attributes', fType: 'Type', fOk: 'Confirm', fBack: 'Back',
    fAttr: { range: 'Effective Range', recoil: 'Recoil Control', handling: 'Handling Speed', stability: 'Stability', hip: 'Hip-fire Accuracy', rpm: 'Fire Rate' },
    fCat: { railBipod: 'Bipod', functional: 'Tactical Device' }, fNone: 'No attachments match.', noParts: 'No attachments can be fitted.',
    banner: '{server} · {date} patch', bannerPending: '{server} · Current live', total: 'Total Price', noPrice: 'No global market data', cnMark: 'CN', cnNote: 'incl. China prices', priceAt: 'prices {at}',
    pendingCn: 'The China server has not received the {date} patch yet. Showing {date} patch values in advance.',
    pendingGlobal: 'The Global server has not received the {date} patch (China) yet. It switches automatically when the Global patch is detected.',
    updated: '{date} patch · updated {at}', updatedLive: 'Updated {at}', magCap: '{n}-round capacity', loading: 'Loading…', fail: 'Could not load data.',
    stat: { damage: 'Damage', range: 'Range', recoil: 'Control', handling: 'Handling', stability: 'Stability', hip: 'Accuracy',
      armor: 'Armor Penetration', rpm: 'Fire Rate', capacity: 'Capacity', mode: 'Fire Mode', velocity: 'Muzzle Velocity', sound: 'Gunshot Sound',
      rangeEff: 'Range & Muzzle Velocity' },
    unit: { rpm: '/min' },
    mode: { '全自动': 'Auto', '单发': 'Single', '连发': 'Burst', '泵动': 'Pump', '半自动': 'Semi', '栓动': 'Bolt', Auto: 'Auto', Burst: 'Burst', Single: 'Single' },
    cat: { assaultRifle: 'Assault Rifle', submachineGun: 'Submachine Gun', marksmanRifle: 'Marksman Rifle', sniperRifle: 'Sniper Rifle',
      lightMachineGun: 'Light Machine Gun', shotgun: 'Shotgun', pistol: 'Pistol', specialWeapon: 'Special' },
    // names used by deltahub.gg build pages (Upper Rail, Riser Optic, Killflash, Special, Charging handle...)
    sock: { 1: 'Rear Grip', 2: 'Barrel', 3: 'Stock', 4: 'Handguard', 5: 'Magazine', 6: 'Muzzle', 8: 'Foregrip', 9: 'Rear Sight', 10: 'Rail Bipod',
      11: 'Optic', 12: 'Magazine', 14: 'Tactical Device', 17: 'Upper Rail', 18: 'Bottom Rail', 19: 'Left Rail', 20: 'Right Rail', 21: 'Optic Mount',
      22: 'Special', 28: 'Stock Pad', 29: 'Cheek Pad', 30: 'Grip Pad', 31: 'Offset Sight', 32: 'Upper Patch', 34: 'Left Patch',
      35: 'Right Patch', 36: 'Barrel Bipod', 37: 'Handguard Kit', 38: 'Stock Kit', 40: 'Top Secondary Sight', 41: 'Riser Optic',
      43: 'Grip Mount', 44: 'Mag Mount', 45: 'Killflash', 46: 'Upper Handguard', 47: 'Gas Block', 48: 'Hammer', 49: 'Trigger',
      50: 'Riser Optic', 51: 'Heat Shield', 52: 'Bolt', 53: 'Rear Grip', 54: 'Charging handle', 64: 'Handguard Sight', 65: 'Handguard',
      66: 'Magazine', 67: 'Stock', 68: 'Rear Grip', 69: 'Riser Optic', 72: 'Barrel', 73: 'Ammo', 76: 'Reinforced Bolt', 77: 'Muzzle',
      55: 'String', 56: 'Grip Piece', 57: 'Bow Limb', 58: 'Bow Sight', 59: 'Arrow Rest', 60: 'Stabilizer', 61: 'Magazine', 62: 'Lever', 74: 'String' }
  },
  zh: {
    cn: '国服', global: '国际服', armory: '枪械选择', all: '全部', filter: '筛选', onSale: '在售', parts: '配件',
    back: '返回', price: '价格', effects: '配件效果', initial: '初始属性', base: '默认', remove: '卸下', locked: '固定',
    sortDefault: '筛选', fBuff: '增益属性', fType: '类型', fOk: '确认', fBack: '返回',
    fAttr: { range: '有效射程', recoil: '后坐力控制', handling: '操控速度', stability: '据枪稳定性', hip: '腰际射击精度', rpm: '射速' },
    fCat: { railBipod: '两脚架', functional: '战术设备' }, fNone: '没有符合条件的配件。', noParts: '没有可安装的配件。',
    banner: '{server} · {date} 版本', bannerPending: '{server} · 当前正式服', total: '总价', noPrice: '暂无国际服价格', cnMark: '国服', cnNote: '含国服价格', priceAt: '价格 {at}',
    pendingCn: '国服尚未进行 {date} 更新，当前提前显示 {date} 版本数值。',
    pendingGlobal: '国际服尚未进行 {date} 更新（以国服为准），检测到国际服更新后会自动切换。',
    updated: '{date} 版本 · 更新于 {at}', updatedLive: '更新于 {at}', magCap: '{n} 发容弹量', loading: '加载中…', fail: '数据加载失败。',
    stat: { damage: '基础伤害', range: '有效射程', recoil: '后坐力控制', handling: '操控速度', stability: '据枪稳定性', hip: '腰际射击精度',
      armor: '护甲伤害', rpm: '射速', capacity: '容量', mode: '射击模式', velocity: '枪口初速', sound: '枪声传播距离',
      rangeEff: '有效射程与枪口初速' },
    unit: { rpm: '发/分' },
    mode: { '全自动': '全自动', '单发': '单发', '连发': '连发', '泵动': '泵动', '半自动': '半自动', '栓动': '栓动', Auto: '全自动', Burst: '连发', Single: '单发' },
    cat: { assaultRifle: '突击步枪', submachineGun: '冲锋枪', marksmanRifle: '射手步枪', sniperRifle: '狙击步枪',
      lightMachineGun: '轻机枪', shotgun: '霰弹枪', pistol: '手枪', specialWeapon: '特殊武器' },
    sock: {}
  }
};
const CAT_ORDER = ['assaultRifle', 'submachineGun', 'marksmanRifle', 'sniperRifle', 'lightMachineGun', 'shotgun', 'pistol', 'specialWeapon'];
const ZH_SUFFIX = ['精确射手步枪', '突击步枪', '冲锋枪', '霰弹枪', '轻机枪', '射手步枪', '狙击步枪', '杠杆步枪'];
const RARITY = { '白': 1, '绿': 2, '蓝': 3, '紫': 4, '金': 5, '红': 6 };
const ROMAN = ['', 'I', 'II', 'III', 'IV', 'V', 'VI'];
// where each socket sits on the gun image (fraction of the image box; muzzle is on the left)
const ANCHOR = {
  1: [.62, .66], 2: [.17, .47], 3: [.86, .46], 4: [.32, .44], 5: [.53, .76], 6: [.04, .47], 8: [.33, .64], 9: [.6, .3], 10: [.24, .58],
  11: [.56, .29], 12: [.55, .76], 14: [.27, .4], 17: [.37, .33], 18: [.3, .58], 19: [.26, .45], 20: [.41, .47], 21: [.55, .36],
  22: [.46, .5], 28: [.96, .46], 29: [.82, .35], 30: [.63, .74], 31: [.63, .33], 32: [.39, .36], 34: [.31, .49], 35: [.43, .5],
  36: [.2, .56], 37: [.34, .47], 38: [.84, .58], 40: [.56, .23], 41: [.57, .26], 43: [.6, .6], 44: [.53, .66], 45: [.5, .3],
  46: [.32, .38], 47: [.37, .42], 48: [.6, .5], 49: [.58, .58], 50: [.57, .26], 51: [.3, .4], 52: [.6, .45], 53: [.62, .66],
  54: [.67, .42], 64: [.3, .34], 65: [.32, .44], 66: [.53, .76], 67: [.86, .46], 68: [.62, .66], 72: [.17, .47], 73: [.53, .84],
  76: [.62, .45], 77: [.04, .47]
};
// compound bow: where the in-game gunsmith (global, 2026-11-05 screenshots) draws each line, as fractions of the bow
// (unturned picture; turned upright on screen). string, grip panel, limb, sight, arrow rest, stabilizer, arrows
const BOW_ANCHOR = { 55: [.516, .723], 56: [.429, .466], 57: [.517, .413], 58: [.637, .333], 59: [.426, .549], 60: [.242, .158], 61: [.518, .546] };
// part array layout from the export
const P = { zh: 0, ko: 1, cat: 2, rar: 3, img: 4, price: 5, sel: 6, rI: 7, rA: 8, rM: 9, rec: 10, hip: 11, han: 12, sta: 13, mI: 14, mA: 15, rof: 16, src: 17 };

// ---------------------------------------------------------------- state
const store = {
  get(k, d) { try { const v = localStorage.getItem('dfg.' + k); return v === null ? d : v; } catch (e) { return d; } },
  set(k, v) { try { localStorage.setItem('dfg.' + k, v); } catch (e) { /* ignore */ } }
};
const S = {
  lang: store.get('lang', 'ko'), server: store.get('server', 'global'), cat: 'all',
  index: null, weapon: null, mount: new Map(), locked: new Set(),
  slot: null, hover: null, showInitial: true, filter: { buff: new Set(), type: new Set() }
};
const cache = new Map();
const $ = (id) => document.getElementById(id);
const t = () => T[S.lang];
const fmt = (s, o) => s.replace(/\{(\w+)\}/g, (_, k) => o[k] ?? '');
const num = (n) => (n == null ? '-' : Math.round(n).toLocaleString('en-US'));
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

// one request per file: a second caller (e.g. opening a gun that is already being fetched) waits for the first
function getJSON(url) {
  if (!cache.has(url)) {
    cache.set(url, fetch(url, { cache: 'no-cache' })
      .then((r) => { if (!r.ok) throw new Error(r.status + ' ' + url); return r.json(); })
      .catch((e) => { cache.delete(url); throw e; }));
  }
  return cache.get(url);
}

// ---------------------------------------------------------------- names
function weaponCat(w) { return w.category || (/霰弹枪/.test(w.zh) ? 'shotgun' : 'specialWeapon'); }
// names: DB table (index.names) first, then the term glossary (terms.json) for names not in the table yet
let TERMS = null;
const TKEYS = {};
const CJK = /[\u4e00-\u9fff]/;
const ATTACH = { ko: ['발', '배율', '계열'], en: ['-', 'x '] };
async function loadTerms() {
  try {
    TERMS = await getJSON('terms.json');
    for (const l of ['ko', 'en']) TKEYS[l] = Object.keys(TERMS[l]).sort((a, b) => b.length - a.length);
  } catch (e) { TERMS = null; }
}
function glossTr(zh, lang) {
  if (!TERMS || !TERMS[lang] || !CJK.test(zh)) return zh;
  const dict = TERMS[lang], keys = TKEYS[lang];
  const s = zh.replace(/([A-Za-z])(\d+发)/g, '$1 $2').replace(/（/g, '(').replace(/）/g, ')').replace(/，/g, ',');
  const out = [];
  let i = 0;
  while (i < s.length) {
    if (CJK.test(s[i])) {
      const k = keys.find((x) => s.startsWith(x, i));
      if (k) { out.push(['T', dict[k]]); i += k.length; } else { out.push(['T', s[i]]); i += 1; }
    } else {
      let j = i;
      while (j < s.length && !CJK.test(s[j])) j += 1;
      out.push(['A', s.slice(i, j)]); i = j;
    }
  }
  let r = '';
  for (const [kind, tok] of out) {
    if (kind === 'T' && ATTACH[lang].some((a) => tok.startsWith(a)) && /[0-9A-Za-z]$/.test(r)) { r += tok; continue; }
    if (r && !/[ (]$/.test(r) && !/^[ ),/]/.test(tok)) r += ' ';
    r += tok;
  }
  return r.replace(/\s+/g, ' ').trim();
}
function trName(zh) {
  if (!zh || S.lang === 'zh') return zh;
  const n = S.index && S.index.names && S.index.names[zh];
  const v = n && n[S.lang === 'ko' ? 0 : 1];
  return v || glossTr(zh, S.lang);
}
// in-game Korean weapon title, e.g. "SCAR-H 전투소총" (category word differs per weapon)
const KO_KIND = / (컴팩트 돌격소총|돌격소총|전투소총|기관단총|범용 기관총|경기관총|지정사수소총|저격소총|샷건)$/;
function koTitle(w) { return S.lang === 'ko' && S.index && S.index.titles ? S.index.titles[w.id] : null; }
function weaponName(w) {
  if (S.lang === 'zh') return w.zh;
  const kt = koTitle(w);
  if (kt) return kt.replace(KO_KIND, '');
  let n = w.zh;
  for (const s of ZH_SUFFIX) if (n.endsWith(s) && n.length > s.length) { n = n.slice(0, -s.length); break; }
  return trName(n);
}
function weaponTitle(w) {
  const kt = koTitle(w);
  if (kt) return kt;
  const n = weaponName(w), c = t().cat[weaponCat(w)] || '';
  if (S.lang === 'zh') return /[步枪弓]$/.test(n) || /枪$/.test(n) ? n : n + c;
  return n + ' ' + c;
}
function partName(p) { return trName(p[P.zh]); }
function sockName(sid) { return t().sock[sid] || (S.index && S.index.sockets[sid]) || ('#' + sid); }
const MODE_ORDER = ['Single', 'Burst', 'Auto'];   // 단발, 점사, 연사
function modeText(m) {
  if (Array.isArray(m)) {
    if (!m.length) return '-';
    return [...m].sort((a, b) => MODE_ORDER.indexOf(a) - MODE_ORDER.indexOf(b)).map((x) => t().mode[x] || x).join('/');
  }
  if (!m) return '-';
  return m.split(/[,/]/).map((x) => t().mode[x.trim()] || x.trim()).join('/');
}

// ---------------------------------------------------------------- mounting rules
function providers(sid) {
  const out = [];
  for (const [owner, s, opts] of S.weapon.sockets || []) if (s === sid) out.push({ owner, opts });
  return out;
}
function activeOwners(mount) { const o = new Set([S.weapon.id]); for (const v of mount.values()) o.add(v); return o; }
function optionsOf(sid, mount) {
  const owners = activeOwners(mount), res = [];
  for (const p of providers(sid)) if (owners.has(p.owner)) for (const i of p.opts) if (!res.includes(i)) res.push(i);
  return res;
}
function blockedSockets(mount) {
  const b = new Set();
  for (const [sid, item] of mount) for (const o of (S.weapon.occupy || {})[item] || []) if (o !== sid) b.add(o);
  return b;
}
function settle(mount) {
  const locked = new Set();
  for (let guard = 0; guard < 20; guard++) {
    let changed = false;
    for (const [sid] of [...mount]) if (!optionsOf(sid, mount).includes(mount.get(sid))) { mount.delete(sid); changed = true; }
    for (const sid of blockedSockets(mount)) if (mount.has(sid)) { mount.delete(sid); changed = true; }
    const items = new Set(mount.values()), blocked = blockedSockets(mount);
    locked.clear();
    for (const [sid, item, policy, ctype, citems] of S.weapon.rules || []) {
      const ok = ctype === 'always' || (citems || []).some((i) => items.has(i));
      if (!ok || blocked.has(sid)) continue;
      if (policy === 'forced') {
        locked.add(sid);
        if (mount.get(sid) !== item) { mount.set(sid, item); changed = true; }
      } else if (!mount.has(sid) && optionsOf(sid, mount).includes(item)) { mount.set(sid, item); changed = true; }
    }
    if (!changed) break;
  }
  return locked;
}
function defaultMount() { const m = new Map(); settle(m); return m; }
function withItem(mount, sid, item) {
  const m = new Map(mount);
  if (item == null) m.delete(sid); else m.set(sid, item);
  for (const o of (S.weapon.occupy || {})[item] || []) if (o !== sid) m.delete(o);
  settle(m);
  return m;
}
function defaultItemFor(sid) {
  for (const [s, item, policy, ctype] of S.weapon.rules || []) if (s === sid && policy === 'default' && ctype === 'always') return item;
  return null;
}

// ---------------------------------------------------------------- stats
function computeStats(mount) {
  const b = S.weapon.base, parts = S.weapon.parts;
  let rec = 0, hip = 0, han = 0, sta = 0, rA = 0, rM = 0, rI = null, mI = null, mA = 0, rof = 0;
  for (const item of mount.values()) {
    const p = parts[item]; if (!p) continue;
    rec += p[P.rec] || 0; hip += p[P.hip] || 0; han += p[P.han] || 0; sta += p[P.sta] || 0;
    rA += p[P.rA] || 0; rM += p[P.rM] || 0; mA += p[P.mA] || 0; rof += p[P.rof] || 0;
    if (p[P.rI] != null) rI = p[P.rI];
    if (p[P.mI] != null) mI = p[P.mI];
  }
  return {
    damage: b.damage, range: ((rI != null ? rI : b.range + rA) * (1 + rM / 100)),
    recoil: b.recoil + rec, handling: b.handling + han, stability: b.stability + sta, hip: b.hip + hip,
    armor: b.armor, rpm: b.rpm == null ? null : Math.round(b.rpm * (1 + rof / 100)), capacity: (mI != null ? mI : b.capacity) + mA, mode: b.fireMode,
    velocity: b.velocity == null ? null : b.velocity * (1 + rM / 100), sound: b.sound
  };
}

// ---------------------------------------------------------------- icons
const ICON = {
  damage: '<path d="M2 9h7M5 6l4 3-4 3M10 5l5 4-5 4"/>',
  range: '<path d="M2 9h11M10 6l3 3-3 3M15 4v10"/>',
  recoil: '<path d="M2 7h10l2-2h2v4h-4l-1 5H6l1-3H2z"/>',
  handling: '<path d="M3 11c2-4 5-6 9-6l3 2-3 2c-4 0-6 1-9 4M10 5l2-2"/>',
  stability: '<circle cx="9" cy="9" r="5"/><path d="M9 1v4M9 13v4M1 9h4M13 9h4"/>',
  hip: '<path d="M9 2v3M9 13v3M2 9h3M13 9h3"/><circle cx="9" cy="9" r="1"/>'
};
const LEVEL = (up, n) => {
  const c = up ? 'var(--green)' : 'var(--red)', d = 'rgba(255,255,255,.35)';
  const ys = up ? [13, 9, 5] : [5, 9, 13];
  return `<svg class="lvl" viewBox="0 0 14 18"><path d="M2 2v14" stroke="${d}" stroke-width="1.4"/>${ys.map((y, i) =>
    `<path d="M4 ${y}h${8 - i * 2}" stroke="${i < n ? c : d}" stroke-width="2"/>`).join('')}</svg>`;
};
const WRENCH = '<svg viewBox="0 0 16 16"><path d="M3 13l5-5M9 3l4 4-2 1-3-3zM2 2l3 3"/></svg>';

// ---------------------------------------------------------------- render: top bar
function renderChrome() {
  document.documentElement.lang = S.lang;
  $('langSelect').value = S.lang;
  for (const b of document.querySelectorAll('#serverTabs .tab')) {
    b.textContent = t()[b.dataset.server];
    b.classList.toggle('on', b.dataset.server === S.server);
  }
  $('armoryTitle').textContent = t().armory;
  $('initialLabel').textContent = t().initial;
  $('initialToggle').checked = S.showInitial;
  $('priceLabel').textContent = t().price;
  $('effTitle').textContent = t().effects;
}

// ---------------------------------------------------------------- render: armory
function renderArmory() {
  const idx = S.index;
  const ws = (idx.weapons || []).map(([id, zh, ko, category, image]) => ({ id, zh, ko, category, image }));
  const cats = CAT_ORDER.filter((c) => ws.some((w) => weaponCat(w) === c));
  $('catTabs').innerHTML = ['all', ...cats].map((c) =>
    `<button type="button" data-cat="${c}" class="${S.cat === c ? 'on' : ''}">${esc(c === 'all' ? t().all : t().cat[c])}</button>`).join('');
  const list = ws.filter((w) => S.cat === 'all' || weaponCat(w) === S.cat)
    .sort((a, b) => CAT_ORDER.indexOf(weaponCat(a)) - CAT_ORDER.indexOf(weaponCat(b)) || a.id.localeCompare(b.id));
  $('weaponGrid').innerHTML = list.map((w) => `
    <a class="wcard" href="${weaponUrl(w.id)}" data-id="${w.id}">
      <img class="wimg" src="img/w/${esc(w.id)}.webp" data-alt="img/w/${esc(w.id)}.png ${esc(w.image)}" alt="" loading="lazy" crossorigin="anonymous">
      <span class="wname">${esc(weaponName(w))}</span>
      <span class="wcat">${esc(t().cat[weaponCat(w)] || '')}</span>
    </a>`).join('');
}

// ---------------------------------------------------------------- render: gunsmith
// slots that the in-game gunsmith does not show (73 子弹: S12 special-ammo parts)
const HIDDEN_SOCKETS = new Set([73]);
// slots the game shows even though they only hold unnamed built-in parts (61: compound bow arrow mag)
const SHOWN_FIXED_SOCKETS = new Set([61]);
function visibleSlots() {
  const out = [], blocked = blockedSockets(S.mount);
  const sids = [...new Set((S.weapon.sockets || []).map((s) => s[1]))];
  for (const sid of sids) {
    if (blocked.has(sid) || HIDDEN_SOCKETS.has(sid)) continue;
    const opts = optionsOf(sid, S.mount);
    if (!opts.length) continue;
    if (!SHOWN_FIXED_SOCKETS.has(sid) && !opts.some((i) => S.weapon.parts[i] && S.weapon.parts[i][P.sel])) continue;
    out.push(sid);
  }
  return out;
}

// ---------------------------------------------------------------- gun silhouette
// Reads the official gun image once: where the gun is drawn (bbox) and its top/bottom outline per column,
// so slot lines can point at the real muzzle, magazine, grip, stock, rails and optic.
const shapeCache = new Map();
const FULL = { x0: 0, y0: 0, x1: 1, y1: 1, top: null, bot: null };
function measureGun(url, loaded) {
  if (shapeCache.has(url)) return Promise.resolve(shapeCache.get(url));
  return new Promise((ok) => {
    const im = loaded || new Image();
    if (!loaded) im.crossOrigin = 'anonymous';
    const read = () => {
      let shape = FULL;
      try {
        const w = im.naturalWidth, h = im.naturalHeight, c = document.createElement('canvas');
        c.width = w; c.height = h;
        const g = c.getContext('2d'); g.drawImage(im, 0, 0);
        const d = g.getImageData(0, 0, w, h).data;
        const op = (x, y) => d[(y * w + x) * 4 + 3] > 40;
        let x0 = w, x1 = -1, y0 = h, y1 = -1;
        for (let y = 0; y < h; y += 2) for (let x = 0; x < w; x += 2) if (op(x, y)) {
          if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
        }
        if (x1 > x0 && y1 > y0) {
          const N = 100, top = new Array(N), bot = new Array(N), bw = x1 - x0, bh = y1 - y0;
          for (let i = 0; i < N; i++) {
            const x = Math.round(x0 + (i + 0.5) / N * bw);
            let t = -1, b = -1;
            for (let y = y0; y <= y1; y++) if (op(x, y)) { if (t < 0) t = y; b = y; }
            top[i] = t < 0 ? null : (t - y0) / bh; bot[i] = b < 0 ? null : (b - y0) / bh;
          }
          // fill gaps
          for (let i = 0; i < N; i++) if (top[i] == null) { const j = top.findIndex((v, k) => k > i && v != null); top[i] = j < 0 ? 0.5 : top[j]; bot[i] = j < 0 ? 0.5 : bot[j]; }
          shape = { x0: x0 / w, y0: y0 / h, x1: x1 / w, y1: y1 / h, top, bot };
        }
      } catch (e) { /* image not readable: fixed positions */ }
      shapeCache.set(url, shape); ok(shape);
    };
    if (loaded) { read(); return; }
    im.onload = read;
    im.onerror = () => { shapeCache.set(url, FULL); ok(FULL); };
    im.src = url;
  });
}
// gun rectangle in wrap percentages (object-fit: contain + transparent margins)
function gunRect() {
  const wrap = $('gunWrap'), el = $('gunImg');
  const W = wrap.clientWidth || 1, H = wrap.clientHeight || 1;
  const bw = el.clientWidth, bh = el.clientHeight, nw = el.naturalWidth || 1200, nh = el.naturalHeight || 600;
  const k = Math.min(bw / nw, bh / nh), dw = nw * k, dh = nh * k;
  const ox = el.offsetLeft + (bw - dw) / 2, oy = el.offsetTop + (bh - dh) / 2;
  const b = shapeCache.get(stageSrc(S.weapon)) || FULL;
  return { l: (ox + b.x0 * dw) / W * 100, t: (oy + b.y0 * dh) / H * 100,
           w: (b.x1 - b.x0) * dw / W * 100, h: (b.y1 - b.y0) * dh / H * 100, shape: b };
}
// socket -> point on the gun (fractions of the gun bbox)
function anchorOf(sid, shape, bow, turned) {
  // the bow is shown turned 90 degrees to the left: (x, y) of the flat image becomes (y, 1 - x)
  if (bow && BOW_ANCHOR[sid]) { const a = BOW_ANCHOR[sid]; return turned ? [a[1], 1 - a[0]] : a; }
  const top = shape.top, bot = shape.bot;
  if (!top) { const a = ANCHOR[sid] || [.5, .5]; return a; }
  const at = (arr, fx) => arr[Math.max(0, Math.min(99, Math.round(fx * 100)))];
  const mid = (fx) => (at(top, fx) + at(bot, fx)) / 2;
  // lowest parts of the outline in the middle of the gun = magazine, then the grip behind it
  const lowRuns = [];
  for (let i = 18; i < 92; i++) {
    if (bot[i] > 0.72) { const r = lowRuns[lowRuns.length - 1]; if (r && r.e === i - 1) r.e = i; else lowRuns.push({ s: i, e: i }); }
  }
  const mag = lowRuns.find((r) => r.s / 100 > 0.22 && r.s / 100 < 0.75);
  const magX = mag ? (mag.s + mag.e) / 200 : 0.5;
  // pistol grip: the deepest part of the outline behind the magazine (it is often shorter than the magazine)
  let gripX = Math.min(0.9, magX + 0.12);
  if (mag) {
    const from = mag.e + 3, to = 90, base = [...bot.slice(from, to)].sort((a, b) => a - b)[Math.floor((to - from) * 0.3)] || 0.5;
    let best = -1;
    for (let i = from; i < to; i++) if (bot[i] > base + 0.08 && (best < 0 || bot[i] > bot[best])) best = i;
    if (best >= 0) {
      let s0 = best, e0 = best;
      while (s0 > from && bot[s0 - 1] > (base + bot[best]) / 2) s0--;
      while (e0 < to - 1 && bot[e0 + 1] > (base + bot[best]) / 2) e0++;
      gripX = (s0 + e0) / 200;
    }
  }
  const fore = Math.max(0.12, magX * 0.55);           // handguard area in front of the magazine
  const optX = Math.min(0.85, magX + 0.04);
  const stockX = Math.max(gripX + 0.16, 0.9);
  const P2 = (fx, fy) => [fx, Math.max(0, Math.min(1, fy))];
  switch (sid) {
    case 6: case 77: return P2(0.012, mid(0.012));
    case 2: case 72: return P2(0.09, mid(0.09));
    case 4: case 27: case 37: case 65: return P2(fore, mid(fore));
    case 46: case 17: case 14: return P2(fore + 0.02, at(top, fore + 0.02) + 0.02);
    case 32: return P2(fore + 0.07, at(top, fore + 0.07) + 0.06);
    case 64: return P2(fore - 0.06, at(top, fore - 0.06) + 0.02);
    case 19: return P2(fore - 0.05, mid(fore - 0.05) - 0.04);
    case 34: return P2(fore - 0.01, at(top, fore - 0.01) + 0.05);
    case 20: return P2(fore + 0.05, mid(fore + 0.05) - 0.02);
    case 35: return P2(fore + 0.09, at(top, fore + 0.09) + 0.05);
    case 8: case 18: return P2(fore, at(bot, fore) - 0.02);
    case 10: case 36: return P2(fore - 0.1, at(bot, fore - 0.1) - 0.02);
    case 51: case 47: return P2(fore + 0.1, mid(fore + 0.1));
    case 11: case 21: case 45: return P2(optX, at(top, optX) + 0.03);
    case 40: case 41: case 50: case 69: return P2(optX + 0.03, at(top, optX + 0.03));
    case 31: return P2(optX + 0.09, at(top, optX + 0.09) + 0.08);
    case 9: case 7: return P2(optX + 0.12, at(top, optX + 0.12) + 0.02);
    case 5: case 12: case 66: return P2(magX + 0.005, at(bot, magX) - 0.16);
    case 44: return P2(magX - 0.03, mid(magX - 0.03) + 0.1);
    case 73: return P2(magX + 0.012, at(bot, magX) - 0.06);
    case 1: case 53: case 68: case 43: return P2(gripX, (mid(gripX) + at(bot, gripX)) / 2);
    case 30: case 56: return P2(gripX + 0.02, at(bot, gripX) - 0.06);
    case 49: case 48: return P2(gripX - 0.04, mid(gripX - 0.04) + 0.06);
    case 52: case 76: case 54: return P2(Math.min(0.8, magX + 0.1), mid(Math.min(0.8, magX + 0.1)));
    case 3: case 67: case 75: return P2(stockX, mid(stockX));
    case 38: return P2(stockX - 0.09, mid(stockX - 0.09) + 0.04);
    case 29: return P2(stockX - 0.02, at(top, stockX - 0.02) + 0.04);
    case 28: return P2(0.985, mid(0.985));
    case 22: case 23: return P2(magX + 0.05, mid(magX + 0.05));
    default: { const a = ANCHOR[sid] || [.5, .5]; return a; }
  }
}

// label widths decide spacing; a row that does not fit is split into two staggered rows
const measureCtx = document.createElement('canvas').getContext('2d');
function labelWidth(text, px) { measureCtx.font = `${px}px ${getComputedStyle(document.body).fontFamily}`; return measureCtx.measureText(text).width; }

// minimum-cost assignment (Hungarian method): rows -> columns of a square cost matrix
function assign(c) {
  const n = c.length, u = new Array(n + 1).fill(0), v = new Array(n + 1).fill(0), p = new Array(n + 1).fill(0), way = new Array(n + 1).fill(0);
  for (let i = 1; i <= n; i++) {
    p[0] = i; let j0 = 0;
    const minv = new Array(n + 1).fill(Infinity), used = new Array(n + 1).fill(false);
    do {
      used[j0] = true; const i0 = p[j0]; let delta = Infinity, j1 = 0;
      for (let j = 1; j <= n; j++) if (!used[j]) {
        const cur = c[i0 - 1][j - 1] - u[i0] - v[j];
        if (cur < minv[j]) { minv[j] = cur; way[j] = j0; }
        if (minv[j] < delta) { delta = minv[j]; j1 = j; }
      }
      for (let j = 0; j <= n; j++) if (used[j]) { u[p[j]] += delta; v[j] -= delta; } else minv[j] -= delta;
      j0 = j1;
    } while (p[j0] !== 0);
    do { const j1 = way[j0]; p[j0] = p[j1]; j0 = j1; } while (j0);
  }
  const res = new Array(n);
  for (let j = 1; j <= n; j++) if (p[j]) res[p[j] - 1] = j - 1;
  return res;
}

// slots sit on a rounded ring around the gun. Each slot goes to the place on the ring closest to the point
// it belongs to (lines are short and do not run across the gun), neighbours are pushed apart along the ring
// just enough not to touch, then the order is fixed so that no two lines cross and no line runs through
// another slot.
function layoutSlots(sids) {
  const img = gunRect(), W = $('gunWrap').clientWidth || 800, H = $('gunWrap').clientHeight || 500;
  // phones get smaller slots and tighter spacing so every slot still fits around the gun
  const phone = W < 480;
  const size = phone ? 36 : W < 700 ? 44 : W < 1000 ? 50 : 60, font = phone ? 10 : W < 700 ? 11 : W < 1000 ? 12 : 13;
  const lab = font + 8, pad = 6, gap = phone ? 4 : 8, side = phone ? 4 : 40;
  const lw = (sid) => Math.max(size, labelWidth(sockName(sid), font) + 2);
  // ring: a superellipse (between an ellipse and a rectangle) inside the stage
  const cx = W / 2, cy = (lab + H) / 2;
  const rx = Math.max(60, W / 2 - pad - size / 2 - side), ry = Math.max(40, (H - lab) / 2 - pad - size / 2);
  const n = 3, M = 720, ring = [];
  for (let i = 0; i < M; i++) {
    const t = i / M * Math.PI * 2, c = Math.cos(t), sn = Math.sin(t);
    ring.push([cx + rx * Math.sign(c) * Math.abs(c) ** (2 / n), cy + ry * Math.sign(sn) * Math.abs(sn) ** (2 / n)]);
  }
  const len = [0];
  for (let i = 1; i <= M; i++) { const p = ring[i - 1], q = ring[i % M]; len.push(len[i - 1] + Math.hypot(q[0] - p[0], q[1] - p[1])); }
  const P = len[M];
  const wrapS = (s) => ((s % P) + P) % P;
  const at = (s) => {
    s = wrapS(s);
    let lo = 0, hi = M; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (len[m] <= s) lo = m; else hi = m; }
    const f = (s - len[lo]) / ((len[lo + 1] - len[lo]) || 1), p = ring[lo], q = ring[(lo + 1) % M];
    return [p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f];
  };
  const bow = sids.includes(55);            // only bows have a string slot
  const turned = bow && stageSrc(S.weapon) !== picOf(S.weapon);
  const pts = sids.map((sid) => {
    const a = anchorOf(sid, img.shape, bow, turned);
    const ax = (img.l + a[0] * img.w) / 100 * W, ay = (img.t + a[1] * img.h) / 100 * H;
    return { sid, ax, ay, s: 0, w: lw(sid) };
  });
  const cnt = pts.length;
  if (cnt) {
    const gl = img.l / 100 * W, gt = img.t / 100 * H, gw = img.w / 100 * W, gh = img.h / 100 * H, sh = img.shape;
    const onGun = (x, y) => {
      const fx = (x - gl) / gw;
      if (fx < 0 || fx > 1) return false;
      if (!sh.top) return y > gt && y < gt + gh;
      const k = Math.max(0, Math.min(99, Math.round(fx * 100)));
      return y > gt + sh.top[k] * gh && y < gt + sh.bot[k] * gh;
    };
    // cost of a line: its length, plus a penalty for the part that runs across the gun itself
    const dist = (p, s) => {
      const [x, y] = at(s), d = Math.hypot(x - p.ax, y - p.ay);
      let inside = 0;
      for (let i = 2; i < 38; i++) { const f = i / 40; if (onGun(x + (p.ax - x) * f, y + (p.ay - y) * f)) inside++; }
      return d + 6 * d * inside / 40 + (inside ? 80 : 0);
    };
    // preferred place: the cheapest point of the ring
    for (const p of pts) {
      let best = Infinity;
      for (let i = 0; i < M; i += 2) { const c = dist(p, len[i]); if (c < best) { best = c; p.want = len[i]; } }
    }
    // box + label of a slot standing at ring position s
    const rectAt = (p, s) => { const [x, y] = at(s); return [x - size / 2, y - size / 2 - lab, x - size / 2 + p.w, y + size / 2]; };
    const hit = (A, B) => !(A[2] + gap <= B[0] || B[2] + gap <= A[0] || A[3] + gap <= B[1] || B[3] + gap <= A[1]);
    // smallest distance along the ring after s at which q no longer touches p
    const sep = (p, q, s) => { let d = 4; while (d < P / 2 && hit(rectAt(p, s), rectAt(q, s + d))) d += 3; return d; };
    // put the slots, in the given ring order, as close as possible to where they want to be without touching
    // (isotonic regression with minimum spacing, a few rounds so the spacing matches where they end up)
    const pack = (order) => {
      // open the circle at the widest gap between current places; aim at the wanted place nearest to each
      let cut = 0, wide = -1;
      for (let i = 0; i < cnt; i++) {
        const g = cnt === 1 ? P : wrapS(order[(i + 1) % cnt].s - order[i].s);
        if (g > wide) { wide = g; cut = (i + 1) % cnt; }
      }
      const o = order.slice(cut).concat(order.slice(0, cut));
      const base = o[0].s - 1;
      const tgt = o.map((p) => { const s = base + wrapS(p.s - base); let d = wrapS(p.want - s); if (d > P / 2) d -= P; return s + d; });
      for (let i = 1; i < cnt; i++) if (tgt[i] < tgt[i - 1]) tgt[i] = tgt[i - 1];   // keep order
      let pos = tgt.slice();
      for (let round = 0; round < 6; round++) {
        const d = [0];
        for (let i = 1; i < cnt; i++) d.push(d[i - 1] + sep(o[i - 1], o[i], pos[i - 1]));
        const total = d[cnt - 1] + (cnt > 1 ? sep(o[cnt - 1], o[0], pos[cnt - 1]) : 0);
        const k = total > P ? P / total : 1;
        // pool adjacent violators on want - offset
        const blocks = [];
        for (let i = 0; i < cnt; i++) {
          blocks.push({ v: tgt[i] - d[i] * k, w: 1, n: 1 });
          while (blocks.length > 1 && blocks[blocks.length - 2].v > blocks[blocks.length - 1].v) {
            const B = blocks.pop(), A = blocks[blocks.length - 1];
            A.v = (A.v * A.w + B.v * B.w) / (A.w + B.w); A.w += B.w; A.n += B.n;
          }
        }
        pos = []; let i = 0;
        for (const B of blocks) for (let j = 0; j < B.n; j++, i++) pos.push(B.v + d[i] * k);
      }
      o.forEach((p, i) => { p.s = wrapS(pos[i]); });
    };
    const ringOrder = () => pts.slice().sort((p, q) => p.s - q.s);
    const crosses = (p, q) => {
      const [x1, y1] = at(p.s), [x3, y3] = at(q.s);
      const d = (ax, ay, bx, by, cx2, cy2) => (bx - ax) * (cy2 - ay) - (by - ay) * (cx2 - ax);
      return d(x1, y1, p.ax, p.ay, x3, y3) * d(x1, y1, p.ax, p.ay, q.ax, q.ay) < 0 &&
             d(x3, y3, q.ax, q.ay, x1, y1) * d(x3, y3, q.ax, q.ay, p.ax, p.ay) < 0;
    };
    const through = (p, q) => {          // does p's line pass through q's box or label?
      const [x, y] = at(p.s), r = rectAt(q, q.s), x0 = r[0] - 2, x1 = r[2] + 2, y0 = r[1] - 2, y1 = r[3] + 2;
      for (let i = 1; i < 40; i++) { const f = i / 40, px = x + (p.ax - x) * f, py = y + (p.ay - y) * f; if (px > x0 && px < x1 && py > y0 && py < y1) return true; }
      return false;
    };
    const score = () => {
      let c = 0, t = 0, l = 0;
      for (let i = 0; i < cnt; i++) {
        l += dist(pts[i], pts[i].s);
        for (let j = 0; j < cnt; j++) if (i !== j) { if (j > i && crosses(pts[i], pts[j])) c++; if (through(pts[i], pts[j])) t++; }
      }
      return c * 1e6 + t * 300 + l;
    };
    // 1) everyone near its wanted place
    pts.forEach((p) => { p.s = p.want; });
    pack(ringOrder());
    // 2) which slot takes which of these places: smallest total cost (lines of such an assignment do not cross)
    const places = pts.map((p) => p.s);
    const asg = assign(pts.map((p) => places.map((s) => dist(p, s))));
    pts.forEach((p, i) => { p.s = places[asg[i]]; });
    pack(ringOrder());
    // 3) swap two neighbours on the ring when that removes a crossing or a line running through another slot
    let cur = score();
    for (let pass = 0; pass < 4 && cur >= 300; pass++) {
      let improved = false;
      for (let i = 0; i < cnt; i++) {
        const o = ringOrder(), p = o[i], q = o[(i + 1) % cnt];
        if (p === q) continue;
        const keep = pts.map((x) => x.s);
        [p.s, q.s] = [q.s, p.s];
        pack(ringOrder());
        const sc = score();
        if (sc < cur - 1e-6) { cur = sc; improved = true; } else pts.forEach((x, k) => { x.s = keep[k]; });
      }
      if (!improved) break;
    }
    // 4) any crossing still left: swap the places of the two crossing lines. Swapping the ends of two crossing
    //    lines always makes them shorter in total, so this ends, and it ends with no crossing at all.
    //    Then the slots are spaced again for their own label widths, and that is checked once more.
    const crossCount = () => { let c = 0; for (let i = 0; i < cnt; i++) for (let j = i + 1; j < cnt; j++) if (crosses(pts[i], pts[j])) c++; return c; };
    for (let round = 0; round < 6 && crossCount(); round++) {
      for (let it = 0; it < 200; it++) {
        let found = false;
        for (let i = 0; i < cnt && !found; i++) for (let j = i + 1; j < cnt && !found; j++) if (crosses(pts[i], pts[j])) {
          [pts[i].s, pts[j].s] = [pts[j].s, pts[i].s]; found = true;
        }
        if (!found) break;
      }
      const keep = pts.map((x) => x.s);
      pack(ringOrder());
      if (crossCount() && round === 5) pts.forEach((x, k) => { x.s = keep[k]; });   // keep the uncrossed places
    }
    // 5) last check: neighbours that still touch are pushed apart along the ring, keeping their order
    for (let it = 0; it < 400; it++) {
      const o = ringOrder(); let moved = false;
      for (let i = 0; i < cnt; i++) {
        const p = o[i], q = o[(i + 1) % cnt];
        if (p === q || !hit(rectAt(p, p.s), rectAt(q, q.s))) continue;
        p.s = wrapS(p.s - 1.5); q.s = wrapS(q.s + 1.5); moved = true;
      }
      if (!moved) break;
    }
  }
  for (const p of pts) { const [x, y] = at(p.s); p.x = x; p.y = y; p.bx = x / W * 100; p.by = y / H * 100; }
  $('slots').style.setProperty('--slot', size + 'px');
  $('slots').style.setProperty('--label', font + 'px');
  S.slotSize = size;
  return pts;
}

// gun pictures: the copies kept with the website (WebP, then PNG), or the official address when there is no copy
const picStep = new Map();           // weapon id -> 1 = WebP failed, 2 = PNG failed too
const picOf = (w) => { const k = picStep.get(w.id) || 0; return k === 0 ? `img/w/${w.id}.webp` : k === 1 ? `img/w/${w.id}.png` : w.image; };
// the moment a gun is opened: its data and its picture download at the same time
const warmed = new Set();
function warmWeapon(id) {
  const key = S.server + id;
  if (warmed.has(key)) return;
  warmed.add(key);
  getJSON(`data/${S.server}/w/${id}.json`).catch(() => {});
  const im = new Image(); im.crossOrigin = 'anonymous'; im.src = `img/w/${id}.webp`;
}
const isBow = (w) => (w.sockets || []).some((s) => s[1] === 55);   // only bows have a string slot
const rotated = new Map();          // official image url -> upright copy (blob url), or the original if it cannot be read
const rotating = new Map();
function rotateLeft(url) {
  if (rotating.has(url)) return rotating.get(url);
  const job = new Promise((ok) => {
    const im = new Image();
    im.crossOrigin = 'anonymous';
    im.onload = () => {
      try {
        const c = document.createElement('canvas'), w = im.naturalWidth, h = im.naturalHeight;
        c.width = h; c.height = w;
        const g = c.getContext('2d'); g.translate(0, w); g.rotate(-Math.PI / 2); g.drawImage(im, 0, 0);
        c.toBlob((b) => { rotated.set(url, b ? URL.createObjectURL(b) : url); ok(); }, 'image/png');
      } catch (e) { rotated.set(url, url); ok(); }
    };
    im.onerror = () => { rotated.set(url, url); ok(); };
    im.src = url;
  });
  rotating.set(url, job);
  return job;
}
const stageSrc = (w) => { const p = picOf(w); return isBow(w) ? rotated.get(p) || p : p; };

function renderStage() {
  const w = S.weapon;
  $('gunTitle').textContent = weaponTitle(w);
  const img = $('gunImg');
  // the bow stands upright like in the game: its picture is turned 90 degrees to the left once, in the browser
  if (isBow(w) && !rotated.has(picOf(w))) {
    rotateLeft(picOf(w)).then(() => { if (S.weapon === w) renderStage(); });
    img.style.visibility = 'hidden'; $('slots').innerHTML = ''; $('leaders').innerHTML = ''; return;
  }
  const src = stageSrc(w);
  img.classList.toggle('upright', src !== picOf(w));
  if (img.dataset.src !== src) {
    img.dataset.src = src;
    img.style.visibility = 'hidden';      // no empty frame or previous gun while the new picture loads
    img.crossOrigin = 'anonymous';        // one download serves the picture and the outline measurement
    img.onload = () => { img.style.visibility = ''; measureGun(src, img).then(() => { if (S.weapon === w) renderStage(); }); };
    img.onerror = () => {
      const k = picStep.get(w.id) || 0;
      if (k < 2 && (k === 0 || w.image)) { picStep.set(w.id, k + 1); if (S.weapon === w) renderStage(); return; }   // next copy / official address
      img.style.visibility = 'hidden'; shapeCache.set(src, FULL);    // no picture at all (e.g. AN94): no broken-image frame
      // picture not readable across sites: show it anyway (slots then use fixed positions)
      if (img.crossOrigin) { img.removeAttribute('crossorigin'); img.onload = () => { img.style.visibility = ''; }; img.onerror = null; img.src = src; }
      if (S.weapon === w) renderStage();
    };
    img.src = src;
  } else if (img.complete) img.style.visibility = '';
  // wait until the gun outline is measured, otherwise slots jump once the image arrives
  if (!shapeCache.has(src)) { $('slots').innerHTML = ''; $('leaders').innerHTML = ''; return; }
  const sids = visibleSlots();
  const pts = layoutSlots(sids);
  $('slots').innerHTML = pts.map((p) => {
    const item = S.mount.get(p.sid), part = item && w.parts[item];
    const showImg = part && part[P.sel] && part[P.img];
    const isDefault = !item || item === defaultItemFor(p.sid) || !(part && part[P.sel]);
    return `<button type="button" class="slot${S.slot === p.sid ? ' on' : ''}${isDefault ? '' : ` mod r${RARITY[part[P.rar]] || 0}`}${S.locked.has(p.sid) ? ' locked' : ''}"
      data-sid="${p.sid}" style="left:${p.bx}%;top:${p.by}%">
      <span class="sl">${esc(sockName(p.sid))}</span>
      <span class="sb">${WRENCH}${showImg ? `<img src="img/p/${esc(item)}.webp" data-alt="img/p/${esc(item)}.png ${esc(part[P.img])}" alt="">` : ''}</span></button>`;
  }).join('');
  drawLeaders(pts);
}

function drawLeaders(pts) {
  const wrap = $('gunWrap'), svg = $('leaders');
  const W = wrap.clientWidth, H = wrap.clientHeight;
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  const h = (S.slotSize || 60) / 2;
  svg.innerHTML = pts.map((p) => {
    const x = p.bx / 100 * W, y = p.by / 100 * H, x2 = p.ax, y2 = p.ay;
    // start where the line to the anchor leaves the box
    const dx = x2 - x, dy = y2 - y, k = Math.min(h / (Math.abs(dx) || 1e-6), h / (Math.abs(dy) || 1e-6), 1);
    const x1 = x + dx * k, y1 = y + dy * k;
    return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"/><rect x="${x2 - 4}" y="${y2 - 4}" width="8" height="8"/>`;
  }).join('');
}

function statRows(cur, cmp) {
  const rows = [['damage', 100], ['range', 150], ['recoil', 100], ['handling', 100], ['stability', 100], ['hip', 100]];
  return rows.map(([k, max]) => {
    const v = Math.round(cur[k]), c = cmp ? Math.round(cmp[k]) : v, d = v - c;
    const pv = Math.max(0, Math.min(1, v / max)) * 100, pc = Math.max(0, Math.min(1, c / max)) * 100;
    const unit = k === 'range' ? 'm' : '';
    const cls = d > 0 ? 'up' : d < 0 ? 'dn' : '';
    const seg = d > 0 ? `<i class="f" style="width:${pc}%"></i><i class="g" style="left:${pc}%;width:${pv - pc}%"></i>`
      : d < 0 ? `<i class="f" style="width:${pv}%"></i><i class="r" style="left:${pv}%;width:${pc - pv}%"></i>`
        : `<i class="f" style="width:${pv}%"></i>`;
    const mark = S.showInitial && S.initialStats ? `<i class="m" style="left:${Math.max(0, Math.min(1, S.initialStats[k] / max)) * 100}%"></i>` : '';
    return `<li><span class="ico"><svg viewBox="0 0 18 18">${ICON[k]}</svg></span><span class="lab">${esc(t().stat[k])}</span>
      <span class="val ${cls}">${v}${unit}${d ? `<span class="d">(${d > 0 ? '+' : ''}${d})</span>` : ''}</span>
      <span class="track">${seg}${mark}</span></li>`;
  }).join('');
}

function renderStats() {
  const cur = computeStats(S.mount);
  let show = cur, cmp = null;
  if (S.hover != null && S.slot != null) {
    show = computeStats(withItem(S.mount, S.slot, S.hover === '' ? null : S.hover));
    cmp = cur;
  } else if (S.showInitial) {
    cmp = S.initialStats;
  }
  $('statsTitle').textContent = weaponTitle(S.weapon);
  $('bars').innerHTML = statRows(show, cmp);
  const u = t().unit, s = t().stat;
  const minor = [
    [s.armor, show.armor ?? '-'],
    [s.rpm, show.rpm != null ? `${show.rpm}${u.rpm}` : '-'],
    [s.capacity, show.capacity ?? '-'],
    [s.mode, modeText(show.mode)],
    [s.velocity, show.velocity != null ? `${Math.round(show.velocity)}m/s` : '-'],
    [s.sound, show.sound != null ? `${show.sound}m` : '-']
  ];
  $('minor').innerHTML = minor.map(([a, b]) => `<li><span>${esc(a)}</span><span>${esc(b)}</span></li>`).join('');
}

function renderPartInfo() {
  const w = S.weapon, box = $('partInfo');
  const item = S.hover != null && S.hover !== '' ? S.hover : (S.slot != null ? S.mount.get(S.slot) : null);
  const p = item && w.parts[item];
  if (S.slot == null || !p || !p[P.sel]) { box.hidden = true; return; }
  box.hidden = false;
  const r = RARITY[p[P.rar]] || 0;
  $('partGrade').textContent = ROMAN[r] || '';
  $('partGrade').className = 'r' + r;
  $('partName').textContent = partName(p);
  $('partPriceRow').hidden = p[P.price] == null;
  $('partPrice').textContent = num(p[P.price]) + (p[P.src] === 'c' ? ' (' + t().cnMark + ')' : '');
  const s = t().stat, li = [];
  if (p[P.mI] != null) li.push(`<li class="neutral">· ${esc(fmt(t().magCap, { n: p[P.mI] }))}</li>`);
  const lv = (v) => (v <= 3 ? 1 : v <= 7 ? 2 : 3);
  const rM = p[P.rM] || 0, rA = p[P.rA] || 0;
  if (p[P.rI] != null) li.push(`<li>${LEVEL(true, 2)}<span>${esc(s.rangeEff)}</span></li>`);
  else if (rM || rA) li.push(`<li>${LEVEL(rM + rA > 0, rM ? (Math.abs(rM) <= 10 ? 1 : Math.abs(rM) <= 20 ? 2 : 3) : lv(Math.abs(rA)))}<span>${esc(s.rangeEff)}</span></li>`);
  for (const [label, v] of [[s.recoil, p[P.rec]], [s.stability, p[P.sta]], [s.hip, p[P.hip]], [s.handling, p[P.han]]])
    if (v) li.push(`<li>${LEVEL(v > 0, lv(Math.abs(v)))}<span>${esc(label)}</span></li>`);
  $('partEffects').innerHTML = li.join('');
}

function renderPicker() {
  const smith = $('smith');
  if (S.slot == null) { $('picker').hidden = true; smith.classList.remove('picking'); return; }
  $('picker').hidden = false; smith.classList.add('picking');
  const w = S.weapon, name = sockName(S.slot);
  $('pickerGhost').textContent = name;
  const nf = S.filter.buff.size + S.filter.type.size;
  $('filterLabel').textContent = t().sortDefault + (nf ? ` (${nf})` : '');
  $('filterBtn').classList.toggle('active', nf > 0);
  $('pickerSub').textContent = S.index.hasPrice ? t().onSale : t().parts;
  // same order as the game: highest grade first, then the newest item (higher item id) first
  const opts = slotOptions().filter(passesFilter)
    .sort((a, b) => (RARITY[w.parts[b][P.rar]] || 0) - (RARITY[w.parts[a][P.rar]] || 0) || String(b).localeCompare(String(a), 'en', { numeric: true }));
  const cur = S.mount.get(S.slot), def = defaultItemFor(S.slot);
  const locked = S.locked.has(S.slot);
  let html = '';
  const fixed = SHOWN_FIXED_SOCKETS.has(S.slot);
  if (!locked && !fixed) {
    const isBase = !cur || cur === def || !(w.parts[cur] && w.parts[cur][P.sel]);
    html += `<button type="button" class="pcard none${isBase ? ' on' : ''}" data-item="">${esc(def ? t().base : t().remove)}${isBase ? '<i class="dot"></i>' : ''}</button>`;
  }
  html += opts.map((i) => {
    const p = w.parts[i], r = RARITY[p[P.rar]] || 0, on = i === cur;
    return `<button type="button" class="pcard${on ? ' on' : ''}" data-item="${i}">
      <span class="tag r${r}">${esc(partName(p))}</span>
      ${p[P.img] ? `<img class="pimg" src="img/p/${esc(i)}.webp" data-alt="img/p/${esc(i)}.png ${esc(p[P.img])}" alt="" loading="lazy">` : ''}
      ${p[P.price] != null ? `<span class="pprice">${p[P.src] === 'c' ? `<em class="cnm">${esc(t().cnMark)}</em>` : ''}<i class="coin"></i>${num(p[P.price])}</span>` : ''}
      ${on ? '<i class="dot"></i>' : ''}</button>`;
  }).join('');
  if (!opts.length && nf) html += `<p class="pnone">${esc(t().fNone)}</p>`;
  else if (!opts.length && fixed) html += `<p class="pnone">${esc(t().noParts)}</p>`;
  $('pickerList').innerHTML = html;
}

// ---------------------------------------------------------------- filter (buff attributes / type)
const F_ATTRS = ['range', 'recoil', 'handling', 'stability', 'hip', 'rpm'];
const F_CATS = ['railBipod', 'functional'];
function slotOptions() { const w = S.weapon; return optionsOf(S.slot, S.mount).filter((i) => w.parts[i] && w.parts[i][P.sel]); }
function buffs(p, k) {
  switch (k) {
    case 'range': return (p[P.rM] || 0) > 0 || (p[P.rA] || 0) > 0 || (p[P.rI] != null && p[P.rI] > S.weapon.base.range);
    case 'recoil': return (p[P.rec] || 0) > 0;
    case 'handling': return (p[P.han] || 0) > 0;
    case 'stability': return (p[P.sta] || 0) > 0;
    case 'hip': return (p[P.hip] || 0) > 0;
    case 'rpm': return (p[P.rof] || 0) > 0;
    default: return false;
  }
}
// a part must raise every checked attribute and be one of the checked types
function passesFilter(i) {
  const p = S.weapon.parts[i];
  for (const k of S.filter.buff) if (!buffs(p, k)) return false;
  if (S.filter.type.size && !S.filter.type.has(p[P.cat])) return false;
  return true;
}
let fDraft = null;
function openFilter() {
  fDraft = { buff: new Set(S.filter.buff), type: new Set(S.filter.type) };
  const cats = new Set(slotOptions().map((i) => S.weapon.parts[i][P.cat]));
  const types = F_CATS.filter((c) => cats.has(c));
  $('fTitle').textContent = t().sortDefault;
  $('fBuffHead').textContent = t().fBuff;
  $('fTypeHead').textContent = t().fType;
  $('fOk').textContent = t().fOk;
  $('fEsc').textContent = t().fBack;
  const box = (kind, k, label) => `<label class="fchk"><input type="checkbox" data-kind="${kind}" data-k="${k}"${fDraft[kind].has(k) ? ' checked' : ''}><span class="box"></span><span>${esc(label)}</span></label>`;
  $('fBuff').innerHTML = F_ATTRS.map((k) => box('buff', k, t().fAttr[k])).join('');
  $('fType').innerHTML = types.map((k) => box('type', k, t().fCat[k])).join('');
  $('fTypeRow').hidden = !types.length;
  $('fmodal').hidden = false;
  pushStep('f');
}
function closeFilter(apply, fromHistory) {
  if (apply && fDraft) { S.filter = fDraft; renderPicker(); }
  fDraft = null; $('fmodal').hidden = true;
  if (!fromHistory) popStep('f');
}

function renderTotal() {
  const box = $('totalBox'), w = S.weapon;
  $('totalLabel').textContent = t().total;
  if (!S.index.hasPrice) { box.classList.add('na'); $('totalPrice').textContent = t().noPrice; box.querySelector('.coin').hidden = true; return; }
  box.classList.remove('na'); box.querySelector('.coin').hidden = false;
  const mount = S.hover != null && S.slot != null ? withItem(S.mount, S.slot, S.hover === '' ? null : S.hover) : S.mount;
  let sum = w.price || 0, cn = w.priceSrc === 'c';
  for (const item of mount.values()) { const p = w.parts[item]; if (p && p[P.sel] && p[P.price]) { sum += p[P.price]; if (p[P.src] === 'c') cn = true; } }
  $('totalPrice').textContent = num(sum);
  $('totalNote').textContent = cn ? t().cnNote : '';
  $('totalNote').hidden = !cn;
}
function patchDate() { const d = S.index.effectiveDate || (S.index.version || '').slice(0, 8).replace(/(\d{4})(\d{2})(\d{2})/, '$1-$2-$3'); return d || '-'; }
function renderSmith() {
  // the picker changes the stage width, so it goes first; the slots are laid out for the final size
  renderPicker(); renderStage(); renderPartInfo(); renderStats(); renderTotal();
  const idx = S.index, date = patchDate();
  $('bannerText').textContent = fmt(idx.pending ? t().bannerPending : t().banner, { server: t()[S.server], date });
  $('versionLine').textContent = idx.pending
    ? fmt(t().updatedLive, { at: idx.generatedAt })
    : fmt(t().updated, { date, at: idx.generatedAt });
  if (idx.priceAt) $('versionLine').textContent += ' · ' + fmt(t().priceAt, { at: idx.priceAt });
  $('escLabel').textContent = t().back;
  placeSideAd(); placeFootAd();
}

// ---------------------------------------------------------------- navigation
async function loadIndex() {
  try {
    S.index = await getJSON(`data/${S.server}/index.json`);
  } catch (e) {
    $('weaponGrid').innerHTML = `<p>${esc(t().fail)}</p>`;
    S.index = null;
  }
}
// ---------------------------------------------------------------- history
// Each weapon is its own page (/w/<id>/, made by tools/pages.js), so opening one is a real page view.
// Inside a weapon page the attachment list and the filter are steps in the browser history, so the
// phone's back button closes them like Esc does. history.state: { p: 1 } list open, { f: 1 } filter open
const pageWeapon = (/^\/w\/(\d+)\/?$/.exec(location.pathname) || [])[1] || null;
const weaponUrl = (id) => `/w/${id}/`;
// back to the weapon list: step back when we came from it (keeps the history short), otherwise open it
function goToList() {
  let fromList = false;
  try { const r = new URL(document.referrer); fromList = r.origin === location.origin && r.pathname === '/'; } catch (e) { /* no referrer */ }
  const n = ['p', 'f'].filter((k) => st()[k]).length;
  if (fromList && history.length > n + 1) history.go(-(n + 1)); else location.href = '/';
}
const st = () => history.state || {};
function pushStep(k) { if (!st()[k]) history.pushState({ ...st(), [k]: 1 }, '', location.href); }
function popStep(k) { if (st()[k]) history.back(); }
async function openWeapon(id) {
  warmWeapon(id);                     // the picture downloads while the data is fetched
  try {
    const w = await getJSON(`data/${S.server}/w/${id}.json`);
    S.weapon = w; S.slot = null; S.hover = null; S.filter = { buff: new Set(), type: new Set() };
    S.mount = defaultMount(); S.locked = settle(S.mount);
    S.initialStats = computeStats(S.mount);
    $('armory').hidden = true; $('smith').hidden = false;
    renderSmith();
  } catch (e) { if (pageWeapon) location.replace('/'); else showArmory(); }
}
// ---------------------------------------------------------------- ads
// AdSense ad unit ids (data-ad-slot). Empty = that box stays hidden.
const ADS = { client: 'ca-pub-8298287264238370', side: '8679196017', list: '6811580574' };
function fillAd(box, slot, fixed) {
  if (!slot || box.dataset.filled) return;
  box.dataset.filled = '1';
  box.innerHTML = fixed
    ? `<ins class="adsbygoogle" style="display:inline-block;width:300px;height:250px" data-ad-client="${ADS.client}" data-ad-slot="${slot}"></ins>`
    : `<ins class="adsbygoogle" style="display:block" data-ad-client="${ADS.client}" data-ad-slot="${slot}" data-ad-format="horizontal" data-full-width-responsive="true"></ins>`;
  try { (window.adsbygoogle = window.adsbygoogle || []).push({}); } catch (e) { /* blocked by an ad blocker */ }
}
// the box under the stats panel is shown only when it fits without squeezing the panel
function placeSideAd() {
  const box = $('adSide');
  if (!ADS.side || $('smith').hidden) return;
  const narrow = innerWidth <= 1100;
  const free = $('side').clientHeight - $('detail').scrollHeight - 12;
  const fits = narrow || free >= 250;
  box.hidden = !fits;
  if (fits) fillAd(box, ADS.side, true);
}
// banner under the gun: on a PC only when the window is tall enough to keep the gun big
function placeFootAd() {
  if (!ADS.list || $('smith').hidden) return;
  const box = $('adFoot'), fits = innerWidth <= 1100 || innerHeight >= 900;
  box.hidden = !fits;
  if (fits) fillAd(box, ADS.list, false);
}
function placeListAd() {
  if (!ADS.list) return;
  for (const id of ['adList', 'adListEnd']) { const box = $(id); box.hidden = false; fillAd(box, ADS.list, false); }
}

function showArmory() {
  if (pageWeapon) { goToList(); return; }
  S.weapon = null; S.slot = null; S.hover = null;
  $('smith').hidden = true; $('armory').hidden = false;
  if (S.index) renderArmory();
  placeListAd();
}
async function route() {
  renderChrome();
  await loadIndex();
  const old = /^#w-(\d+)$/.exec(location.hash);             // old address style (#w-<id>)
  if (old) { location.replace(weaponUrl(old[1])); return; }
  if (pageWeapon && S.index && S.index.weapons.some((x) => x[0] === pageWeapon)) await openWeapon(pageWeapon);
  else showArmory();
}

// ---------------------------------------------------------------- events
$('serverTabs').addEventListener('click', async (e) => {
  const b = e.target.closest('.tab'); if (!b || b.dataset.server === S.server) return;
  S.server = b.dataset.server; store.set('server', S.server);
  const keep = S.weapon && S.weapon.id;
  renderChrome(); await loadIndex();
  if (keep && S.index && S.index.weapons.some((x) => x[0] === keep)) await openWeapon(keep); else showArmory();
});
$('langSelect').addEventListener('change', (e) => {
  S.lang = e.target.value; store.set('lang', S.lang); renderChrome();
  if (S.weapon) renderSmith(); else if (S.index) renderArmory();
});
$('catTabs').addEventListener('click', (e) => { const b = e.target.closest('button'); if (!b) return; S.cat = b.dataset.cat; renderArmory(); });
$('toArmory').addEventListener('click', () => showArmory());
// Esc / the Esc button: close the attachment list, or go back to the weapon list (like the game)
function goBack() {
  if ($('smith').hidden) return;
  if (S.slot != null) closePicker(); else showArmory();
}
function closePicker() { S.slot = null; S.hover = null; renderSmith(); popStep('p'); }
$('escBack').addEventListener('click', goBack);
$('slots').addEventListener('click', (e) => {
  const b = e.target.closest('.slot'); if (!b) return;
  const sid = Number(b.dataset.sid);
  if (S.locked.has(sid)) return;
  if (S.slot === sid) { closePicker(); return; }
  S.slot = sid; S.hover = null; S.filter = { buff: new Set(), type: new Set() }; renderSmith();
  pushStep('p');
});
const list = $('pickerList');
list.addEventListener('click', (e) => {
  const b = e.target.closest('.pcard'); if (!b || S.slot == null) return;
  const item = b.dataset.item || null;
  S.mount = withItem(S.mount, S.slot, item);
  S.locked = settle(S.mount); S.hover = null;
  renderSmith();
});
list.addEventListener('pointerover', (e) => {
  if (e.pointerType && e.pointerType !== 'mouse') return;
  const b = e.target.closest('.pcard'); if (!b) return;
  const item = b.dataset.item;
  if (S.hover === item) return;
  S.hover = item; renderPartInfo(); renderStats(); renderTotal();
});
list.addEventListener('pointerleave', () => { if (S.hover == null) return; S.hover = null; renderPartInfo(); renderStats(); renderTotal(); });
$('filterBtn').addEventListener('click', openFilter);
$('fmodal').addEventListener('change', (e) => {
  const c = e.target.closest('input[data-kind]'); if (!c || !fDraft) return;
  const set = fDraft[c.dataset.kind]; if (c.checked) set.add(c.dataset.k); else set.delete(c.dataset.k);
});
$('fOk').addEventListener('click', () => closeFilter(true));
// pictures kept with the website (img/...): when a copy is missing, the next one in data-alt (PNG copy, then the
// official address); when none is left, nothing
document.addEventListener('error', (e) => {
  const im = e.target;
  if (!(im instanceof HTMLImageElement) || !('alt' in im.dataset)) return;
  const rest = im.dataset.alt.split(' ').filter(Boolean);
  if (!rest.length || rest[0] === 'null') { im.style.visibility = 'hidden'; return; }
  im.dataset.alt = rest.slice(1).join(' ');
  im.src = rest[0];
}, true);
$('fEsc').parentElement.addEventListener('click', () => closeFilter(false));
$('initialToggle').addEventListener('change', (e) => { S.showInitial = e.target.checked; renderStats(); });
document.addEventListener('keydown', (e) => {
  if (!$('fmodal').hidden) { if (e.key === 'Escape') closeFilter(false); return; }
  if (e.target.closest('select, input')) return;
  if (e.key === 'Escape') goBack();
  if ((e.key === 'q' || e.key === 'Q') && S.server !== 'cn') document.querySelector('[data-server="cn"]').click();
  if ((e.key === 'e' || e.key === 'E') && S.server !== 'global') document.querySelector('[data-server="global"]').click();
});
// lay the slots out again whenever the stage changes size (window, picker opening/closing, fonts)
let stageSize = '';
const stageObserver = new ResizeObserver(() => {
  const wrap = $('gunWrap'), k = wrap.clientWidth + 'x' + wrap.clientHeight;
  if (k === stageSize) return;
  stageSize = k;
  if (S.weapon && !$('smith').hidden) { renderStage(); placeSideAd(); placeFootAd(); }
});
stageObserver.observe($('gunWrap'));
window.addEventListener('popstate', () => {
  const s0 = st();
  if (!s0.f && !$('fmodal').hidden) closeFilter(false, true);
  if (!s0.p && S.slot != null && !$('smith').hidden) { S.slot = null; S.hover = null; renderSmith(); }
});

// start every download at once: names, weapon list, and on a weapon page its data and picture
getJSON(`data/${S.server}/index.json`).catch(() => {});
if (pageWeapon) warmWeapon(pageWeapon);
loadTerms().then(route);
