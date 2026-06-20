# Challenge Tasks

> **อ่าน [`scenario.md`](scenario.md) ก่อนเริ่มทำ** — โจทย์ทั้งหมดอิงจากสถานการณ์จริงในโรงงาน

## Platform แนะนำ: Snowflake

- แนะนำให้ใช้ **Snowflake Trial Account** (สมัครฟรี — ดู [README](README.md))
- ข้อมูลจัดเตรียมไว้บน S3 พร้อมสำหรับ load เข้า Snowflake ได้ทันที
- Features ที่เหมาะกับโจทย์: Dynamic Tables, Tasks, Cortex ML, Streamlit in Snowflake
- หากต้องการใช้ tool อื่น (dbt, Spark, Python) ร่วมด้วยก็ได้ — แต่ต้องอธิบายเหตุผลใน DESIGN.md

---

## Phase 1: คำถามจากผู้จัดการ (ต้องตอบได้หลัง Task 1-2)

ผู้จัดการโรงงานถามคำถามเหล่านี้ในที่ประชุม:

| # | จาก | คำถาม |
|---|------|--------|
| Q1 | Production Manager | Group3 ผลิตได้น้อยกว่า Group1 เกือบครึ่ง — **ทำไม?** |
| Q2 | Maintenance Engineer | motor_02 สั่นหนัก — อยู่ **ISO Zone ไหน** (A/B/C/D)? |
| Q3 | Energy Manager | ชั้นไหนใช้ไฟมากที่สุด? กะไหนเปลืองที่สุด? |

Pipeline ที่คุณสร้างใน Task 1-2 ต้องผลิตข้อมูลที่ตอบคำถามเหล่านี้ได้

---

## Task 1: Data Understanding & Schema Design (20 คะแนน)

### บริบท

ตาราง `RAW_EVENTS` รวมข้อมูลจากทุก sensor ไว้ในที่เดียวตาม Unified Namespace (UNS) คุณต้องเข้าใจโครงสร้างก่อนจึงจะออกแบบ pipeline ได้

### สิ่งที่ต้องทำ

1. **สำรวจข้อมูล** — ระบุว่า `RAW_EVENTS` มี data domain อะไรบ้าง
   - ดูจาก `SCHEMA_VERSION`, `AREA`, `WORK_CENTER`
   - ใช้ `OBJECT_KEYS(PAYLOAD)` ดู payload structure

2. **ออกแบบ Silver Schema** — สำหรับ **แต่ละ domain** ที่พบ:
   - เขียน `CREATE TABLE` DDL พร้อม data type ที่เหมาะสม
   - ระบุ computed columns ที่จะช่วยตอบคำถาม Q1-Q3
   - อธิบาย rationale (1 ย่อหน้าต่อ domain)

3. **วาด Architecture Diagram** — แสดง Bronze → Silver → Gold
   - แสดง table names, ความสัมพันธ์, refresh schedule
   - ระบุว่า Gold table ไหนตอบคำถามไหน

### เกณฑ์การให้คะแนน

| เกณฑ์ | คะแนน |
|--------|--------|
| ระบุ domain ได้ครบถ้วนและถูกต้อง | 5 |
| Silver schema มี data type ที่เหมาะสม + computed columns ที่ตอบโจทย์ | 5 |
| Rationale ชัดเจน สมเหตุสมผล | 5 |
| Architecture diagram ครอบคลุม + ชี้ได้ว่า Gold ไหนตอบ Q ไหน | 5 |

### Tips

- ดู `reference/data_dictionary.md` สำหรับ payload fields ทั้งหมด
- สังเกตว่า vibration data มี **2 schema versions** — จะจัดการอย่างไร?
- State codes ของ production ไม่ใช่ 1-6 ตาม textbook — ต้อง explore เอง
- ดู `reference/uns_schema.md` สำหรับ UNS hierarchy

---

## Task 2: Silver Pipeline — Incremental Transform (30 คะแนน)

### บริบท

ข้อมูลไหลเข้ามาตลอดเวลา Pipeline ต้องเป็น **incremental** — ไม่ reprocess ข้อมูลที่ทำไปแล้ว

### สิ่งที่ต้องทำ

เลือก **อย่างน้อย 1 domain** แล้วสร้าง Silver pipeline ที่:

1. **Incremental** — ใช้ watermark, stream, หรือ Dynamic Table
2. **Idempotent** — รันซ้ำได้ ไม่เกิด duplicate
3. **Typed** — แปลง PAYLOAD เป็น typed columns
4. **Enriched** — เพิ่ม computed columns ที่ตอบคำถามทาง business:

   | Domain | Computed column ที่ต้องมี | เพื่อตอบ |
   |--------|--------------------------|---------|
   | Production | `IS_PRODUCING` (state=800), `DOWNTIME_CATEGORY` | Q1: ทำไม Group3 ผลิตน้อย |
   | Vibration | `MACHINE_STATE` (จาก RPM), `ISO_ZONE` (จาก RMS) | Q2: motor_02 อยู่ zone ไหน |
   | Power | `IS_PEAK_HOUR`, `HOURLY_KWH` (จาก cumulative diff) | Q3: ชั้นไหนใช้ไฟมากสุด |

5. **Scheduled** — สร้าง Task ให้รันอัตโนมัติ (ระบุ interval + warehouse)

### ตัวเลือก Implementation

| Approach | ข้อดี | ข้อเสีย |
|----------|------|---------|
| Stored Procedure + Task | ควบคุม logic เต็มที่ | ต้องจัดการ watermark เอง |
| Dynamic Table | Snowflake จัดการ refresh ให้ | จำกัด expression, ไม่มี custom error handling |
| Stream + Task | Event-driven, ไม่ miss data | ต้องเข้าใจ offset management |

### เกณฑ์การให้คะแนน

| เกณฑ์ | คะแนน |
|--------|--------|
| Incremental logic ถูกต้อง (ไม่ full-scan) | 8 |
| Idempotent (MERGE หรือ equivalent) | 7 |
| Data type conversion ถูกต้องและครบถ้วน | 5 |
| Computed columns ตอบโจทย์ business และ logic ถูก | 5 |
| Scheduling ทำงานได้จริง | 5 |

### Bonus

- จัดการ schema evolution vibration v1 → v2 (+3)
- มี error handling / bad data quarantine (+2)
- มี observability (watermark tracking, logging) (+2)

---

## Phase 2: คำถามเพิ่มเติม (เปิดเผยหลังทำ Task 1-2 เสร็จ)

หลังจากเห็น Silver data ผู้จัดการถามเพิ่ม:

| # | จาก | คำถาม |
|---|------|--------|
| Q4 | Production Manager | เครื่องไหนมี **setup/changeover time นานที่สุด?** แสดงเป็น hourly |
| Q5 | Maintenance Engineer | motor_02 vibration **trend ตลอดเดือน** — แย่ลงหรือคงที่? |
| Q6 | Energy Manager | Daily energy cost: **วันหยุด vs วันทำงาน** ต่างกันกี่ %? |
| Q7 | Plant Manager | **สร้างอะไรบางอย่าง** ที่ดูใน 30 วินาทีแล้วรู้ว่าโรงงานมีปัญหาตรงไหน |

---

## Task 3: Gold Aggregation — Analytics Layer (25 คะแนน)

### บริบท

ข้อมูล Silver ยังละเอียดเกินไปสำหรับ business users Gold layer สรุปเป็น hourly/shift/daily grain ที่ตอบ Q4-Q6 ได้ทันที

### สิ่งที่ต้องทำ

สร้าง Gold table **อย่างน้อย 1 ตาราง** ที่:

1. **Aggregates** ข้อมูลเป็น hourly หรือ shift-level grain
2. **Joins** กับ reference table ที่คุณสร้าง (shift definitions, machine config, energy rates)
3. **ตอบคำถามทาง business โดยตรง:**

   **Production Gold (ตอบ Q1, Q4):**
   - Parts produced per hour per machine
   - Uptime % = readings ที่ state=800 / total readings
   - Top downtime reason (จาก status_code → reason lookup)
   - Setup/changeover duration per machine (state=801 consecutive readings × source_period)

   **Vibration Gold (ตอบ Q2, Q5):**
   - Hourly average RMS velocity per motor
   - ISO Zone classification (A: <1.8, B: 1.8-4.5, C: 4.5-11.2, D: >11.2 mm/s)
   - 7-day rolling average → trend direction (improving/stable/degrading)
   - Max crest factor per hour (bearing health indicator)

   **Energy Gold (ตอบ Q3, Q6):**
   - Hourly kWh per meter (MAX - MIN of cumulative energy within hour)
   - Daily cost = kWh × rate (peak 4.50 ฿/kWh, off-peak 2.60 ฿/kWh)
   - Power factor average per hour (flag if < 0.85)
   - Weekend vs weekday label

### Reference Tables ที่ต้องสร้าง

คุณต้อง **ออกแบบเอง** อย่างน้อย 1 ตาราง reference/config:

| ตัวอย่าง | ใช้ทำอะไร |
|----------|----------|
| MACHINE_CONFIG | machine_id, group, category, standard_cycle_time |
| SHIFT_DEFINITIONS | shift_name, start_time_local, end_time_local |
| ENERGY_RATE_CONFIG | hour_start, hour_end, rate_baht_per_kwh, is_peak |
| REASON_CODE_LOOKUP | state_code, status_code, reason_name, treatment |

### เกณฑ์การให้คะแนน

| เกณฑ์ | คะแนน |
|--------|--------|
| Aggregation logic ถูกต้อง (ไม่ double-count, ไม่ AVG cumulative) | 7 |
| Reference table design เหมาะสมและ join ถูกต้อง | 5 |
| Business metrics ตอบ Q4-Q6 ได้จริงและคำนวณถูก | 8 |
| Performance consideration (clustering key, grain ที่เหมาะ) | 5 |

### Bonus

- Gold table ครอบคลุมมากกว่า 1 domain (+5)
- ใช้ Dynamic Table ที่ refresh ได้จริง (+3)

---

## Task 4: AI-Assisted Capstone — Plant Health at a Glance (25 คะแนน)

### บริบท

ผู้จัดการโรงงานพูดว่า:

> "สร้างอะไรบางอย่างที่ฉันเปิดดูตอนเช้าแล้วรู้ใน 30 วินาทีว่าโรงงานสุขภาพดีหรือมีปัญหา"

นี่คือ **Q7** — คำถามสุดท้ายที่ท้าทายที่สุด

### สิ่งที่ต้องทำ

เลือก **1 approach** แล้วสร้างให้ทำงานได้จริง:

#### Option A: Plant Health Dashboard (Streamlit in Snowflake)
- 3 sections: Production | Vibration | Energy
- แต่ละ section แสดง health status (Green/Yellow/Red)
- Drill-down เมื่อคลิก → แสดง detail ของปัญหา
- ใช้ Gold tables เป็น data source

#### Option B: Automated Alert System
- สร้าง Snowflake Alert หรือ Task ที่ตรวจจับ:
  - Vibration เข้า Zone C/D → alert
  - Uptime ต่ำกว่า 50% ใน 1 ชั่วโมง → alert
  - Power factor ต่ำกว่า 0.85 → alert
- เก็บ alert history ใน table
- ส่ง notification (email หรือ webhook)

#### Option C: Cortex ML — Predictive Maintenance
- ใช้ Snowflake Cortex Anomaly Detection บน vibration data
- ใช้ Cortex Forecast ทำนาย vibration 7 วันข้างหน้า
- สรุปผลลัพธ์: motor_02 จะถึง critical เมื่อไหร่?

#### Option D: Semantic View + Natural Language Query
- สร้าง Semantic View จาก Gold tables
- ผู้จัดการสามารถถาม: "เครื่องไหนผลิตน้อยที่สุดวันนี้?" เป็นภาษาธรรมชาติ
- แสดง verified queries ที่ทดสอบแล้ว

### เกณฑ์การให้คะแนน

| เกณฑ์ | คะแนน |
|--------|--------|
| ทำงานได้จริง (demo ได้, functional) | 8 |
| ตอบ Q7 ได้ ("30 วินาทีรู้สุขภาพโรงงาน") | 7 |
| Design decisions อธิบายใน DESIGN.md | 5 |
| ใช้ AI tools อย่างมีประสิทธิภาพ (ไม่ copy-paste) | 5 |

### หมายเหตุ

- **ใช้ AI ได้ทุกตัว** — Cortex Code, ChatGPT, Copilot, Claude
- แต่ต้อง **อธิบายได้** ว่าทำไมเลือกแบบนี้
- ถ้า AI generate code ต้อง **เข้าใจทุกบรรทัด** — อาจถูกถามในสัมภาษณ์

---

## สรุปคะแนน

| Task | คะแนน | ทดสอบอะไร |
|------|--------|-----------|
| 1. Data Understanding & Schema Design | 20 | Strategic Thinking |
| 2. Silver Pipeline | 30 | Implementation |
| 3. Gold Aggregation | 25 | Analytics Engineering |
| 4. Capstone | 25 | AI-Assisted Delivery |
| **รวม** | **100** | |
| Bonus (ทุก task รวมกัน) | สูงสุด +15 | Excellence |

**ผ่าน:** 60 คะแนน | **ดี:** 75 คะแนน | **ดีมาก:** 85+ คะแนน

---

## Deliverables Checklist

### Code & SQL
- [ ] SQL files สำหรับ Silver table(s) + pipeline
- [ ] SQL files สำหรับ Gold table(s) + reference tables
- [ ] Task 4 implementation (Streamlit / Alert / ML / Semantic View)

### DESIGN.md (Structured — ตามหัวข้อด้านล่าง)

ส่งไฟล์ `DESIGN.md` ที่มีหัวข้อต่อไปนี้ **ทุกข้อ:**

#### 1. Architecture Diagram
- วาด diagram แสดง Bronze → Silver → Gold
- ระบุ table names, refresh schedule, dependencies
- แสดงว่า Gold table ไหนตอบ Q ไหน
- ใช้ Mermaid, ASCII art, หรือรูปภาพก็ได้

#### 2. Decision Log (สำคัญมาก)
สำหรับทุกการตัดสินใจหลักที่คุณทำ ให้เขียน:

| # | การตัดสินใจ | ทำไมเลือกแบบนี้ | ทางเลือกที่พิจารณาแล้วไม่เลือก |
|---|------------|----------------|-------------------------------|
| 1 | ตัวอย่าง: ใช้ Dynamic Table แทน SP | declarative, ง่ายกว่า, auto-refresh | SP: ควบคุมได้มากกว่าแต่ complexity สูง |
| 2 | ... | ... | ... |

**ต้องมีอย่างน้อย 5 decisions** เช่น:
- เลือก domain ไหน? ทำไม?
- Incremental strategy: watermark vs stream vs DT?
- จัดการ vibration v1→v2 อย่างไร?
- QUALITY=BAD: filter, flag, หรือ quarantine?
- Timezone: convert ที่ Silver หรือ Gold?
- 803105 (No Order): นับเป็น downtime หรือ excluded?

#### 3. Data Quality Findings
- สิ่งที่คุณพบว่า "ผิดปกติ" หรือ "น่าสงสัย" ในข้อมูล
- สิ่งที่คุณทำกับมัน (filter? flag? report?)
- สิ่งที่คุณจะแจ้ง IT/plant manager ถ้าเป็นงานจริง

#### 4. Business Questions Mapping
แสดงว่า pipeline ที่คุณสร้าง **ตอบ Q1-Q7 อย่างไร:**

| Question | ตอบจากตารางไหน | Query/วิธีดู |
|----------|---------------|-------------|
| Q1: Group3 ทำไมผลิตน้อย | GOLD.PRODUCTION_HOURLY | `WHERE work_center='Group3' ...` |
| Q2: motor_02 zone ไหน | SILVER.VIBRATION | `WHERE asset='motor_02' ...` |
| ... | ... | ... |

#### 5. Tradeoffs & Limitations
- Pipeline ของคุณมีข้อจำกัดอะไร?
- ถ้ามีเวลาเพิ่มจะทำอะไรต่อ?
- Scale issues: ถ้าเครื่องจักรเพิ่มเป็น 200 ตัว จะเกิดอะไร?

---

### Video Walkthrough (5-10 นาที)

> **ห้ามส่ง video ผ่าน Git** — ไฟล์ใหญ่เกินไป
> อัปโหลดขึ้น **Loom** (แนะนำ) หรือ **YouTube (Unlisted)** แล้วใส่ link ไว้ใน README.md ของ repo คุณ
> ตัวอย่าง: `## Video Walkthrough` → `https://www.loom.com/share/xxxxx`

**สำคัญ: ต้องส่ง video** — ใช้ Loom, OBS, หรือ screen recording อะไรก็ได้

ใน video ต้องมี:

1. **Demo สด (2-3 นาที)**
   - แสดงว่า pipeline ทำงาน (run task หรือ refresh DT)
   - Query Gold table แล้วตอบ Q1 หรือ Q2 ให้ดู
   - ถ้ามี dashboard → เปิดให้เห็น

2. **อธิบาย Architecture (2-3 นาที)**
   - เปิด diagram จาก DESIGN.md
   - อธิบายว่าข้อมูลไหลอย่างไร
   - ชี้ว่า "ตรงนี้ตอบ Q1, ตรงนี้ตอบ Q3"

3. **Decision ที่ยากที่สุด (1-2 นาที)**
   - เลือก 1 decision ที่คุณคิดนานที่สุด
   - อธิบายว่าพิจารณาอะไร ทำไมเลือกแบบนี้
   - ถ้าเลือกใหม่ได้จะเปลี่ยนอะไร?

4. **Data Quality Finding (1 นาที)**
   - แสดงสิ่งที่คุณพบว่า "ไม่ถูกต้อง" หรือ "น่าสงสัย"
   - คุณทำอะไรกับมัน?

**Tips สำหรับ video:**
- ไม่ต้อง edit / ไม่ต้องสวย — เน้นเนื้อหา
- พูดเป็นภาษาไทยหรืออังกฤษก็ได้
- ไม่จำเป็นต้องเปิดหน้า (voice + screen recording พอ)
- Upload ขึ้น YouTube (unlisted) หรือ Loom แล้วใส่ link ใน README ของ repo

> **ทำไมต้องมี video?**
> เพราะ AI สามารถเขียน code และ document ได้ แต่ไม่สามารถ **อธิบายสดๆ** ว่าทำไมเลือกแบบนี้ได้
> Video คือสิ่งที่พิสูจน์ว่าคุณเข้าใจจริง ไม่ใช่แค่ copy-paste

---

### REFLECTION.md (ไม่มี template — เขียนอิสระ)
- สิ่งที่เรียนรู้จากโจทย์นี้
- ปัญหาที่เจอ + วิธีแก้
- ถ้ามีเวลา 2 สัปดาห์เพิ่ม จะทำอะไรต่อ?

---

## วิธีการส่งงาน

ส่งเป็น **Git repository** (GitHub/GitLab) ที่มีทุก deliverable ข้างต้น

ตั้งชื่อ repo: `de-challenge-2026-{ชื่อ-นามสกุล}`
