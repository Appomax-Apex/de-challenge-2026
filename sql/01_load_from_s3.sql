-- ============================================================================
-- DE Challenge 2026 — Load Data from S3
-- รันไฟล์นี้หลังจาก 00_setup.sql เสร็จแล้ว
-- ============================================================================

USE WAREHOUSE CHALLENGE_WH;
USE DATABASE DE_CHALLENGE;
USE SCHEMA BRONZE;

-- 1. สร้าง File Format สำหรับ Parquet
CREATE OR REPLACE FILE FORMAT DE_CHALLENGE.BRONZE.PARQUET_FORMAT
    TYPE = PARQUET
    COMPRESSION = SNAPPY;

-- 2. สร้าง External Stage (public S3 bucket — ไม่ต้องใช้ credentials)
CREATE OR REPLACE STAGE DE_CHALLENGE.BRONZE.CHALLENGE_DATA
    URL = 's3://appomax-de-challenge/raw_events/'
    FILE_FORMAT = DE_CHALLENGE.BRONZE.PARQUET_FORMAT;

-- 3. ตรวจสอบว่าเห็นไฟล์ (ควรเห็น parquet files)
LIST @DE_CHALLENGE.BRONZE.CHALLENGE_DATA;

-- 4. โหลดข้อมูล Production (Schema Version 0.1) — ~25.3M rows
-- *** ใช้เวลาประมาณ 3-5 นาที ***
COPY INTO DE_CHALLENGE.BRONZE.RAW_EVENTS
FROM @DE_CHALLENGE.BRONZE.CHALLENGE_DATA/production/
FILE_FORMAT = DE_CHALLENGE.BRONZE.PARQUET_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- 5. โหลดข้อมูล Vibration v1 — ~574K rows
COPY INTO DE_CHALLENGE.BRONZE.RAW_EVENTS
FROM @DE_CHALLENGE.BRONZE.CHALLENGE_DATA/vibration_v1/
FILE_FORMAT = DE_CHALLENGE.BRONZE.PARQUET_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- 6. โหลดข้อมูล Vibration v2 — ~565K rows
COPY INTO DE_CHALLENGE.BRONZE.RAW_EVENTS
FROM @DE_CHALLENGE.BRONZE.CHALLENGE_DATA/vibration_v2/
FILE_FORMAT = DE_CHALLENGE.BRONZE.PARQUET_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- 7. โหลดข้อมูล Power Meter — ~299K rows
COPY INTO DE_CHALLENGE.BRONZE.RAW_EVENTS
FROM @DE_CHALLENGE.BRONZE.CHALLENGE_DATA/power_meter/
FILE_FORMAT = DE_CHALLENGE.BRONZE.PARQUET_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ============================================================================
-- ตรวจสอบผลลัพธ์
-- ============================================================================

-- ควรเห็น 4 rows แสดงจำนวนข้อมูลแต่ละ domain
SELECT
    SCHEMA_VERSION,
    COUNT(*) AS row_count,
    MIN(EVENT_TS) AS earliest_event,
    MAX(EVENT_TS) AS latest_event
FROM DE_CHALLENGE.BRONZE.RAW_EVENTS
GROUP BY SCHEMA_VERSION
ORDER BY row_count DESC;

-- ผลลัพธ์ที่คาดหวัง:
-- | SCHEMA_VERSION     | ROW_COUNT   | EARLIEST_EVENT      | LATEST_EVENT        |
-- |--------------------|-------------|---------------------|---------------------|
-- | 0.1                | ~25,333,789 | 2026-05-26 07:23:34 | 2026-06-20 03:02:28 |
-- | vibration.raw.v1   | ~573,762    | 2026-05-22 09:48:50 | 2026-06-11 04:58:06 |
-- | vibration.raw.v2   | ~564,724    | 2026-06-11 12:26:05 | 2026-06-20 03:02:25 |
-- | power_meter.raw.v1 | ~299,093    | 2026-05-22 10:17:00 | 2026-06-20 03:02:00 |

-- ============================================================================
-- โหลดข้อมูลเสร็จแล้ว! เริ่มทำโจทย์ใน challenge.md ได้เลย
-- ============================================================================
