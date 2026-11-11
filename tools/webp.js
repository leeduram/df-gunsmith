// Makes a WebP copy (keeps transparency, several times smaller) of every picture in web\img\{w,t,p}\*.png
// whose PNG is new or changed. Run by collect.ps1 after the pictures step.
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const root = path.join(__dirname, '..', 'web', 'img');
(async () => {
  let made = 0, failed = 0;
  for (const dir of ['w', 't', 'p']) {
    const d = path.join(root, dir);
    if (!fs.existsSync(d)) continue;
    for (const f of fs.readdirSync(d)) {
      if (!f.endsWith('.png')) continue;
      const src = path.join(d, f), dst = src.slice(0, -4) + '.webp';
      try {
        if (fs.existsSync(dst) && fs.statSync(dst).mtimeMs >= fs.statSync(src).mtimeMs) continue;
        await sharp(src).webp({ quality: dir === 'w' ? 85 : 80, alphaQuality: 90, effort: 5 }).toFile(dst + '.tmp');
        fs.renameSync(dst + '.tmp', dst);
        made++;
      } catch (e) {
        failed++;
        console.error(f + ': ' + e.message);
      }
    }
  }
  console.log(`webp: ${made} made, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})();
