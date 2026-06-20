# Hints — Task 1: Data Understanding & Schema Design

## ถ้าไม่รู้จะเริ่มยังไง

### Hint Level 1 (ลอง query เหล่านี้)

```sql
-- ดูว่ามี SCHEMA_VERSION อะไรบ้าง
SELECT SCHEMA_VERSION, COUNT(*) FROM DE_CHALLENGE.BRONZE.RAW_EVENTS
GROUP BY SCHEMA_VERSION;

-- ดูว่าแต่ละ domain มี AREA/WORK_CENTER อะไร
SELECT SCHEMA_VERSION, AREA, WORK_CENTER, COUNT(DISTINCT ASSET) as assets
FROM DE_CHALLENGE.BRONZE.RAW_EVENTS
GROUP BY 1, 2, 3;
```

### Hint Level 2 (วิธีดู payload structure)

```sql
-- ดู keys ใน payload ของแต่ละ domain
SELECT SCHEMA_VERSION, OBJECT_KEYS(PAYLOAD) as keys
FROM DE_CHALLENGE.BRONZE.RAW_EVENTS
WHERE SCHEMA_VERSION = 'power_meter.raw.v1'
LIMIT 1;

-- ดูค่าจริงใน payload
SELECT PAYLOAD:eq_active_power::FLOAT as active_power_kw,
       PAYLOAD:eq_power_factor::FLOAT as power_factor
FROM DE_CHALLENGE.BRONZE.RAW_EVENTS
WHERE SCHEMA_VERSION = 'power_meter.raw.v1'
LIMIT 5;
```

### Hint Level 3 (ถ้ายังไม่แน่ใจ schema design)

คิดแบบนี้: สำหรับแต่ละ domain ถามตัวเองว่า:
1. **Primary key คืออะไร?** → มักจะเป็น (ASSET + EVENT_TS)
2. **VARIANT fields ไหนที่ต้อง extract?** → ดูจาก OBJECT_KEYS
3. **Data type อะไรเหมาะกับแต่ละ field?** → NUMBER สำหรับ sensor values, BOOLEAN สำหรับ flags
4. **ต้อง enrich อะไรบ้าง?** → State labels, time-based flags

---

## ข้อควรระวัง (หักคะแนน: -2 ถ้าดู hints)

การดู hints จะถูกบันทึกและหักคะแนน 2 คะแนนต่อ task ที่ดู hint
