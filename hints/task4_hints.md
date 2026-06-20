# Hints — Task 4: AI-Assisted Capstone

## ถ้าไม่รู้จะเริ่มยังไง

### Hint Level 1 (เลือก Option ที่ง่ายที่สุดสำหรับคุณ)

| Option | ระดับความยาก | เหมาะกับใคร |
|--------|-------------|-------------|
| A: Vibration Alert | ปานกลาง | คนที่ถนัด SQL/logic |
| B: OEE Dashboard | ง่ายที่สุด | คนที่ถนัด visualization |
| C: Energy Monitor | ปานกลาง | คนที่ถนัด time-series |
| D: Semantic View | ยากที่สุด | คนที่อยากลองของใหม่ |

### Hint Level 2 (Streamlit starter)

ถ้าเลือก Option B (OEE Dashboard):

```python
# streamlit_app.py — run in Snowflake Streamlit
import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.title("Production OEE Dashboard")

# Query gold table
df = session.sql("""
    SELECT * FROM DE_CHALLENGE.GOLD.PRODUCTION_HOURLY_GOLD
    ORDER BY HOUR_LOCAL DESC
    LIMIT 1000
""").to_pandas()

# Fleet overview
st.metric("Average AP Score", f"{df['UPTIME_PCT'].mean():.1%}")

# Per-machine chart
st.bar_chart(df.groupby('ASSET')['PARTS_PRODUCED'].sum())
```

### Hint Level 3 (Cortex ML for anomaly detection)

ถ้าเลือก Option A (Vibration Alert):

```sql
-- Train anomaly detection model on vibration data
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION my_model(
    INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'DE_CHALLENGE.SILVER.VIBRATION_SILVER'),
    TIMESTAMP_COLNAME => 'EVENT_TS',
    TARGET_COLNAME => 'X_RMS_VELOCITY_MM_S',
    LABEL_COLNAME => ''  -- unsupervised
);

-- Run detection
CALL my_model!DETECT_ANOMALIES(
    INPUT_DATA => SYSTEM$REFERENCE('TABLE', 'DE_CHALLENGE.SILVER.VIBRATION_SILVER'),
    TIMESTAMP_COLNAME => 'EVENT_TS',
    TARGET_COLNAME => 'X_RMS_VELOCITY_MM_S'
);
```

### Hint Level 4 (Semantic View starter)

ถ้าเลือก Option D:

```sql
CREATE OR REPLACE SEMANTIC VIEW DE_CHALLENGE.GOLD.PRODUCTION_SEMANTIC
AS
  TABLES (
    DE_CHALLENGE.GOLD.PRODUCTION_HOURLY_GOLD
      PRIMARY KEY (ASSET, HOUR_LOCAL)
      WITH METRICS (
        parts_produced = SUM(PARTS_PRODUCED),
        avg_uptime = AVG(UPTIME_PCT)
      )
      WITH DIMENSIONS (
        machine = ASSET,
        hour = HOUR_LOCAL,
        work_center = WORK_CENTER
      )
  );
```

---

## ข้อควรระวัง (หักคะแนน: -2 ถ้าดู hints)
