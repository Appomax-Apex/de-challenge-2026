-- ============================================================================
-- DE Challenge 2026 — Initial Setup
-- รันไฟล์นี้ก่อนเริ่มทำโจทย์
-- ============================================================================

-- 1. สร้าง Database
CREATE OR REPLACE DATABASE DE_CHALLENGE
    COMMENT = 'Data Engineering Challenge 2026 — Shop Floor to Insight';

-- 2. สร้าง Schemas (Medallion Architecture)
CREATE SCHEMA IF NOT EXISTS DE_CHALLENGE.BRONZE
    COMMENT = 'Raw data layer — ห้ามแก้ไขข้อมูลในนี้';

CREATE SCHEMA IF NOT EXISTS DE_CHALLENGE.SILVER
    COMMENT = 'Cleaned and typed data — ทำงานใน schema นี้';

CREATE SCHEMA IF NOT EXISTS DE_CHALLENGE.GOLD
    COMMENT = 'Business metrics and aggregations — ทำงานใน schema นี้';

-- 3. สร้าง Warehouse (XS เพียงพอสำหรับ trial account)
CREATE WAREHOUSE IF NOT EXISTS CHALLENGE_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse สำหรับ DE Challenge — auto suspend 60 วินาที';

-- 4. ตั้งค่า context
USE WAREHOUSE CHALLENGE_WH;
USE DATABASE DE_CHALLENGE;
USE SCHEMA BRONZE;

-- 5. สร้างตาราง RAW_EVENTS (Bronze)
CREATE OR REPLACE TABLE DE_CHALLENGE.BRONZE.RAW_EVENTS (
    EVENT_TS            TIMESTAMP_NTZ,      -- UTC (ต้อง +7 ชม. เพื่อได้เวลาไทย)
    ENTERPRISE          VARCHAR,
    SITE                VARCHAR,
    AREA                VARCHAR,
    WORK_CENTER         VARCHAR,
    WORK_CELL           VARCHAR,
    ASSET               VARCHAR,
    ASSET_PATH          VARCHAR,
    NAMESPACE           VARCHAR,
    QUALITY             VARCHAR,
    PAYLOAD             VARIANT,
    INGESTED_TS         TIMESTAMP_NTZ,      -- UTC
    SCHEMA_VERSION      VARCHAR,
    SOURCE              VARCHAR,
    CORRELATION_ID      VARCHAR
)
COMMENT = 'Unified Namespace raw events — ข้อมูลดิบจากทุก sensor (timestamps เป็น UTC)';

-- ============================================================================
-- Setup เสร็จสิ้น! ขั้นตอนต่อไป: รัน 01_load_from_s3.sql เพื่อโหลดข้อมูล
-- ============================================================================
