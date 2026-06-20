# Data Dictionary

## ตาราง RAW_EVENTS (Bronze Layer)

### Column Reference

| Column | Type | คำอธิบาย |
|--------|------|----------|
| EVENT_TS | TIMESTAMP_TZ(9) | เวลาที่เหตุการณ์เกิดขึ้น (**UTC**) |
| ENTERPRISE | VARCHAR | ชื่อองค์กร (compomax) |
| SITE | VARCHAR | ชื่อ site (compomax_site) |
| AREA | VARCHAR | พื้นที่: Forming, air_chiller, control_room |
| WORK_CENTER | VARCHAR | กลุ่ม: Group1-4, chiller, electrical |
| WORK_CELL | VARCHAR | หน่วยย่อย (อาจเป็น NULL) |
| ASSET | VARCHAR | ชื่อ asset: FM22, motor_01, MAIN-MDB |
| ASSET_PATH | VARCHAR | Full topic path |
| NAMESPACE | VARCHAR | Partial path (ไม่รวม asset) |
| QUALITY | VARCHAR | GOOD หรือ BAD |
| PAYLOAD | VARIANT | JSON payload ที่แตกต่างตาม domain |
| INGESTED_TS | TIMESTAMP_TZ(9) | เวลาที่ข้อมูลเข้า Snowflake (UTC) |
| SCHEMA_VERSION | VARCHAR | Version ของ payload schema |
| SOURCE | VARCHAR | แหล่งข้อมูล (aws_iot_core) |
| CORRELATION_ID | VARCHAR | ID สำหรับ trace (มักว่าง) |

---

## Domain 1: Production (SCHEMA_VERSION = '0.1')

### ข้อมูลทั่วไป

- **Assets:** 38 Forming Machines (FM22, FM24, FM52, FM54, FM61, ...)
- **Groups:** Group1 (10 machines), Group2 (10), Group3 (8), Group4 (10)
- **Frequency:** ทุก 3 วินาที
- **ปริมาณ:** ~25.3 ล้าน rows

### Payload Fields

| Field | Type | ตัวอย่างค่า | คำอธิบาย |
|-------|------|------------|----------|
| connected | BOOLEAN | true | อุปกรณ์เชื่อมต่อ |
| counter | INTEGER | 15234 | Counter สะสม (ไม่ reset) |
| n3_state_code | INTEGER | 800 | State code หลัก (ดู State Codes ด้านล่าง) |
| n3_status_code | INTEGER | 800000 | Sub-status (6 หลัก: state + reason) |
| n3_reason_code | INTEGER | 0 | Reason code (ใช้ร่วมกับ state เพื่อระบุเหตุผล) |
| plan_id | STRING | "PL-2026-0145" | ID ของ production plan |
| qty_to_produce | INTEGER | 5000 | จำนวนที่ต้องผลิตตาม plan |
| source_period | INTEGER | 3000 | Reporting period (ms) |
| topic | STRING | "compomax/.../FM22" | Full MQTT topic |
| wo_cycle_time | FLOAT | 4.2 | Ideal cycle time (วินาที/ชิ้น) |
| wo_name | STRING | "WO-20260615-A" | Work order name |
| wo_operation_time | FLOAT | 28800 | Elapsed operation time (วินาที) |
| wo_part_counter | INTEGER | 1523 | Parts produced ใน WO นี้ |
| wo_part_counter_delta | INTEGER | 1 | Parts produced ตั้งแต่ reading ก่อนหน้า |
| wo_part_counter_no_reset | INTEGER | 45678 | Parts produced ไม่ reset |
| wo_part_name | STRING | "PART-A1234" | ชื่อชิ้นงาน |

### State Codes (Production Machine States)

| n3_state_code | ความหมาย | Treatment |
|---|---|---|
| 800 | **Running** — เครื่องกำลังผลิต | PRODUCTIVE |
| 801 | **Setup / Changeover** — กำลังเปลี่ยน die หรือตั้งค่า | PLANNED_STOP |
| 803 | **Stopped** — หยุดด้วยเหตุผลต่างๆ (ดู status_code) | ดู sub-reason |

### Status Codes (Sub-reason เมื่อ state=803)

| n3_status_code | ความหมาย | Treatment |
|---|---|---|
| 803105 | **No Order Assigned** — ไม่มี work order | EXCLUDED (ไม่ควรนับเป็น downtime) |
| 803101 | **Material Shortage** — รอวัตถุดิบ | UNPLANNED_DOWNTIME |
| 803112 | **Mechanical Fault** — เครื่องเสีย | UNPLANNED_DOWNTIME |
| 803102 | Unknown (TBD) — ยังไม่ confirm | UNPLANNED_DOWNTIME |
| 803103 | Unknown (TBD) | UNPLANNED_DOWNTIME |
| 803104 | Unknown (TBD) | UNPLANNED_DOWNTIME |
| 803111 | Unknown (TBD) | UNPLANNED_DOWNTIME |

> **หมายเหตุ:** สังเกตว่า state 803 reason 105 (No Order) คิดเป็นสัดส่วนใหญ่ของ "downtime" — ต้องตัดสินใจว่าจะรวมในการคำนวณ uptime หรือไม่

### Machine Categories

| Category | คำอธิบาย | ข้อควรระวัง |
|---|---|---|
| ACTIVE_PRODUCER | เครื่องที่ผลิตจริง | ใช้คำนวณ OEE ตามปกติ |
| IDLE_UNUSED | เครื่องที่ไม่เคยผลิต (counter=0 ตลอด) | ไม่ควรรวมในการคำนวณ throughput |
| ALWAYS_RUNNING | รายงาน state=800 แต่ counter ไม่เดิน | **ระวัง:** ดูเหมือนผลิตแต่ไม่ผลิตจริง |

---

## Domain 2: Vibration (SCHEMA_VERSION = 'vibration.raw.v1' / 'vibration.raw.v2')

### ข้อมูลทั่วไป

- **Assets:** 4 motors (motor_01 ถึง motor_04) บน chiller_01 ถึง chiller_04
- **Sensor:** Banner QM30VT2 tri-axial vibration sensor
- **Frequency:** ทุก 5-20 วินาที
- **ปริมาณ:** ~574K (v1) + ~565K (v2) = ~1.14 ล้าน rows

### Payload Fields หลัก (v1)

| Field | Type | Unit | คำอธิบาย |
|-------|------|------|----------|
| rotational_speed_rpm | FLOAT | RPM | ความเร็วรอบมอเตอร์ |
| rotational_speed_hz | FLOAT | Hz | ความเร็วรอบ (Hz) |
| temperature_c | FLOAT | °C | อุณหภูมิ bearing housing |
| x_rms_velocity_mm_s | FLOAT | mm/s | **ค่าหลักสำหรับ ISO assessment** |
| x_peak_acceleration_g | FLOAT | g | Peak vibration (impact detection) |
| x_high_frequency_rms_acceleration_g | FLOAT | g | High-freq component (bearing defects) |
| x_crest_factor | FLOAT | ratio | Peak/RMS (ค่า >6 = probable bearing damage) |
| x_kurtosis | FLOAT | - | Statistical shape (ค่า >5 = impulsive vibration) |
| z_rms_velocity_mm_s | FLOAT | mm/s | Same metrics สำหรับ Z-axis |
| z_peak_acceleration_g | FLOAT | g | |
| device_available | BOOLEAN | - | Sensor online |
| device_error | BOOLEAN | - | Sensor error flag |

### การตีความ Motor State

| Condition | Interpretation |
|-----------|---------------|
| rotational_speed_rpm > 100 | RUNNING |
| rotational_speed_rpm > 0 AND <= 100 | STARTING/STOPPING |
| rotational_speed_rpm = 0 | IDLE/STANDBY |
| device_available = false | OFFLINE |

---

## Domain 3: Power Meter (SCHEMA_VERSION = 'power_meter.raw.v1')

### ข้อมูลทั่วไป

- **Assets:** 8 meters (MAIN-MDB, PM-F1 ถึง PM-F7)
- **MAIN-MDB:** Main Distribution Board (รวมทั้งโรงงาน)
- **PM-Fx:** Sub-meter ตามชั้น (Floor 1-7)
- **Frequency:** ทุก 60 วินาที
- **ปริมาณ:** ~299K rows

### Payload Fields

| Field | Type | Unit | คำอธิบาย |
|-------|------|------|----------|
| device_id | STRING | - | ID ของ meter |
| floor | STRING | - | ชั้นโรงงาน |
| eq_active_power | FLOAT | kW | Active power ปัจจุบัน |
| eq_apparent_power | FLOAT | kVA | Apparent power |
| eq_reactive_power | FLOAT | kVAr | Reactive power |
| eq_current | FLOAT | A | Total current |
| eq_power_factor | FLOAT | 0-1 | Power factor |
| eq_phase_to_phase_voltage | FLOAT | V | Line-to-line voltage |
| eq_phase_v | FLOAT | V | Phase voltage |
| frequency | FLOAT | Hz | Grid frequency (~50 Hz) |
| l1_current | FLOAT | A | Phase L1 current |
| l2_current | FLOAT | A | Phase L2 current |
| l3_current | FLOAT | A | Phase L3 current |
| l1_phase_v | FLOAT | V | Phase L1 voltage |
| l1_current_thd | FLOAT | % | L1 current THD |
| l1_voltage_thd | FLOAT | % | L1 voltage THD |
| total_import_active_energy | FLOAT | kWh | Cumulative energy (kWh สะสม) |
| total_import_reactive_energy | FLOAT | kVArh | Cumulative reactive energy |
| total_apparent_energy | FLOAT | kVAh | Cumulative apparent energy |

### การคำนวณ Energy Consumption

`total_import_active_energy` เป็นค่าสะสม (monotonically increasing) การคำนวณ consumption ต่อชั่วโมงทำได้โดย:

```sql
energy_kwh = MAX(total_import_active_energy) - MIN(total_import_active_energy)
-- within each hour, per device
```

### Meter Hierarchy

```
MAIN-MDB (Main Distribution Board)
  ├── PM-F1 (Floor 1)
  ├── PM-F2 (Floor 2)
  ├── PM-F3 (Floor 3)
  ├── PM-F4 (Floor 4)
  ├── PM-F5 (Floor 5)
  ├── PM-F6 (Floor 6)
  └── PM-F7 (Floor 7)
```

> **หมายเหตุ:** ผลรวมของ PM-F1 ถึง PM-F7 ควรใกล้เคียง MAIN-MDB — ถ้าไม่ตรง อาจมี unmeasured loads

---

## ข้อควรระวัง (Data Quality Notes)

1. **Timezone:** `EVENT_TS` เป็น UTC — โรงงานอยู่ GMT+7 (Asia/Bangkok)
2. **QUALITY = BAD:** มีอยู่จริงในข้อมูล — ต้องตัดสินใจว่าจะ filter หรือ flag
3. **NULL values:** `WORK_CELL` เป็น NULL สำหรับ Production domain — นี่ไม่ใช่ bug, โรงงาน group machines ตาม WORK_CENTER โดยตรง
4. **Schema evolution:** Vibration data เปลี่ยนจาก v1 → v2 กลางทาง
5. **Cumulative counters:** `total_import_active_energy` และ `wo_part_counter_no_reset` เป็นค่าสะสม — ต้อง diff เพื่อได้ค่า per-period
6. **Duplicates:** อาจมี rows ที่มี EVENT_TS เดียวกันจาก delivery retry — pipeline ควร handle ได้
