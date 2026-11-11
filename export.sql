-- Export procedures: produce the JSON files the website reads.
-- Safe to run multiple times.
SET NAMES utf8mb4;

DROP FUNCTION IF EXISTS fn_server_version;
DROP PROCEDURE IF EXISTS sp_export_index;
DROP PROCEDURE IF EXISTS sp_export_weapons;

DELIMITER $$

-- one row: index JSON (weapon list + socket names)
-- the server's version is used, or the newest stored version when the server has none yet (pending = true)
CREATE PROCEDURE sp_export_index(IN p_server VARCHAR(8))
BEGIN
  DECLARE vv INT;
  SELECT dfttk_version_id INTO vv FROM server_state WHERE server = p_server;
  IF vv IS NULL THEN SELECT MAX(id) INTO vv FROM dfttk_version; END IF;
  SELECT JSON_OBJECT(
    'server', p_server,
    'version', (SELECT data_version FROM dfttk_version WHERE id = vv),
    'effectiveDate', (SELECT DATE_FORMAT(effective_date, '%Y-%m-%d') FROM dfttk_version WHERE id = vv),
    'pending', (SELECT dfttk_version_id IS NULL FROM server_state WHERE server = p_server),
    'hasPrice', TRUE,
    'priceAt', IF(p_server = 'global', (SELECT DATE_FORMAT(MAX(observed_at), '%Y-%m-%d %H:%i') FROM price_global), NULL),
    'generatedAt', DATE_FORMAT(NOW(), '%Y-%m-%d %H:%i'),
    'weapons', (SELECT JSON_ARRAYAGG(JSON_ARRAY(w.weapon_id, w.name_zh, k.name_ko, w.category, w.image))
                FROM weapon w LEFT JOIN name_ko k ON k.object_id = w.weapon_id
                WHERE w.v = vv),
    'sockets', (SELECT JSON_OBJECTAGG(socket_id, name_zh) FROM socket_name WHERE socket_name.v = vv),
    'names', (SELECT JSON_OBJECTAGG(i.name_zh, JSON_ARRAY(i.name_ko, COALESCE(o.name_en, i.name_en)))
              FROM name_i18n i LEFT JOIN name_en_official o ON o.name_zh = i.name_zh),
    'titles', (SELECT JSON_OBJECTAGG(weapon_id, title_ko) FROM weapon_title)
  ) AS j;
END $$

-- one row per weapon: (weapon_id, JSON)
-- parts: id -> [zh, ko, category, rarity, image, price, selectable,
--               rangeInitial, rangeAdd, rangeMultPct, recoil, hip, handling, stability, magInitial, magAdd, fireRatePct,
--               priceSrc]  priceSrc (global only): 'g' = global market, 'c' = China price shown because no global price is known
CREATE PROCEDURE sp_export_weapons(IN p_server VARCHAR(8))
BEGIN
  DECLARE vv INT;
  DECLARE with_price TINYINT DEFAULT 1;
  DECLARE is_g TINYINT DEFAULT (p_server = 'global');  -- global: global price when known, else China price (marked 'c')
  -- the server's version, or the newest stored version when the server has none yet
  SELECT dfttk_version_id INTO vv FROM server_state WHERE server = p_server;
  IF vv IS NULL THEN SELECT MAX(id) INTO vv FROM dfttk_version; END IF;

  SELECT w.weapon_id,
    JSON_OBJECT(
      'id', w.weapon_id, 'zh', w0.name_zh, 'ko', k.name_ko, 'category', w0.category, 'image', w0.image,
      'price', IF(with_price, IF(is_g, COALESCE(pgw.price, NULLIF(og_item.avg_price, 0)), NULLIF(og_item.avg_price, 0)), NULL),
      'priceSrc', IF(is_g, IF(pgw.price IS NOT NULL, 'g', IF(NULLIF(og_item.avg_price, 0) IS NOT NULL, 'c', NULL)), NULL),
      'base', JSON_OBJECT(
        'range', w.attr_range, 'recoil', w.attr_recoil, 'hip', w.attr_hip,
        'handling', w.attr_handling, 'stability', w.attr_stability,
        'damage', w.dmg, 'armor', w.armor_dmg, 'rpm', w.rpm, 'capacity', w.clip,
        'fireMode', w.fire_modes, 'velocity', w.velocity, 'sound', w.sound),
      'sockets', (SELECT JSON_ARRAYAGG(JSON_ARRAY(s.owner_item_id, s.socket_id, s.opts))
                  FROM (SELECT owner_item_id, socket_id, JSON_ARRAYAGG(item_id) AS opts
                        FROM socket_option so WHERE so.v = vv AND so.weapon_id = w.weapon_id
                          AND so.item_id NOT IN (SELECT item_id FROM part_hidden)
                        GROUP BY owner_item_id, socket_id) s),
      'rules', (SELECT JSON_ARRAYAGG(JSON_ARRAY(dm.socket_id, dm.item_id, dm.policy, dm.condition_type, dm.condition_items))
                FROM (SELECT * FROM default_mount x WHERE x.v = vv AND x.weapon_id = w.weapon_id ORDER BY x.rule_no) dm),
      'occupy', (SELECT JSON_OBJECTAGG(o.item_id, o.sids)
                 FROM (SELECT item_id, JSON_ARRAYAGG(socket_id) sids FROM extra_occupancy eo
                       WHERE eo.v = vv AND eo.weapon_id = w.weapon_id GROUP BY item_id) o),
      'parts', (SELECT JSON_OBJECTAGG(i.item_id, JSON_ARRAY(
                   IF(p.name_zh LIKE '内部配件%' AND oi.name_zh IS NOT NULL, oi.name_zh, p.name_zh), pk.name_ko, p.category,
                   COALESCE(rs.rarity, p.rarity, ELT(oi.grade, '白', '绿', '蓝', '紫', '金', '红')), p.image,
                   IF(with_price, IF(is_g, COALESCE(pg.price, NULLIF(oi.avg_price, 0)), NULLIF(oi.avg_price, 0)), NULL),
                   (oi.object_id IS NOT NULL OR p.player_selectable = 1),
                   d.range_initial, d.range_add, d.range_mult_pct, d.recoil, d.hip, d.handling, d.stability,
                   d.mag_initial, d.mag_add, d.rof_pct,
                   IF(is_g, IF(pg.price IS NOT NULL, 'g', IF(NULLIF(oi.avg_price, 0) IS NOT NULL, 'c', NULL)), NULL)))
                FROM (SELECT item_id FROM socket_option so2 WHERE so2.v = vv AND so2.weapon_id = w.weapon_id
                        AND so2.item_id NOT IN (SELECT item_id FROM part_hidden)
                      UNION SELECT item_id FROM default_mount dm2 WHERE dm2.v = vv AND dm2.weapon_id = w.weapon_id) i
                JOIN part p ON p.v = vv AND p.item_id = i.item_id
                LEFT JOIN v_part_final d ON d.v = vv AND d.weapon_id = w.weapon_id AND d.item_id = i.item_id
                LEFT JOIN official_item oi ON oi.object_id = i.item_id
                LEFT JOIN price_global pg ON pg.object_id = i.item_id
                LEFT JOIN name_ko pk ON pk.object_id = i.item_id
                LEFT JOIN part_rarity_seen rs ON rs.item_id = i.item_id)
    ) AS j
  FROM weapon w0
  JOIN v_weapon_final w ON w.v = w0.v AND w.weapon_id = w0.weapon_id
  LEFT JOIN name_ko k ON k.object_id = w.weapon_id
  LEFT JOIN official_item og_item ON og_item.object_id = w.weapon_id
  LEFT JOIN price_global pgw ON pgw.object_id = w.weapon_id
  WHERE w0.v = vv
  ORDER BY w.weapon_id;
END $$

DELIMITER ;
