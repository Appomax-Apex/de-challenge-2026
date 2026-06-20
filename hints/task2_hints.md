# Hints — Task 2: Silver Pipeline

## ถ้าไม่รู้จะเริ่มยังไงกับ incremental pipeline

### Hint Level 1 (Concept)

Incremental pipeline หมายถึง: ทุกครั้งที่รัน ให้ process **เฉพาะข้อมูลใหม่** ที่ยังไม่เคย process

วิธีที่นิยม 3 แบบ:
1. **Watermark** — จำ timestamp ล่าสุดที่ process ไปแล้ว → query เฉพาะ rows ที่ใหม่กว่านั้น
2. **Stream** — Snowflake track ให้ว่า rows ไหนยังไม่เคยถูกอ่าน
3. **Dynamic Table** — Snowflake จัดการ incremental ให้ทั้งหมด (declarative)

### Hint Level 2 (Watermark approach)

```sql
-- 1. สร้าง watermark table
CREATE TABLE DE_CHALLENGE.SILVER.TRANSFORM_WATERMARK (
    DOMAIN VARCHAR,
    LAST_PROCESSED_TS TIMESTAMP_TZ,
    UPDATED_AT TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
);

-- 2. ในการ transform แต่ละรอบ
-- query เฉพาะ rows ที่ INGESTED_TS > watermark
-- INSERT/MERGE เข้า silver table
-- UPDATE watermark เป็นค่าล่าสุด

-- 3. MERGE pattern (idempotent)
MERGE INTO DE_CHALLENGE.SILVER.MY_TABLE AS target
USING (SELECT ... FROM DE_CHALLENGE.BRONZE.RAW_EVENTS WHERE INGESTED_TS > :watermark) AS source
ON target.ASSET = source.ASSET AND target.EVENT_TS = source.EVENT_TS
WHEN NOT MATCHED THEN INSERT (...)
VALUES (...);
```

### Hint Level 3 (Dynamic Table approach)

```sql
-- Dynamic Table จัดการ incremental ให้อัตโนมัติ
CREATE OR REPLACE DYNAMIC TABLE DE_CHALLENGE.SILVER.VIBRATION_SILVER
    TARGET_LAG = '15 minutes'
    WAREHOUSE = CHALLENGE_WH
AS
SELECT
    EVENT_TS,
    ASSET,
    PAYLOAD:rotational_speed_rpm::FLOAT AS rotational_speed_rpm,
    PAYLOAD:temperature_c::FLOAT AS temperature_c,
    PAYLOAD:x_rms_velocity_mm_s::FLOAT AS x_rms_velocity_mm_s,
    -- ... more fields ...
    CASE
        WHEN PAYLOAD:rotational_speed_rpm::FLOAT > 100 THEN 'RUNNING'
        WHEN PAYLOAD:rotational_speed_rpm::FLOAT > 0 THEN 'STARTING'
        ELSE 'IDLE'
    END AS machine_state,
    CASE
        WHEN PAYLOAD:x_rms_velocity_mm_s::FLOAT > 11.2 THEN 'D'
        WHEN PAYLOAD:x_rms_velocity_mm_s::FLOAT > 4.5 THEN 'C'
        WHEN PAYLOAD:x_rms_velocity_mm_s::FLOAT > 1.8 THEN 'B'
        ELSE 'A'
    END AS iso_zone
FROM DE_CHALLENGE.BRONZE.RAW_EVENTS
WHERE SCHEMA_VERSION LIKE 'vibration.raw.%';
```

---

## ข้อควรระวัง (หักคะแนน: -2 ถ้าดู hints)
