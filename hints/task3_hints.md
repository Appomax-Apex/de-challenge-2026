# Hints — Task 3: Gold Aggregation

## ถ้าไม่รู้จะ aggregate อย่างไร

### Hint Level 1 (Concept)

Gold table คือ **pre-computed metrics** ที่พร้อมใช้ใน dashboard โดยทั่วไป:
- Grain: 1 row = 1 asset + 1 hour (หรือ 1 shift)
- Columns: KPIs, counts, averages ที่คำนวณไว้แล้ว
- Joins: รวม reference data (machine name, shift label, rate config)

### Hint Level 2 (Production example)

```sql
-- Hourly production gold — key concept:
-- Group by ASSET + HOUR, then calculate metrics
SELECT
    ASSET,
    DATE_TRUNC('hour', CONVERT_TIMEZONE('UTC', 'Asia/Bangkok', EVENT_TS)) AS hour_local,
    -- Parts produced (use DELTA, not cumulative counter!)
    SUM(wo_part_counter_delta) AS parts_produced,
    -- Uptime calculation (state 800 = producing)
    COUNT_IF(n3_state_code = 800) AS producing_readings,
    COUNT(*) AS total_readings,
    producing_readings::FLOAT / NULLIF(total_readings, 0) AS uptime_pct,
    -- Top downtime reason (sub-status when state=803)
    MODE(CASE WHEN n3_state_code = 803 THEN n3_status_code END) AS top_downtime_status
FROM DE_CHALLENGE.SILVER.PRODUCTION_SILVER
GROUP BY 1, 2;
```

### Hint Level 3 (Common mistakes to avoid)

1. **อย่า AVG ค่าสะสม** — `total_import_active_energy` เป็น cumulative → ใช้ MAX-MIN
2. **อย่าลืม timezone** — DATE_TRUNC ตรงๆ จะได้ UTC hours → shift boundaries จะผิด
3. **อย่า COUNT(*) สำหรับ uptime** โดยไม่ filter state — ต้อง COUNT_IF(state=800)

### Hint Level 4 (Reference table example)

```sql
-- ตัวอย่าง shift definition table
CREATE TABLE DE_CHALLENGE.GOLD.SHIFT_DEFINITIONS (
    SHIFT_NAME VARCHAR,
    START_HOUR_LOCAL INTEGER,  -- 8, 16, 0
    END_HOUR_LOCAL INTEGER     -- 16, 24, 8
);

INSERT INTO DE_CHALLENGE.GOLD.SHIFT_DEFINITIONS VALUES
('Day', 8, 16),
('Evening', 16, 24),
('Night', 0, 8);
```

---

## ข้อควรระวัง (หักคะแนน: -2 ถ้าดู hints)
