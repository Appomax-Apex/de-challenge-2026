# Unified Namespace (UNS) Schema Reference

## UNS คืออะไร?

Unified Namespace (UNS) คือสถาปัตยกรรมข้อมูลที่รวม **ทุก data source** ในโรงงานเข้าไว้ใน hierarchy เดียว โดยใช้ topic-based addressing คล้าย MQTT ข้อมูลทุกประเภทไม่ว่าจะเป็น sensor, PLC, หรือ system ใดๆ จะถูก flatten ลงใน schema เดียวกัน

## Hierarchy Structure

ข้อมูลใน `RAW_EVENTS` ถูกจัดระดับตาม ISA-95 hierarchy:

```
ENTERPRISE / SITE / AREA / WORK_CENTER / WORK_CELL / ASSET
    │          │      │         │            │          │
    ▼          ▼      ▼         ▼            ▼          ▼
 compomax  compomax  area    work_center   cell     specific
            _site                                    device
```

### ตัวอย่างจริงจากข้อมูล

| Level | Production Domain | Vibration Domain | Power Domain |
|-------|------------------|-----------------|--------------|
| ENTERPRISE | compomax | compomax | compomax |
| SITE | compomax_site | compomax_site | compomax_site |
| AREA | Forming | air_chiller | control_room |
| WORK_CENTER | Group1/2/3/4 | chiller | electrical |
| WORK_CELL | _(null)_ | chiller_01..04 | power_meter |
| ASSET | FM22, FM52, FM61... | motor_01..04 | MAIN-MDB, PM-F1..F7 |

## ASSET_PATH

Column `ASSET_PATH` คือ full path ของ device ในรูปแบบ topic-style:

```
compomax/compomax_site/Forming/Group1/FM22
compomax/compomax_site/air_chiller/chiller_01/motor_01/vibration_1
compomax/compomax_site/control_room/electrical/power_meter/MAIN-MDB
```

## Schema Versions

### `0.1` — Production / Forming Machines

**Source:** PLC ผ่าน Advantech Edge Gateway
**จำนวน:** ~25.3 ล้าน rows
**Frequency:** ทุก 3 วินาที (state) + ทุก 60 วินาที (summary)

**Payload keys:**
```
connected, counter, n3_reason_code, n3_state_code, n3_status_code,
plan_id, qty_to_produce, source_period, topic, wo_cycle_time,
wo_name, wo_operation_time, wo_part_counter, wo_part_counter_delta,
wo_part_counter_no_reset, wo_part_name
```

**Key fields:**
| Field | Type | คำอธิบาย |
|-------|------|----------|
| n3_state_code | INTEGER | สถานะเครื่อง: 1=Producing, 2=Idle, 3=Planned DT, 4=Unplanned DT, 5=Setup, 6=Maintenance |
| n3_status_code | INTEGER | Sub-status ภายใน state |
| n3_reason_code | INTEGER | เหตุผลของ downtime (map กับ reason code lookup) |
| wo_part_counter | INTEGER | จำนวนชิ้นงานสะสม (reset ทุก work order) |
| wo_part_counter_delta | INTEGER | จำนวนชิ้นที่ผลิตตั้งแต่ reading ก่อนหน้า |
| wo_name | STRING | Work order name ปัจจุบัน |
| wo_cycle_time | FLOAT | เวลา cycle ต่อชิ้น (วินาที) |
| source_period | INTEGER | ความถี่ในการส่งข้อมูล (ms) |
| connected | BOOLEAN | อุปกรณ์เชื่อมต่ออยู่หรือไม่ |

---

### `vibration.raw.v1` — Chiller Motor Vibration (ข้อมูลเก่า)

**Source:** Banner QM30VT2 vibration sensors
**จำนวน:** ~574,000 rows
**ช่วงเวลา:** 2026-05-22 ถึง 2026-06-11
**Frequency:** ทุก 5–20 วินาทีต่อ motor

**Payload keys (ย่อ):**
```
device_available, device_error, rotational_speed_hz, rotational_speed_rpm,
temperature_c, x_rms_velocity_mm_s, x_peak_acceleration_g,
x_high_frequency_rms_acceleration_g, x_crest_factor, x_kurtosis,
z_rms_velocity_mm_s, z_peak_acceleration_g, ...
(รวมทั้งหมด 53 fields)
```

**Key fields:**
| Field | Type | คำอธิบาย |
|-------|------|----------|
| rotational_speed_rpm | FLOAT | ความเร็วรอบ (ใช้ระบุว่ามอเตอร์ทำงานอยู่หรือไม่) |
| temperature_c | FLOAT | อุณหภูมิ bearing |
| x_rms_velocity_mm_s | FLOAT | ค่า vibration หลัก (ใช้ประเมิน ISO 10816) |
| x_peak_acceleration_g | FLOAT | Peak acceleration (ตรวจจับ impact) |
| x_crest_factor | FLOAT | Peak/RMS ratio (ค่าสูง = bearing damage) |
| device_available | BOOLEAN | Sensor พร้อมใช้งาน |
| device_error | BOOLEAN | Sensor มี error |

---

### `vibration.raw.v2` — Chiller Motor Vibration (ข้อมูลใหม่)

**Source:** เดียวกับ v1 แต่มีการเปลี่ยน schema
**จำนวน:** ~565,000 rows
**ช่วงเวลา:** 2026-06-11 เป็นต้นไป (ต่อจาก v1)

**ข้อแตกต่างจาก v1:**
- อาจมี fields เพิ่ม/ลด/เปลี่ยนชื่อ
- ผู้เข้าสอบต้อง **สำรวจเอง** ว่าอะไรเปลี่ยน และจัดการ schema evolution อย่างไร

> **หมายเหตุ:** นี่คือสถานการณ์จริงที่เกิดขึ้นในโรงงาน — vendor update firmware แล้ว payload format เปลี่ยน คุณต้องรับมือให้ได้

---

### `power_meter.raw.v1` — Power Meter Readings

**Source:** Power meters (Schneider/ABB) ผ่าน Modbus → Gateway
**จำนวน:** ~299,000 rows
**Frequency:** ทุก 60 วินาที

**Payload keys:**
```
device_id, floor, frequency, source_topic,
eq_active_power, eq_apparent_power, eq_current, eq_power_factor,
eq_reactive_power, eq_phase_to_phase_voltage, eq_phase_v,
l1_current, l1_phase_v, l1_current_thd, l1_voltage_thd, l1_l2_voltage,
l2_current, l2_phase_v, l2_current_thd, l2_voltage_thd, l2_l3_voltage,
l3_current, l3_phase_v, l3_current_thd, l3_voltage_thd, l3_l1_voltage,
total_import_active_energy, total_import_reactive_energy, total_apparent_energy
```

**Key fields:**
| Field | Type | คำอธิบาย |
|-------|------|----------|
| device_id | STRING | ID ของ power meter |
| floor | STRING | ชั้นของโรงงาน (F1, F2, ...) |
| eq_active_power | FLOAT | Active power (kW) |
| eq_power_factor | FLOAT | Power factor (0-1, ค่าใกล้ 1 = ดี) |
| total_import_active_energy | FLOAT | Cumulative kWh (ค่าสะสม) |
| frequency | FLOAT | Grid frequency (Hz) — ควรใกล้ 50 Hz |
| l1_current_thd | FLOAT | Total Harmonic Distortion (%) — ค่าสูง = harmonic issues |

---

## QUALITY Column

ทุก row มี column `QUALITY` ซึ่งมีค่า:
- `GOOD` — ข้อมูลปกติ
- `BAD` — sensor หรือ connection มีปัญหา

**คำแนะนำ:** คุณควรจัดการข้อมูลที่มี QUALITY = BAD อย่างไร? นี่เป็นการตัดสินใจที่คุณต้องระบุใน DESIGN.md

---

## NAMESPACE Column

`NAMESPACE` คือ partial path ที่ไม่รวม work_cell และ asset — ใช้สำหรับ group ข้อมูลในระดับ area:

```
compomax/compomax_site/Forming
compomax/compomax_site/air_chiller
compomax/compomax_site/control_room/electrical
```
