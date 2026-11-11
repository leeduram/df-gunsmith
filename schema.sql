-- Delta Force gunsmith DB schema (MySQL 8.0+ / 9.x)
-- Safe to run multiple times.
SET NAMES utf8mb4;

-- ---------- raw downloads ----------
CREATE TABLE IF NOT EXISTS raw_doc (
  id         BIGINT AUTO_INCREMENT PRIMARY KEY,
  run_id     VARCHAR(20)  NOT NULL,            -- collector run, yyyyMMdd-HHmmss
  source     VARCHAR(16)  NOT NULL,            -- dfttk / official / steam
  kind       VARCHAR(16)  NOT NULL,            -- manifest, items, sockets, weapon, gun, acc, news
  ref_id     VARCHAR(32)  NOT NULL DEFAULT '', -- weapon id for kind=weapon
  body       JSON         NOT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY k_run (run_id, source, kind)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- versions & which version each server shows ----------
CREATE TABLE IF NOT EXISTS dfttk_version (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  data_version   VARCHAR(64) NOT NULL UNIQUE,  -- e.g. 20261105-weiguang.1
  effective_date DATE        NULL,             -- China patch date (from the yyyymmdd prefix)
  run_id         VARCHAR(20) NOT NULL,
  first_seen     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  global_since   DATETIME    NULL              -- set when the global server is detected as updated to this version
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS server_state (
  server           VARCHAR(8)   PRIMARY KEY,   -- cn / global
  dfttk_version_id INT          NULL,
  mode             VARCHAR(8)   NOT NULL DEFAULT 'auto',  -- auto / manual (manual = never changed by the collector)
  updated_at       DATETIME     NULL,
  note             VARCHAR(255) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT IGNORE INTO server_state (server) VALUES ('cn'), ('global');

-- global update signals (Steam client build change / Steam official announcement)
CREATE TABLE IF NOT EXISTS global_signal (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  kind        VARCHAR(16)  NOT NULL,           -- build / announcement
  value       VARCHAR(255) NOT NULL,           -- build number or news gid
  detail      VARCHAR(500) NULL,               -- news title
  detected_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY u_kind_value (kind, value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- game data per dfttk version (v = dfttk_version.id) ----------
CREATE TABLE IF NOT EXISTS weapon (
  v              INT         NOT NULL,
  weapon_id      VARCHAR(32) NOT NULL,
  name_zh        VARCHAR(100) NULL,
  category       VARCHAR(32) NULL,
  image          VARCHAR(255) NULL,
  attr_range     DECIMAL(8,2) NULL,  -- 최적 사거리
  attr_recoil    DECIMAL(8,2) NULL,  -- 반동 제어
  attr_hip       DECIMAL(8,2) NULL,  -- 지향사격 정밀도
  attr_handling  DECIMAL(8,2) NULL,  -- 조작 속도
  attr_stability DECIMAL(8,2) NULL,  -- 안정성
  PRIMARY KEY (v, weapon_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS part (
  v                 INT          NOT NULL,
  item_id           VARCHAR(32)  NOT NULL,
  name_zh           VARCHAR(100) NULL,
  category          VARCHAR(32)  NULL,
  rarity            VARCHAR(8)   NULL,
  image             VARCHAR(255) NULL,
  player_selectable TINYINT(1)   NOT NULL DEFAULT 0,
  PRIMARY KEY (v, item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS socket_name (
  v         INT         NOT NULL,
  socket_id INT         NOT NULL,
  name_zh   VARCHAR(64) NULL,
  PRIMARY KEY (v, socket_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- which items can go into which socket (owner = the weapon itself or a part that provides sockets)
CREATE TABLE IF NOT EXISTS socket_option (
  v             INT         NOT NULL,
  weapon_id     VARCHAR(32) NOT NULL,
  owner_item_id VARCHAR(32) NOT NULL,
  socket_id     INT         NOT NULL,
  item_id       VARCHAR(32) NOT NULL,
  PRIMARY KEY (v, weapon_id, owner_item_id, socket_id, item_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- default / forced mounts (condition_type always or anyMounted)
CREATE TABLE IF NOT EXISTS default_mount (
  v               INT          NOT NULL,
  weapon_id       VARCHAR(32)  NOT NULL,
  rule_no         INT          NOT NULL,
  socket_id       INT          NOT NULL,
  item_id         VARCHAR(32)  NOT NULL,
  policy          VARCHAR(16)  NULL,       -- default / forced
  condition_type  VARCHAR(16)  NULL,       -- always / anyMounted
  condition_items JSON         NULL,
  PRIMARY KEY (v, weapon_id, rule_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- a part that also blocks other sockets
CREATE TABLE IF NOT EXISTS extra_occupancy (
  v         INT         NOT NULL,
  weapon_id VARCHAR(32) NOT NULL,
  item_id   VARCHAR(32) NOT NULL,
  socket_id INT         NOT NULL,
  PRIMARY KEY (v, weapon_id, item_id, socket_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- all Hazard Operations (sol) effects of each part on each weapon
CREATE TABLE IF NOT EXISTS part_effect (
  v         INT          NOT NULL,
  weapon_id VARCHAR(32)  NOT NULL,
  item_id   VARCHAR(32)  NOT NULL,
  seq       INT          NOT NULL,
  target    VARCHAR(100) NOT NULL,
  modifier  VARCHAR(32)  NULL,
  value     DOUBLE       NULL,
  scope     VARCHAR(32)  NULL,          -- NONE = always; TacticalEffective = only while laser/light is on
  PRIMARY KEY (v, weapon_id, item_id, seq),
  KEY k_target (v, target)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- Tencent official (current values + price history) ----------
CREATE TABLE IF NOT EXISTS official_item (
  object_id         VARCHAR(32)  PRIMARY KEY,
  primary_class     VARCHAR(16)  NULL,
  second_class      VARCHAR(32)  NULL,
  name_zh           VARCHAR(100) NULL,
  grade             INT          NULL,
  weight            DECIMAL(8,3) NULL,
  length            INT          NULL,
  width             INT          NULL,
  avg_price         BIGINT       NULL,
  price_change_rate DECIMAL(10,2) NULL,
  pic               VARCHAR(255) NULL,
  pre_pic           VARCHAR(255) NULL,
  updated_at        DATETIME     NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS official_gun (
  object_id       VARCHAR(32)  PRIMARY KEY,
  meat_harm       INT NULL,  -- 기본 대미지
  armor_harm      INT NULL,  -- 아머 관통
  shoot_distance  INT NULL,  -- 최적 사거리
  recoil          INT NULL,
  control_speed   INT NULL,
  stable          INT NULL,
  hip_shot        INT NULL,
  fire_speed      INT NULL,  -- 발사 속도
  capacity        INT NULL,  -- 용량
  fire_mode       VARCHAR(64) NULL,
  muzzle_velocity INT NULL,  -- 포구 속도
  sound_distance  INT NULL,  -- 총성 전파 거리
  caliber         VARCHAR(32) NULL,
  updated_at      DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS price_history (
  object_id VARCHAR(32) NOT NULL,
  run_id    VARCHAR(20) NOT NULL,
  avg_price BIGINT      NULL,
  PRIMARY KEY (object_id, run_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Korean names (filled by hand)
CREATE TABLE IF NOT EXISTS name_ko (
  object_id  VARCHAR(32)  PRIMARY KEY,
  name_ko    VARCHAR(100) NOT NULL,
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Korean/English names by Chinese name (seeded by names_seed.sql; edit freely, mark checked ones 'verified')
CREATE TABLE IF NOT EXISTS name_i18n (
  name_zh    VARCHAR(100) COLLATE utf8mb4_bin PRIMARY KEY,
  name_ko    VARCHAR(150) NOT NULL,
  name_en    VARCHAR(150) NOT NULL,
  source     ENUM('verified','draft') NOT NULL DEFAULT 'draft',
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- grade colour as seen in the game, for parts where the data disagrees or has none (seeded by names_seed.sql)
CREATE TABLE IF NOT EXISTS part_rarity_seen (
  item_id  VARCHAR(32) PRIMARY KEY,
  rarity   VARCHAR(4)  NOT NULL,   -- 白 绿 蓝 紫 金 红
  seen_on  DATE        NOT NULL,
  note     VARCHAR(100) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- parts hidden from the site (event / limited-time parts that are not sold in the market)
CREATE TABLE IF NOT EXISTS part_hidden (
  item_id VARCHAR(32) PRIMARY KEY,
  note    VARCHAR(100) NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- weapon titles as shown in the game (Korean), seeded by names_seed.sql
CREATE TABLE IF NOT EXISTS weapon_title (
  weapon_id VARCHAR(32) PRIMARY KEY,
  title_ko  VARCHAR(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- display helpers ----------
-- in-game displayed effect of a part on a weapon (always-on effects only, laser/light off).
-- 최적 사거리: range_initial replaces the base value, range_add adds meters, range_mult_pct is a % increase
--   (also applies to 포구 속도). Others are +/- points. mag_initial sets the capacity, mag_add adds to it.
CREATE OR REPLACE VIEW v_part_display AS
SELECT v, weapon_id, item_id,
  MAX(CASE WHEN target = 'DisplayAttrValues.2' AND modifier = 'Initial' THEN value END)               AS range_initial,
  SUM(CASE WHEN target = 'DisplayAttrValues.2' AND modifier = 'Addend'  THEN value ELSE 0 END)        AS range_add,
  ROUND(100 * SUM(CASE WHEN target = 'DisplayAttrValues.2' AND modifier = 'Mult_A' THEN value ELSE 0 END), 2) AS range_mult_pct,
  SUM(CASE WHEN target = 'DisplayAttrValues.3' THEN value ELSE 0 END) AS recoil,
  SUM(CASE WHEN target = 'DisplayAttrValues.4' THEN value ELSE 0 END) AS hip,
  SUM(CASE WHEN target = 'DisplayAttrValues.5' THEN value ELSE 0 END) AS handling,
  SUM(CASE WHEN target = 'DisplayAttrValues.6' THEN value ELSE 0 END) AS stability,
  MAX(CASE WHEN target = 'GMagCapacity' AND modifier = 'Initial' THEN value END)                      AS mag_initial,
  SUM(CASE WHEN target = 'GMagCapacity' AND modifier = 'Addend'  THEN value ELSE 0 END)               AS mag_add,
  ROUND(100 * SUM(CASE WHEN target = 'GRateOfFire' AND modifier = 'Mult_A' THEN value ELSE 0 END), 2)  AS rof_pct
FROM part_effect
WHERE scope = 'NONE' AND (target LIKE 'DisplayAttrValues.%' OR target IN ('GMagCapacity', 'GRateOfFire'))
GROUP BY v, weapon_id, item_id;

-- ---------- columns added later (kept safe to run on an existing database) ----------
DROP PROCEDURE IF EXISTS sp_add_col;
DELIMITER $$
CREATE PROCEDURE sp_add_col(IN t VARCHAR(64), IN c VARCHAR(64), IN d VARCHAR(255))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema = DATABASE() AND table_name = t AND column_name = c) THEN
    SET @ddl = CONCAT('ALTER TABLE ', t, ' ADD COLUMN ', c, ' ', d);
    PREPARE st FROM @ddl; EXECUTE st; DEALLOCATE PREPARE st;
  END IF;
END $$
DELIMITER ;
-- weapon stats from the dfttk weapon catalog / weapon packs
CALL sp_add_col('weapon', 'dmg',        'INT NULL');   -- 기본 대미지
CALL sp_add_col('weapon', 'armor_dmg',  'INT NULL');   -- 아머 관통
CALL sp_add_col('weapon', 'rpm',        'INT NULL');   -- 발사 속도
CALL sp_add_col('weapon', 'fire_modes', 'JSON NULL');  -- ["Auto","Single",...]
CALL sp_add_col('weapon', 'velocity',   'INT NULL');   -- 포구 속도 m/s
CALL sp_add_col('weapon', 'sound',      'INT NULL');   -- 총성 전파 거리 m
CALL sp_add_col('weapon', 'clip',       'INT NULL');   -- 용량 (used when no default magazine sets it)
DROP PROCEDURE IF EXISTS sp_add_col;

-- global market prices (no feed for the global server: seeded from in-game market recordings,
-- later possibly from other sources). Newest observation wins.
CREATE TABLE IF NOT EXISTS price_global (
  object_id   VARCHAR(32) PRIMARY KEY,
  price       BIGINT      NOT NULL,
  source      VARCHAR(16) NOT NULL,   -- 'video' = read from a market recording
  observed_at DATETIME    NOT NULL,   -- when the price was on screen (KST)
  updated_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- deltaforcetools.gg global market (fetched once a day). Its items have no game ids,
-- so each of its items is matched to ours once and the match is kept here.
CREATE TABLE IF NOT EXISTS dft_map (
  en_key    VARCHAR(255) COLLATE utf8mb4_bin PRIMARY KEY,  -- its item key, e.g. 'ATTACHMENT-OPS Suppressor'
  object_id VARCHAR(32)  NOT NULL,
  method    VARCHAR(16)  NOT NULL,                         -- name / alias / video / manual
  mapped_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- names that are worded differently on that site (its Traditional name converted to Simplified -> our Chinese name)
CREATE TABLE IF NOT EXISTS dft_alias (
  dft_name VARCHAR(255) COLLATE utf8mb4_bin PRIMARY KEY,
  name_zh  VARCHAR(255) COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
-- items of that site that could not be matched in the last fetch (to check by hand)
CREATE TABLE IF NOT EXISTS dft_unmapped (
  en_key  VARCHAR(255) COLLATE utf8mb4_bin PRIMARY KEY,
  name_en VARCHAR(255) NULL,
  name_s  VARCHAR(255) NULL,
  price   BIGINT       NULL,
  seen_at DATETIME     NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO dft_alias (dft_name, name_zh) VALUES
('共振人体工学握把','共振人体工程握把'),('霰弹枪涡流喉缩','霰弹枪涡流收束器'),('AKM 40发延长匣','AKM延长匣40发'),
('野牛攻击者标准枪管','野牛打击者标准枪管'),('俄式准直仪二倍瞄准镜','俄式准直二倍瞄准镜'),('Vector 30发扩充弹匣','Vector扩容30发弹匣'),
('S12K 24发扩充弹鼓','S12K扩容24发弹鼓'),('AK12 30发聚合物弹匣','AK12聚合物30发弹匣'),('S12K 10发扩充弹匣','S12K扩容10发弹匣'),
('Cobra准直仪瞄准镜','Cobra准直式瞄准镜'),('AKM 70发大弹鼓','AKM大弹鼓70发'),('霰弹枪回音消音器','霰弹枪回声消音器'),
('实用霰弹喉缩','实用霰弹收束器'),('M4 60发弹鼓','M4弹鼓60发'),('AKS-74U 75发聚合物弹鼓','AKS-74U聚合物弹鼓75发'),
('LPVO高倍率战斗瞄准器','LPVO多倍率战斗瞄具'),('AKS-74U 45发延长弹匣','AKS-74U延长弹匣45发'),('微型瞄准器增高架','微型瞄具增高架'),
-- by its item key (no Chinese name on the site for these)
('ATTACHMENT-AK Bolt Cover','AK枪托尾盖'),('ATTACHMENT-PKM Bolt Cover','PKM枪托尾盖'),('ATTACHMENT-SCAR-H Bolt Cover','SCAR-H枪托尾盖'),
('ATTACHMENT-UZI Bolt Cover','UZI枪托尾盖'),('WEAPON-G18','G18'),('WEAPON-CI-19 Assault Rifle','腾龙'),('WEAPON-SR-3M Compact Assault Rifle','SR-3M')
AS a ON DUPLICATE KEY UPDATE name_zh = a.name_zh;
-- official English names from deltaforcetools (its English list, matched through dft_map). Shown instead of the drafts.
CREATE TABLE IF NOT EXISTS name_en_official (
  name_zh    VARCHAR(100) COLLATE utf8mb4_bin PRIMARY KEY,
  name_en    VARCHAR(255) NOT NULL,
  source     VARCHAR(16)  NOT NULL DEFAULT 'dft',
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------- season changes: dfttk game data + Tencent official numbers ----------
-- Starting point = last season's official numbers (official_baseline, taken when a new dfttk version arrives,
-- before the patch). After the patch, whichever source moved away from that starting point has the update:
--   official did not change -> dfttk (it may carry a change the official list does not show)
--   official changed        -> official (also when dfttk differs: checked in game on the global S11 client,
--                              dfttk had the S11 numbers - VSS 엘리트 일체형 개머리판 조작 속도 -6, 시크릿 베벨 그립
--                              반동 제어 +9 - while official had them wrong or missing before and changed them in S12)
-- Only for the version that is live on the China server today (official numbers are China's current ones).
CREATE TABLE IF NOT EXISTS official_stat (
  object_id  VARCHAR(32) PRIMARY KEY,
  kind       VARCHAR(8)  NOT NULL,   -- gun / acc
  recoil     INT NULL,               -- 반동 제어
  hip        INT NULL,               -- 지향사격 정밀도
  handling   INT NULL,               -- 조작 속도
  stability  INT NULL,               -- 안정성
  range_pct  INT NULL,               -- acc: 최적 사거리 %
  range_m    INT NULL,               -- gun: 최적 사거리 m
  dmg        INT NULL,
  armor      INT NULL,
  rpm        INT NULL,
  capacity   INT NULL,
  velocity   INT NULL,
  sound      INT NULL,
  updated_at DATETIME NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS official_baseline (
  v          INT         NOT NULL,   -- dfttk version this starting point belongs to
  object_id  VARCHAR(32) NOT NULL,
  kind       VARCHAR(8)  NOT NULL,
  recoil     INT NULL, hip INT NULL, handling INT NULL, stability INT NULL, range_pct INT NULL, range_m INT NULL,
  dmg        INT NULL, armor INT NULL, rpm INT NULL, capacity INT NULL, velocity INT NULL, sound INT NULL,
  taken_at   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (v, object_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- the dfttk version live on the China server today
CREATE OR REPLACE VIEW v_live_version AS
SELECT id AS v FROM dfttk_version WHERE effective_date <= CURDATE() ORDER BY effective_date DESC, id DESC LIMIT 1;

-- part effects after the season merge (same columns as v_part_display)
CREATE OR REPLACE VIEW v_part_final AS
SELECT d.v, d.weapon_id, d.item_id, d.range_initial, d.range_add,
  -- 최적 사거리: only when dfttk also gives it as a % (not as meters added or a fixed range)
  CASE WHEN o.range_pct <> b.range_pct AND d.range_initial IS NULL AND d.range_add = 0
            AND ABS(d.range_mult_pct - b.range_pct) < 0.5 THEN o.range_pct ELSE d.range_mult_pct END AS range_mult_pct,
  CASE WHEN o.recoil    <> b.recoil    THEN o.recoil    ELSE d.recoil    END AS recoil,
  CASE WHEN o.hip       <> b.hip       THEN o.hip       ELSE d.hip       END AS hip,
  CASE WHEN o.handling  <> b.handling  THEN o.handling  ELSE d.handling  END AS handling,
  CASE WHEN o.stability <> b.stability THEN o.stability ELSE d.stability END AS stability,
  -- a gun whose capacity changed: its default magazine sets the new capacity
  CASE WHEN og.capacity <> bg.capacity AND d.mag_initial = bg.capacity
            AND EXISTS (SELECT 1 FROM default_mount dm WHERE dm.v = d.v AND dm.weapon_id = d.weapon_id
                          AND dm.item_id = d.item_id AND dm.condition_type = 'always')
       THEN og.capacity ELSE d.mag_initial END AS mag_initial,
  d.mag_add, d.rof_pct
FROM v_part_display d
LEFT JOIN v_live_version lv ON lv.v = d.v
LEFT JOIN official_baseline b  ON lv.v IS NOT NULL AND b.v = d.v AND b.object_id = d.item_id AND b.kind = 'acc'
LEFT JOIN official_stat o      ON lv.v IS NOT NULL AND o.object_id = d.item_id AND o.kind = 'acc'
LEFT JOIN official_baseline bg ON lv.v IS NOT NULL AND bg.v = d.v AND bg.object_id = d.weapon_id AND bg.kind = 'gun'
LEFT JOIN official_stat og     ON lv.v IS NOT NULL AND og.object_id = d.weapon_id AND og.kind = 'gun';

-- weapon base numbers after the season merge; a number dfttk does not have (empty or 0) comes from official
CREATE OR REPLACE VIEW v_weapon_final AS
SELECT w.v, w.weapon_id, w.fire_modes,
  CASE WHEN w.dmg IS NULL OR w.dmg = 0 THEN o.dmg WHEN o.dmg <> b.dmg THEN o.dmg ELSE w.dmg END AS dmg,
  CASE WHEN w.armor_dmg IS NULL OR w.armor_dmg = 0 THEN o.armor WHEN o.armor <> b.armor THEN o.armor ELSE w.armor_dmg END AS armor_dmg,
  CASE WHEN w.rpm IS NULL OR w.rpm = 0 THEN o.rpm WHEN o.rpm <> b.rpm THEN o.rpm ELSE w.rpm END AS rpm,
  CASE WHEN w.clip IS NULL OR w.clip = 0 THEN o.capacity WHEN o.capacity <> b.capacity THEN o.capacity ELSE w.clip END AS clip,
  CASE WHEN w.velocity IS NULL OR w.velocity = 0 THEN o.velocity WHEN o.velocity <> b.velocity THEN o.velocity ELSE w.velocity END AS velocity,
  CASE WHEN w.sound IS NULL OR w.sound = 0 THEN o.sound WHEN o.sound <> b.sound THEN o.sound ELSE w.sound END AS sound,
  CASE WHEN o.range_m <> b.range_m THEN o.range_m   ELSE w.attr_range     END AS attr_range,
  CASE WHEN o.recoil <> b.recoil THEN o.recoil    ELSE w.attr_recoil    END AS attr_recoil,
  CASE WHEN o.hip <> b.hip THEN o.hip       ELSE w.attr_hip       END AS attr_hip,
  CASE WHEN o.handling <> b.handling THEN o.handling  ELSE w.attr_handling  END AS attr_handling,
  CASE WHEN o.stability <> b.stability THEN o.stability ELSE w.attr_stability END AS attr_stability
FROM weapon w
LEFT JOIN v_live_version lv ON lv.v = w.v
LEFT JOIN official_stat o     ON o.object_id = w.weapon_id AND o.kind = 'gun'
LEFT JOIN official_baseline b ON lv.v IS NOT NULL AND b.v = w.v AND b.object_id = w.weapon_id AND b.kind = 'gun';
