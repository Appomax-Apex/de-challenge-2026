# ISA-95 Model Cheatsheet

## ISA-95 คืออะไร?

ISA-95 (IEC 62264) เป็นมาตรฐานสากลที่กำหนด **โครงสร้างลำดับชั้น** ของระบบในโรงงานอุตสาหกรรม ช่วยให้ทุกคนพูดภาษาเดียวกันเมื่อพูดถึง "เครื่องไหน อยู่ตรงไหน ทำอะไร"

## Physical Hierarchy (Equipment Model)

```
Enterprise          ← บริษัท / องค์กร
  └── Site          ← โรงงาน / สถานที่
       └── Area     ← พื้นที่การผลิต (production area)
            └── Work Center  ← กลุ่มเครื่องจักร (line, cell group)
                 └── Work Unit (Work Cell)  ← หน่วยงานย่อย
                      └── Equipment (Asset)  ← เครื่องจักร/อุปกรณ์แต่ละตัว
```

### Mapping กับข้อมูลในโจทย์นี้

| ISA-95 Level | Column ใน RAW_EVENTS | ตัวอย่าง |
|---|---|---|
| Enterprise | `ENTERPRISE` | compomax |
| Site | `SITE` | compomax_site |
| Area | `AREA` | Forming, air_chiller, control_room |
| Work Center | `WORK_CENTER` | Group1, chiller, electrical |
| Work Cell | `WORK_CELL` | chiller_01, power_meter |
| Equipment/Asset | `ASSET` | FM22, motor_01, MAIN-MDB |

---

## Production States (โรงงานนี้)

ข้อมูล Production ใช้ state model ที่กำหนดเอง (ไม่ใช่ ISA-95 Part 6 ตรงๆ):

| n3_state_code | State | คำอธิบาย |
|---|---|---|
| 800 | **Running** | เครื่องกำลังผลิตชิ้นงาน |
| 801 | **Setup / Changeover** | กำลังเปลี่ยน die หรือตั้งค่าเครื่อง |
| 803 | **Stopped** | หยุดด้วยเหตุผลต่างๆ (ดู sub-status) |
| NULL | **Offline / No Data** | ไม่มีข้อมูล state (ประมาณ 4.8% ของ readings) |

### Sub-status codes (n3_status_code เมื่อ state=803)

| n3_status_code | เหตุผล | Treatment |
|---|---|---|
| 803105 | No Order Assigned — ไม่มี work order สั่ง | EXCLUDED |
| 803101 | Material Shortage — รอวัตถุดิบ | UNPLANNED_DOWNTIME |
| 803112 | Mechanical Fault — เครื่องเสีย | UNPLANNED_DOWNTIME |
| 803102 | Unknown (TBD) | UNPLANNED_DOWNTIME |
| 803103 | Unknown (TBD) | UNPLANNED_DOWNTIME |
| 803104 | Unknown (TBD) | UNPLANNED_DOWNTIME |
| 803111 | Unknown (TBD) | UNPLANNED_DOWNTIME |

> **หมายเหตุ:** reason 803105 (No Order) คิดเป็นสัดส่วนใหญ่มาก — โรงงานถือว่า "excluded" ไม่ควรนับเป็น downtime แต่ผู้เข้าสอบต้องตัดสินใจเอง

---

## OEE (Overall Equipment Effectiveness)

OEE เป็น KPI หลักของ manufacturing ประกอบด้วย 3 ส่วน:

```
OEE = Availability × Performance × Quality

Availability = (Planned Time - Downtime) / Planned Time
Performance = (Actual Output × Ideal Cycle Time) / Available Time  
Quality     = Good Parts / Total Parts
```

### ในโจทย์นี้:

- **Availability** คำนวณจาก n3_state_code (state 800 = producing, state 803 ที่ไม่ใช่ 803105 = downtime)
- **Performance** คำนวณจาก wo_part_counter_delta × wo_cycle_time / available_time
- **Quality** — ข้อมูล quality/reject ไม่มีใน dataset นี้ จึงมักสมมติ = 1.0 หรือใช้เฉพาะ AP Score (Availability × Performance)

> **ข้อควรระวังในโจทย์นี้:**
> - State 803 + reason 105 (No Order) = excluded time — โรงงานไม่นับเป็น downtime
> - ต้องตัดสินใจว่า "planned production time" = total time - excluded time หรือไม่

> **หมายเหตุ:** ในโจทย์นี้ ใช้ **AP Score** (Availability × Performance) แทน OEE เต็มรูปแบบ เพราะไม่มี reject data

---

## Shift Model

โรงงานทำงาน 2 กะหลัก + 2 กะล่วงเวลา (ไม่เป็นมาตรฐาน 8-16-24):

| กะ | เวลา (Local, GMT+7) | ชั่วโมง | หมายเหตุ |
|---|---|---|---|
| Day | 00:45 – 09:45 | 9 ชม. | กะเช้า |
| Day OT | 09:45 – 12:45 | 3 ชม. | ล่วงเวลาเช้า |
| Night | 12:45 – 21:45 | 9 ชม. | กะค่ำ |
| Night OT | 21:45 – 00:45 | 3 ชม. | ล่วงเวลาค่ำ |

**สำคัญ:** ข้อมูลใน `EVENT_TS` เป็น **UTC** — ต้องแปลง +7 ชั่วโมง (`CONVERT_TIMEZONE('UTC','Asia/Bangkok',EVENT_TS)`) ก่อนคำนวณ shift

---

## Vibration Standards (ISO 10816 / ISO 20816)

สำหรับ vibration monitoring ใช้ค่า RMS Velocity (mm/s) ในการประเมินสภาพเครื่อง:

| Zone | ค่า RMS Velocity (mm/s) | สถานะ | การตอบสนอง |
|------|--------------------------|-------|------------|
| A | 0 – 1.8 | ดีมาก (Newly commissioned) | ไม่ต้องทำอะไร |
| B | 1.8 – 4.5 | ยอมรับได้ (Acceptable) | เฝ้าระวัง |
| C | 4.5 – 11.2 | เตือน (Alert) | วางแผนซ่อม |
| D | > 11.2 | อันตราย (Danger) | หยุดเครื่องทันที |

> **หมายเหตุ:** ค่าเหล่านี้สำหรับเครื่องจักร Class II (15–75 kW) ซึ่งตรงกับ chiller motors ในโจทย์

---

## Medallion Architecture (Bronze → Silver → Gold)

```
┌──────────┐         ┌──────────┐         ┌──────────┐
│  BRONZE  │         │  SILVER  │         │   GOLD   │
│          │  ──→    │          │  ──→    │          │
│ Raw JSON │         │  Typed   │         │ Business │
│ as-is    │         │  Cleaned │         │ Metrics  │
└──────────┘         └──────────┘         └──────────┘
  RAW_EVENTS          Domain tables         Hourly/Shift
  (1 table)           (1 per domain)        aggregations
  VARIANT payload     Typed columns         KPIs, alerts
  All domains mixed   Filtered, enriched    Dashboard-ready
```

### แนวคิดหลัก:

| Layer | หลักการ |
|-------|---------|
| Bronze | ห้ามแก้ไข ห้ามลบ — เก็บ raw as-is ไว้เสมอ |
| Silver | Clean, type, enrich — 1 table ต่อ 1 domain |
| Gold | Aggregate, join, calculate — พร้อมใช้งาน |
