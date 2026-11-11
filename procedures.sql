-- Build procedures: turn raw_doc rows of one collector run into tables.
-- Safe to run multiple times (drops and recreates the procedures).
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_build_dfttk;
DROP PROCEDURE IF EXISTS sp_build_official;
DROP PROCEDURE IF EXISTS sp_snapshot_official;
DROP PROCEDURE IF EXISTS sp_build_steam;
DROP PROCEDURE IF EXISTS sp_refresh_state;
DROP PROCEDURE IF EXISTS sp_cleanup_raw;
DROP PROCEDURE IF EXISTS sp_build_dfttk_catalog;

DELIMITER $$

-- dfttk: creates a new version only when dataVersion is new
CREATE PROCEDURE sp_build_dfttk(IN p_run VARCHAR(20))
proc: BEGIN
  DECLARE v_ver VARCHAR(64);
  DECLARE v_id INT;
  DECLARE v_items JSON;
  DECLARE v_sockets JSON;

  SELECT body->>'$.dataVersion' INTO v_ver
    FROM raw_doc WHERE run_id = p_run AND source = 'dfttk' AND kind = 'manifest' LIMIT 1;
  IF v_ver IS NULL THEN LEAVE proc; END IF;
  IF EXISTS (SELECT 1 FROM dfttk_version WHERE data_version = v_ver) THEN LEAVE proc; END IF;

  INSERT INTO dfttk_version (data_version, effective_date, run_id)
  VALUES (v_ver,
          IF(v_ver REGEXP '^[0-9]{8}', STR_TO_DATE(LEFT(v_ver, 8), '%Y%m%d'), NULL),
          p_run);
  SET v_id = LAST_INSERT_ID();

  SELECT body->'$.items'   INTO v_items   FROM raw_doc WHERE run_id = p_run AND source = 'dfttk' AND kind = 'items'   LIMIT 1;
  SELECT body->'$.sockets' INTO v_sockets FROM raw_doc WHERE run_id = p_run AND source = 'dfttk' AND kind = 'sockets' LIMIT 1;

  -- weapons
  INSERT INTO weapon (v, weapon_id, name_zh, category, image,
                      attr_range, attr_recoil, attr_hip, attr_handling, attr_stability)
  SELECT v_id, r.ref_id,
         JSON_UNQUOTE(JSON_EXTRACT(v_items, CONCAT('$."', r.ref_id, '"'))),
         JSON_UNQUOTE(JSON_EXTRACT(r.body, CONCAT('$.display.objects."', r.ref_id, '".categoryId'))),
         JSON_UNQUOTE(JSON_EXTRACT(r.body, CONCAT('$.display.objects."', r.ref_id, '".imagePath'))),
         r.body->>'$.weapon.attributes.displayAttrValues."2"',
         r.body->>'$.weapon.attributes.displayAttrValues."3"',
         r.body->>'$.weapon.attributes.displayAttrValues."4"',
         r.body->>'$.weapon.attributes.displayAttrValues."5"',
         r.body->>'$.weapon.attributes.displayAttrValues."6"'
  FROM raw_doc r
  WHERE r.run_id = p_run AND r.source = 'dfttk' AND r.kind = 'weapon';

  -- parts (display objects of every weapon pack)
  INSERT IGNORE INTO part (v, item_id, name_zh, category, rarity, image, player_selectable)
  SELECT v_id, k.item_id,
         JSON_UNQUOTE(JSON_EXTRACT(v_items, CONCAT('$."', k.item_id, '"'))),
         JSON_UNQUOTE(JSON_EXTRACT(r.body, CONCAT('$.display.objects."', k.item_id, '".categoryId'))),
         JSON_UNQUOTE(JSON_EXTRACT(r.body, CONCAT('$.display.objects."', k.item_id, '".rarityId'))),
         JSON_UNQUOTE(JSON_EXTRACT(r.body, CONCAT('$.display.objects."', k.item_id, '".imagePath'))),
         IF(JSON_EXTRACT(r.body, CONCAT('$.display.objects."', k.item_id, '".playerSelectable')) = TRUE, 1, 0)
  FROM raw_doc r
  JOIN JSON_TABLE(JSON_KEYS(r.body->'$.display.objects'), '$[*]' COLUMNS (item_id VARCHAR(32) PATH '$')) k
  WHERE r.run_id = p_run AND r.source = 'dfttk' AND r.kind = 'weapon'
    AND JSON_UNQUOTE(JSON_EXTRACT(r.body, CONCAT('$.display.objects."', k.item_id, '".objectType'))) = 'part';

  -- socket names
  IF v_sockets IS NOT NULL THEN
    INSERT INTO socket_name (v, socket_id, name_zh)
    SELECT v_id, CAST(k.sid AS UNSIGNED), JSON_UNQUOTE(JSON_EXTRACT(v_sockets, CONCAT('$."', k.sid, '"')))
    FROM JSON_TABLE(JSON_KEYS(v_sockets), '$[*]' COLUMNS (sid VARCHAR(16) PATH '$')) k;
  END IF;

  -- compatibility: which items fit which socket
  INSERT INTO socket_option (v, weapon_id, owner_item_id, socket_id, item_id)
  SELECT DISTINCT v_id, r.ref_id, k.owner, s.socket_id, s.item_id
  FROM raw_doc r
  JOIN JSON_TABLE(JSON_KEYS(r.body->'$.assembly.socketProviders'), '$[*]' COLUMNS (owner VARCHAR(32) PATH '$')) k
  JOIN JSON_TABLE(JSON_EXTRACT(r.body, CONCAT('$.assembly.socketProviders."', k.owner, '".sockets')), '$[*]'
         COLUMNS (socket_id INT PATH '$.socketId',
                  NESTED PATH '$.optionItemIds[*]' COLUMNS (item_id VARCHAR(32) PATH '$'))) s
  WHERE r.run_id = p_run AND r.source = 'dfttk' AND r.kind = 'weapon' AND s.item_id IS NOT NULL;

  -- default / forced mounts
  INSERT INTO default_mount (v, weapon_id, rule_no, socket_id, item_id, policy, condition_type, condition_items)
  SELECT v_id, r.ref_id, x.rule_no, x.socket_id, x.item_id, x.policy, x.ctype, x.citems
  FROM raw_doc r
  JOIN JSON_TABLE(JSON_EXTRACT(r.body, CONCAT('$.assembly.coupling."', r.ref_id, '".rules')), '$[*]'
         COLUMNS (rule_no FOR ORDINALITY,
                  socket_id INT PATH '$.targetSocketId',
                  item_id VARCHAR(32) PATH '$.mountedItemId',
                  policy VARCHAR(16) PATH '$.mountPolicy',
                  ctype VARCHAR(16) PATH '$.condition.type',
                  citems JSON PATH '$.condition.itemIds')) x
  WHERE r.run_id = p_run AND r.source = 'dfttk' AND r.kind = 'weapon';

  -- parts that block extra sockets
  INSERT INTO extra_occupancy (v, weapon_id, item_id, socket_id)
  SELECT DISTINCT v_id, r.ref_id, k.item_id, s.socket_id
  FROM raw_doc r
  JOIN JSON_TABLE(JSON_KEYS(r.body->'$.assembly.extraOccupancy'), '$[*]' COLUMNS (item_id VARCHAR(32) PATH '$')) k
  JOIN JSON_TABLE(JSON_EXTRACT(r.body, CONCAT('$.assembly.extraOccupancy."', k.item_id, '".occupiedSocketIds')), '$[*]'
         COLUMNS (socket_id INT PATH '$')) s
  WHERE r.run_id = p_run AND r.source = 'dfttk' AND r.kind = 'weapon';

  -- part effects (Hazard Operations = sol)
  INSERT INTO part_effect (v, weapon_id, item_id, seq, target, modifier, value, scope)
  SELECT v_id, r.ref_id, k.item_id, e.seq, e.target, e.modifier, e.val, e.scope
  FROM raw_doc r
  JOIN JSON_TABLE(JSON_KEYS(r.body->'$.effectsByItemId'), '$[*]' COLUMNS (item_id VARCHAR(32) PATH '$')) k
  JOIN JSON_TABLE(JSON_EXTRACT(r.body, CONCAT('$.effectsByItemId."', k.item_id, '".sol')), '$[*]'
         COLUMNS (seq FOR ORDINALITY,
                  target VARCHAR(100) PATH '$.target',
                  modifier VARCHAR(32) PATH '$.modifier',
                  val DOUBLE PATH '$.value',
                  scope VARCHAR(32) PATH '$.scope')) e
  WHERE r.run_id = p_run AND r.source = 'dfttk' AND r.kind = 'weapon' AND e.target IS NOT NULL;
END proc $$

-- Tencent official: current item info, gun base stats, price history
CREATE PROCEDURE sp_build_official(IN p_run VARCHAR(20))
BEGIN
  INSERT INTO official_item (object_id, primary_class, second_class, name_zh, grade, weight, length, width,
                             avg_price, price_change_rate, pic, pre_pic, updated_at)
  SELECT IF(CHAR_LENGTH(j.object_id) = 10 AND j.object_id LIKE '180%', CONCAT(LEFT(j.object_id, 4), '0', SUBSTRING(j.object_id, 5)), j.object_id),
         j.primary_class, j.second_class, j.name_zh, j.grade, j.weight, j.length, j.width,
         j.avg_price, j.rate, j.pic, j.pre_pic, NOW()
  FROM raw_doc r
  JOIN JSON_TABLE(r.body, '$.jData.data.data.list[*]'
         COLUMNS (object_id VARCHAR(32) PATH '$.objectID',
                  primary_class VARCHAR(16) PATH '$.primaryClass',
                  second_class VARCHAR(32) PATH '$.secondClass',
                  name_zh VARCHAR(100) PATH '$.objectName',
                  grade INT PATH '$.grade',
                  weight DECIMAL(8,3) PATH '$.weight',
                  length INT PATH '$.length',
                  width INT PATH '$.width',
                  avg_price BIGINT PATH '$.avgPrice',
                  rate DECIMAL(10,2) PATH '$.priceChangeRate',
                  pic VARCHAR(255) PATH '$.pic',
                  pre_pic VARCHAR(255) PATH '$.prePic')) j
  WHERE r.run_id = p_run AND r.source = 'official' AND r.kind IN ('gun', 'acc')
  ON DUPLICATE KEY UPDATE primary_class = VALUES(primary_class), second_class = VALUES(second_class),
    name_zh = VALUES(name_zh), grade = VALUES(grade), weight = VALUES(weight), length = VALUES(length),
    width = VALUES(width), avg_price = VALUES(avg_price), price_change_rate = VALUES(price_change_rate),
    pic = VALUES(pic), pre_pic = VALUES(pre_pic), updated_at = VALUES(updated_at);

  INSERT INTO official_gun (object_id, meat_harm, armor_harm, shoot_distance, recoil, control_speed, stable,
                            hip_shot, fire_speed, capacity, fire_mode, muzzle_velocity, sound_distance, caliber, updated_at)
  SELECT IF(CHAR_LENGTH(j.object_id) = 10 AND j.object_id LIKE '180%', CONCAT(LEFT(j.object_id, 4), '0', SUBSTRING(j.object_id, 5)), j.object_id),
         j.meat, j.armor, j.dist, j.recoil, j.ctrl, j.stable, j.hip, j.rpm, j.cap,
         j.mode, j.vel, j.sound, j.caliber, NOW()
  FROM raw_doc r
  JOIN JSON_TABLE(r.body, '$.jData.data.data.list[*]'
         COLUMNS (object_id VARCHAR(32) PATH '$.objectID',
                  meat INT PATH '$.gunDetail.meatHarm',
                  armor INT PATH '$.gunDetail.armorHarm',
                  dist INT PATH '$.gunDetail.shootDistance',
                  recoil INT PATH '$.gunDetail.recoil',
                  ctrl INT PATH '$.gunDetail.control',
                  stable INT PATH '$.gunDetail.stable',
                  hip INT PATH '$.gunDetail.hipShot',
                  rpm INT PATH '$.gunDetail.fireSpeed',
                  cap INT PATH '$.gunDetail.capacity',
                  mode VARCHAR(64) PATH '$.gunDetail.fireMode',
                  vel INT PATH '$.gunDetail.muzzleVelocity',
                  sound INT PATH '$.gunDetail.soundDistance',
                  caliber VARCHAR(32) PATH '$.gunDetail.caliber')) j
  WHERE r.run_id = p_run AND r.source = 'official' AND r.kind = 'gun'
  ON DUPLICATE KEY UPDATE meat_harm = VALUES(meat_harm), armor_harm = VALUES(armor_harm),
    shoot_distance = VALUES(shoot_distance), recoil = VALUES(recoil), control_speed = VALUES(control_speed),
    stable = VALUES(stable), hip_shot = VALUES(hip_shot), fire_speed = VALUES(fire_speed),
    capacity = VALUES(capacity), fire_mode = VALUES(fire_mode), muzzle_velocity = VALUES(muzzle_velocity),
    sound_distance = VALUES(sound_distance), caliber = VALUES(caliber), updated_at = VALUES(updated_at);

  -- numbers used for the season merge (see official_stat in schema.sql); an attachment lists only non-zero effects
  INSERT INTO official_stat (object_id, kind, recoil, hip, handling, stability, range_pct, updated_at)
  SELECT j.object_id, 'acc', COALESCE(j.recoil, 0), COALESCE(j.hip, 0), COALESCE(j.ctrl, 0), COALESCE(j.stable, 0),
         COALESCE(j.pct, 0), NOW()
  FROM raw_doc r
  JOIN JSON_TABLE(r.body, '$.jData.data.data.list[*]'
         COLUMNS (object_id VARCHAR(32) PATH '$.objectID',
                  recoil INT PATH '$.accDetail.recoil',
                  hip INT PATH '$.accDetail.hipShot',
                  ctrl INT PATH '$.accDetail.controlSpeed',
                  stable INT PATH '$.accDetail.controlStable',
                  pct INT PATH '$.accDetail.shotDistancePercent')) j
  WHERE r.run_id = p_run AND r.source = 'official' AND r.kind = 'acc'
  ON DUPLICATE KEY UPDATE recoil = VALUES(recoil), hip = VALUES(hip), handling = VALUES(handling),
    stability = VALUES(stability), range_pct = VALUES(range_pct), updated_at = VALUES(updated_at);

  INSERT INTO official_stat (object_id, kind, recoil, hip, handling, stability, range_m, dmg, armor, rpm, capacity,
                             velocity, sound, updated_at)
  SELECT object_id, 'gun', recoil, hip_shot, control_speed, stable, shoot_distance, meat_harm, armor_harm, fire_speed,
         capacity, muzzle_velocity, sound_distance, NOW()
  FROM official_gun
  ON DUPLICATE KEY UPDATE recoil = VALUES(recoil), hip = VALUES(hip), handling = VALUES(handling),
    stability = VALUES(stability), range_m = VALUES(range_m), dmg = VALUES(dmg), armor = VALUES(armor),
    rpm = VALUES(rpm), capacity = VALUES(capacity), velocity = VALUES(velocity), sound = VALUES(sound),
    updated_at = VALUES(updated_at);

  INSERT IGNORE INTO price_history (object_id, run_id, avg_price)
  SELECT j.object_id, p_run, j.avg_price
  FROM raw_doc r
  JOIN JSON_TABLE(r.body, '$.jData.data.data.list[*]'
         COLUMNS (object_id VARCHAR(32) PATH '$.objectID', avg_price BIGINT PATH '$.avgPrice')) j
  WHERE r.run_id = p_run AND r.source = 'official' AND r.kind IN ('gun', 'acc');
END $$

-- starting point for the season merge of dfttk version p_v: the official numbers as they are now
-- (called when a new dfttk version is stored, which is before the patch goes live). Never overwritten.
CREATE PROCEDURE sp_snapshot_official(IN p_v INT)
BEGIN
  INSERT IGNORE INTO official_baseline (v, object_id, kind, recoil, hip, handling, stability, range_pct, range_m,
                                        dmg, armor, rpm, capacity, velocity, sound)
  SELECT p_v, object_id, kind, recoil, hip, handling, stability, range_pct, range_m, dmg, armor, rpm, capacity,
         velocity, sound
  FROM official_stat;
END $$

-- Steam: record official announcements that look like an update notice
CREATE PROCEDURE sp_build_steam(IN p_run VARCHAR(20))
BEGIN
  INSERT IGNORE INTO global_signal (kind, value, detail, detected_at)
  SELECT 'announcement', n.gid, LEFT(n.title, 500), FROM_UNIXTIME(n.pub)
  FROM raw_doc r
  JOIN JSON_TABLE(r.body, '$.appnews.newsitems[*]'
         COLUMNS (gid VARCHAR(64) PATH '$.gid',
                  title VARCHAR(1000) PATH '$.title',
                  feedlabel VARCHAR(100) PATH '$.feedlabel',
                  pub BIGINT PATH '$.date')) n
  WHERE r.run_id = p_run AND r.source = 'steam' AND r.kind = 'news'
    AND n.feedlabel = 'Community Announcements'
    AND n.title REGEXP '(?i)(patch|update|season|balance|maintenance|adjust)';
END $$

-- decide which dfttk version each server shows
--  cn     : newest version whose China patch date has arrived
--  global : newest version the global server has been detected on. Detection = after the version appeared,
--           the Steam client build changed AND an official update announcement was posted within 1 day of it.
--  A server with mode = 'manual' is never changed here.
CREATE PROCEDURE sp_refresh_state()
BEGIN
  UPDATE dfttk_version d
  SET d.global_since = NOW()
  WHERE d.global_since IS NULL
    AND (d.effective_date IS NULL OR d.effective_date <= CURDATE())
    AND EXISTS (SELECT 1 FROM global_signal b JOIN global_signal a
                  ON a.kind = 'announcement' AND ABS(TIMESTAMPDIFF(HOUR, a.detected_at, b.detected_at)) <= 24
                WHERE b.kind = 'build' AND b.detected_at >= d.first_seen AND a.detected_at >= d.first_seen);

  UPDATE server_state st
  JOIN (SELECT id FROM dfttk_version
        WHERE effective_date IS NULL OR effective_date <= CURDATE()
        ORDER BY effective_date DESC, id DESC LIMIT 1) d
  SET st.dfttk_version_id = d.id, st.updated_at = NOW(), st.note = 'auto'
  WHERE st.server = 'cn' AND st.mode = 'auto' AND (st.dfttk_version_id IS NULL OR st.dfttk_version_id <> d.id);

  UPDATE server_state st
  JOIN (SELECT id FROM dfttk_version WHERE global_since IS NOT NULL
        ORDER BY global_since DESC, id DESC LIMIT 1) d
  SET st.dfttk_version_id = d.id, st.updated_at = NOW(), st.note = 'auto'
  WHERE st.server = 'global' AND st.mode = 'auto' AND (st.dfttk_version_id IS NULL OR st.dfttk_version_id <> d.id);
END $$

-- weapon stats (damage, armor damage, fire rate, fire modes, muzzle velocity) from the dfttk weapon catalog
-- downloaded in run p_run, plus gunshot distance and magazine size from the stored weapon packs of that version.
CREATE PROCEDURE sp_build_dfttk_catalog(IN p_run VARCHAR(20))
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_run VARCHAR(20);
  DECLARE c JSON;
  SELECT d.id, d.run_id INTO v_id, v_run
    FROM raw_doc r JOIN dfttk_version d ON d.data_version = r.body->>'$.dataVersion' COLLATE utf8mb4_unicode_ci
    WHERE r.run_id = p_run AND r.source = 'dfttk' AND r.kind = 'manifest' LIMIT 1;
  SELECT body INTO c FROM raw_doc WHERE run_id = p_run AND source = 'dfttk' AND kind = 'weaponCatalog' LIMIT 1;
  IF v_id IS NULL OR c IS NULL THEN LEAVE proc; END IF;

  UPDATE weapon w SET
    w.dmg        = JSON_EXTRACT(c, CONCAT('$.objects."', w.weapon_id, '".combatSummaryByMode.sol.baseFleshDamage')),
    w.armor_dmg  = JSON_EXTRACT(c, CONCAT('$.objects."', w.weapon_id, '".combatSummaryByMode.sol.baseArmorDamage')),
    w.rpm        = ROUND(COALESCE(
                     JSON_EXTRACT(c, CONCAT('$.objects."', w.weapon_id, '".combatSummaryByMode.sol.displayFireRateRpm')),
                     JSON_EXTRACT(c, CONCAT('$.objects."', w.weapon_id, '".combatSummaryByMode.sol.fireRateRpm')))),
    w.fire_modes = JSON_EXTRACT(c, CONCAT('$.objects."', w.weapon_id, '".combatSummaryByMode.sol.supportedFireModes')),
    w.velocity   = JSON_EXTRACT(c, CONCAT('$.objects."', w.weapon_id, '".combatSummaryByMode.sol.muzzleVelocityMps'))
  WHERE w.v = v_id;

  UPDATE weapon w
  JOIN raw_doc r ON r.run_id = v_run AND r.source = 'dfttk' AND r.kind = 'weapon' AND r.ref_id = w.weapon_id
  SET w.sound = r.body->>'$.weapon.acoustics.shotDistanceMeters',
      w.clip  = r.body->>'$.weapon.ammunition.clipCapacity'
  WHERE w.v = v_id;

  SELECT COUNT(*) FROM weapon WHERE v = v_id AND dmg IS NOT NULL;
END $$

-- keep raw documents small: keep dfttk raw only for the run that created a version, drop others after build
CREATE PROCEDURE sp_cleanup_raw(IN p_run VARCHAR(20))
BEGIN
  DELETE FROM raw_doc
  WHERE run_id = p_run
    AND (source <> 'dfttk' OR run_id NOT IN (SELECT run_id FROM dfttk_version));
  -- China price history (one row per item per hour, not shown on the site yet): keep 90 days, trimmed once a day
  IF HOUR(NOW()) = 0 THEN
    DELETE FROM price_history WHERE run_id < DATE_FORMAT(NOW() - INTERVAL 90 DAY, '%Y%m%d');
  END IF;
END $$


-- (name keys are computed inline: stored functions need extra MySQL privileges when binary logging is on)
DROP FUNCTION IF EXISTS fn_dft_norm $$
DROP FUNCTION IF EXISTS fn_dft_wnorm $$

-- load one deltaforcetools fetch (raw_doc source='dft', kind='auction'): match new items, store prices
-- rows: {k: item key, n: English name, s: Simplified name, c: 'A' attachment / 'F' firearm, p: price, u: update time (KST), v: prices seen 2026-11-04 13:00-16:30}
DROP PROCEDURE IF EXISTS sp_load_dft $$
CREATE PROCEDURE sp_load_dft(IN p_run VARCHAR(20))
BEGIN
  DECLARE vv INT;
  SELECT MAX(id) INTO vv FROM dfttk_version;
  DROP TEMPORARY TABLE IF EXISTS t_dft;
  CREATE TEMPORARY TABLE t_dft (
    k VARCHAR(255) COLLATE utf8mb4_bin PRIMARY KEY, n VARCHAR(255), s VARCHAR(255), c CHAR(1), p BIGINT, u DATETIME, v JSON,
    nz VARCHAR(255) COLLATE utf8mb4_bin, wz VARCHAR(255) COLLATE utf8mb4_bin) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
  INSERT IGNORE INTO t_dft (k, n, s, c, p, u, v)
    SELECT j.k, j.n, j.s, j.c, j.p, STR_TO_DATE(j.u, '%Y-%m-%d %H:%i:%s'), j.v
    FROM raw_doc r, JSON_TABLE(r.body, '$[*]' COLUMNS (
      k VARCHAR(255) PATH '$.k', n VARCHAR(255) PATH '$.n', s VARCHAR(255) PATH '$.s', c CHAR(1) PATH '$.c',
      p BIGINT PATH '$.p', u VARCHAR(20) PATH '$.u', v JSON PATH '$.v')) j
    WHERE r.run_id = p_run AND r.source = 'dft' AND r.kind = 'auction' AND j.k IS NOT NULL AND j.p > 0;
  UPDATE t_dft SET nz = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(s), '後', '后'), '摺', '折'), '昇', '升'), '蠍', '蝎'), '（', '('), '）', ')'), '衞', '卫'), '扩充', '扩容'), '手电筒', '手电'), '延长', '加长'), '口径快拔', '快拔'), 'x', '*'), ' ', ''), '-', ''), '.', ''), '·', ''), '_', ''),
    wz = REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(s), '後', '后'), '摺', '折'), '昇', '升'), '蠍', '蝎'), '（', '('), '）', ')'), '衞', '卫'), '扩充', '扩容'), '手电筒', '手电'), '延长', '加长'), '口径快拔', '快拔'), 'x', '*'), ' ', ''), '-', ''), '.', ''), '·', ''), '_', ''), '(突击步枪|战斗步枪|精确射手步枪|射手步枪|狙击步枪|冲锋枪|轻机枪|通用机枪|机枪|霰弹枪|手枪|步枪)$', '') WHERE s IS NOT NULL AND s <> '';

  -- our objects with a unique name key
  DROP TEMPORARY TABLE IF EXISTS t_obj;
  CREATE TEMPORARY TABLE t_obj (object_id VARCHAR(32) PRIMARY KEY, c CHAR(1), nz VARCHAR(255) COLLATE utf8mb4_bin, KEY (nz)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
  INSERT IGNORE INTO t_obj SELECT item_id, 'A', REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(name_zh), '後', '后'), '摺', '折'), '昇', '升'), '蠍', '蝎'), '（', '('), '）', ')'), '衞', '卫'), '扩充', '扩容'), '手电筒', '手电'), '延长', '加长'), '口径快拔', '快拔'), 'x', '*'), ' ', ''), '-', ''), '.', ''), '·', ''), '_', '') FROM part WHERE v = vv AND name_zh IS NOT NULL;
  INSERT IGNORE INTO t_obj SELECT weapon_id, 'F', REGEXP_REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(name_zh), '後', '后'), '摺', '折'), '昇', '升'), '蠍', '蝎'), '（', '('), '）', ')'), '衞', '卫'), '扩充', '扩容'), '手电筒', '手电'), '延长', '加长'), '口径快拔', '快拔'), 'x', '*'), ' ', ''), '-', ''), '.', ''), '·', ''), '_', ''), '(突击步枪|战斗步枪|精确射手步枪|射手步枪|狙击步枪|冲锋枪|轻机枪|通用机枪|机枪|霰弹枪|手枪|步枪)$', '') FROM weapon WHERE v = vv AND name_zh IS NOT NULL;
  DROP TEMPORARY TABLE IF EXISTS t_dup;
  CREATE TEMPORARY TABLE t_dup (c CHAR(1), nz VARCHAR(255) COLLATE utf8mb4_bin, PRIMARY KEY (c, nz)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
  INSERT IGNORE INTO t_dup SELECT c, nz FROM t_obj GROUP BY c, nz HAVING COUNT(*) > 1;
  DELETE o FROM t_obj o JOIN t_dup d ON d.c = o.c AND d.nz = o.nz;

  -- 1) names worded differently on the site
  INSERT IGNORE INTO dft_map (en_key, object_id, method)
    SELECT t.k, o.object_id, 'alias' FROM t_dft t
    JOIN dft_alias a ON a.dft_name IN (t.s, t.k)
    JOIN t_obj o ON o.c = t.c AND o.nz = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(a.name_zh), '後', '后'), '摺', '折'), '昇', '升'), '蠍', '蝎'), '（', '('), '）', ')'), '衞', '卫'), '扩充', '扩容'), '手电筒', '手电'), '延长', '加长'), '口径快拔', '快拔'), 'x', '*'), ' ', ''), '-', ''), '.', ''), '·', ''), '_', '')
    WHERE t.k NOT IN (SELECT en_key FROM dft_map);
  -- 2) same name
  INSERT IGNORE INTO dft_map (en_key, object_id, method)
    SELECT t.k, o.object_id, 'name' FROM t_dft t
    JOIN t_obj o ON o.c = t.c AND o.nz = IF(t.c = 'F', t.wz, t.nz)
    WHERE t.k NOT IN (SELECT en_key FROM dft_map)
      AND o.object_id NOT IN (SELECT object_id FROM dft_map);
  -- 3) still unmatched: the site's price at the time of the market recording equals exactly one recorded price
  DROP TEMPORARY TABLE IF EXISTS t_vid;
  CREATE TEMPORARY TABLE t_vid (k VARCHAR(255) COLLATE utf8mb4_bin, object_id VARCHAR(32)) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
  INSERT INTO t_vid
    SELECT t.k, g.object_id FROM t_dft t
    JOIN price_global g ON g.source = 'video' AND JSON_CONTAINS(t.v, CAST(g.price AS JSON))
    JOIN t_obj o ON o.object_id = g.object_id AND o.c = t.c
    WHERE t.k NOT IN (SELECT en_key FROM dft_map) AND g.object_id NOT IN (SELECT object_id FROM dft_map);
  DROP TEMPORARY TABLE IF EXISTS t_vk;
  CREATE TEMPORARY TABLE t_vk (k VARCHAR(255) PRIMARY KEY, n INT) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
  INSERT INTO t_vk SELECT k, COUNT(*) FROM t_vid GROUP BY k;
  DROP TEMPORARY TABLE IF EXISTS t_vo;
  CREATE TEMPORARY TABLE t_vo (object_id VARCHAR(32) PRIMARY KEY, n INT) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;
  INSERT INTO t_vo SELECT object_id, COUNT(*) FROM t_vid GROUP BY object_id;
  INSERT IGNORE INTO dft_map (en_key, object_id, method)
    SELECT x.k, x.object_id, 'video' FROM t_vid x
    JOIN t_vk ON t_vk.k = x.k AND t_vk.n = 1
    JOIN t_vo ON t_vo.object_id = x.object_id AND t_vo.n = 1;

  -- prices (newest observation wins; a market recording newer than the site's data is kept)
  INSERT INTO price_global (object_id, price, source, observed_at)
    SELECT * FROM (SELECT m.object_id, t.p AS price, 'dft' AS source, t.u AS observed_at
                   FROM t_dft t JOIN dft_map m ON m.en_key = t.k WHERE t.u IS NOT NULL) AS nv
  ON DUPLICATE KEY UPDATE
    price = IF(nv.observed_at >= price_global.observed_at, nv.price, price_global.price),
    source = IF(nv.observed_at >= price_global.observed_at, nv.source, price_global.source),
    observed_at = GREATEST(price_global.observed_at, nv.observed_at);

  -- official English names of matched attachments
  INSERT INTO name_en_official (name_zh, name_en, source)
    SELECT * FROM (SELECT p.name_zh, REGEXP_REPLACE(MAX(t.n), '[\\x{200B}-\\x{200F}]', '') AS name_en, 'dft' AS source
                   FROM t_dft t JOIN dft_map m ON m.en_key = t.k
                   JOIN part p ON p.v = vv AND p.item_id = m.object_id
                   WHERE t.c = 'A' AND t.n IS NOT NULL AND t.n <> '' AND p.name_zh IS NOT NULL
                   GROUP BY p.name_zh) AS nv
  ON DUPLICATE KEY UPDATE name_en = nv.name_en;

  DELETE FROM dft_unmapped;
  INSERT IGNORE INTO dft_unmapped (en_key, name_en, name_s, price, seen_at)
    SELECT k, n, s, p, u FROM t_dft WHERE k NOT IN (SELECT en_key FROM dft_map);
  SELECT COUNT(*) INTO @dft_n FROM t_dft;
  SELECT COUNT(*) INTO @dft_m FROM t_dft t JOIN dft_map m ON m.en_key = t.k;
  SELECT CONCAT(@dft_n, ' items, ', @dft_m, ' matched, ', (SELECT COUNT(*) FROM dft_unmapped), ' unmatched');
END $$

DELIMITER ;
