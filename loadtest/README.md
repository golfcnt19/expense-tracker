# Load testing

ทดสอบโหลด API ด้วย Apache JMeter 5.6.3 พร้อมผลการวัดจริงที่ทำซ้ำได้

## ผลลัพธ์: index สำคัญแค่ไหน

ทดลองวัดผลของ index สองตัวที่ออกแบบไว้ใน migration แรก โดยรัน **พารามิเตอร์เดียวกันเป๊ะ**
สองรอบ ต่างกันแค่มีหรือไม่มี index

```
ข้อมูล      200,000 แถว (39 MB)
โหลด        50 concurrent users, ramp-up 10 วิ, ยิงต่อเนื่อง 60 วิ
endpoint    GET /api/expenses (list) และ GET /api/expenses/summary
```

| | **มี index** | **ไม่มี index** | ต่างกัน |
|---|---:|---:|---:|
| Throughput | **2,675 req/s** | 194 req/s | **13.8×** |
| รวมทั้งหมด | 160,413 req | 11,600 req | |
| Error | 0.00% | 0.00% | |

รายละเอียดเวลาตอบสนอง หน่วยเป็นมิลลิวินาที

| endpoint | | avg | p50 | p95 | p99 | max |
|---|---|---:|---:|---:|---:|---:|
| GET list | มี index | **15** | 16 | 21 | 32 | 91 |
| | ไม่มี index | 255 | 255 | 435 | 528 | 963 |
| GET summary | มี index | **19** | 20 | 26 | 36 | 94 |
| | ไม่มี index | 220 | 233 | 365 | 473 | 883 |

**p99 ของ list ต่างกัน 16 เท่า** (32 ms → 528 ms) — ตัวเลข p99 สำคัญกว่า avg
เพราะมันคือประสบการณ์ของผู้ใช้ที่โชคร้ายที่สุด 1 ใน 100 คน ซึ่งเป็นกลุ่มที่มักบ่น

## ทำไมถึงต่างขนาดนั้น

แผนคิวรีตอนมี index — อ่านแค่ 23 หน้าข้อมูล

```
Limit (actual time=0.147..0.222 rows=20 loops=1)
  Buffers: shared hit=20 read=3
  ->  Index Scan using idx_expense_spent_on_desc on expense
        Index Cond: (spent_on >= ... AND spent_on <= ...)
```

`ORDER BY spent_on DESC, id DESC` ตรงกับลำดับของ index พอดี ฐานข้อมูลจึงอ่าน 20 แถวแรก
แล้วหยุด **ไม่ต้อง sort เลย**

พอไม่มี index ต้อง Seq Scan ทั้ง 200,000 แถว แล้ว sort ก่อนตัด 20 แถวแรก — งานเพิ่มขึ้นหมื่นเท่า
เพื่อผลลัพธ์ชุดเดียวกัน

index ที่ใช้

```sql
CREATE INDEX idx_expense_spent_on_desc     ON expense (spent_on DESC, id DESC);
CREATE INDEX idx_expense_category_spent_on ON expense (category, spent_on DESC);
```

ตัวแรกออกแบบให้ตรงกับ `ORDER BY` ของหน้ารายการ ตัวที่สองสำหรับหน้าสรุปที่กรองด้วย category
ก่อนช่วงวันที่ — **ไม่ได้ใส่ index ตามความรู้สึก แต่ใส่ตามคิวรีที่โค้ดยิงจริง**

## วิธีรันซ้ำ

ต้องมี JMeter 5.6.3 ในเครื่องและ API รันอยู่

```bash
jmeter -n -t expense-api.jmx -Jusers=50 -Jrampup=10 -Jduration=60 -l results/run.jtl
```

สรุปผลเป็นตาราง

```bash
node summarise.js results/run.jtl
```

พารามิเตอร์ที่ปรับได้

| flag | ค่าเริ่มต้น | ความหมาย |
|---|---|---|
| `-Jhost` | localhost | โฮสต์ของ API |
| `-Jport` | 8080 | พอร์ต |
| `-Jusers` | 50 | จำนวน thread ที่ยิงพร้อมกัน |
| `-Jrampup` | 10 | วินาทีที่ใช้เร่งจนครบทุก thread |
| `-Jduration` | 60 | วินาทีที่ยิงต่อเนื่อง |

### ทำการทดลอง index ซ้ำ

```sql
-- ลบ
DROP INDEX idx_expense_spent_on_desc;
DROP INDEX idx_expense_category_spent_on;
ANALYZE expense;

-- คืน
CREATE INDEX idx_expense_spent_on_desc     ON expense (spent_on DESC, id DESC);
CREATE INDEX idx_expense_category_spent_on ON expense (category, spent_on DESC);
ANALYZE expense;
```

### สร้างข้อมูลทดสอบ

```sql
INSERT INTO expense (id, amount, category, note, spent_on, created_at, updated_at)
SELECT gen_random_uuid(),
       ROUND((random() * 4990 + 10)::numeric, 2),
       (ARRAY['FOOD','TRANSPORT','HOUSING','UTILITIES','HEALTH','ENTERTAINMENT','OTHER'])[1 + floor(random()*7)::int],
       'seed row ' || g,
       CURRENT_DATE - (floor(random()*730))::int,
       now(), now()
FROM generate_series(1, 200000) g;
ANALYZE expense;
```

## สิ่งที่ตั้งใจใส่ไว้ใน test plan

**สุ่มช่วงวันที่ใหม่ทุก iteration** — ถ้ายิงคิวรีเดิมซ้ำ ๆ ฐานข้อมูลกับ OS จะ cache ไว้หมด
แล้วตัวเลขจะสวยเกินจริง แต่ละรอบจึงสุ่มหน้าต่าง 30 วันเลื่อนไปมาในช่วง 2 ปี

**เปิด HTTP keep-alive** ไม่งั้นจะกลายเป็นวัดความเร็ว TCP handshake แทนที่จะวัด API

**มี response assertion ตรวจ status 200** ทุก sampler — ถ้าไม่ตรวจ API ที่ตอบ 500 เร็ว ๆ
จะดูเหมือนมี throughput สูง ทั้งที่พังหมด

**ใช้ฟังก์ชันในตัวของ JMeter ไม่ใช่ Groovy** — Groovy 3.0.20 ที่มากับ JMeter 5.6.3
คอมไพล์ไม่ผ่านบน JDK 25 (`Unsupported class file major version 69`) การเลี่ยง Groovy
ทำให้ test plan นี้รันได้โดยไม่ผูกกับเวอร์ชัน JDK

## ข้อจำกัดของตัวเลขชุดนี้

ตัวเลขข้างบนวัดจาก **เครื่องพัฒนาเครื่องเดียว** ที่รันทั้ง JMeter, API และ PostgreSQL พร้อมกัน
ค่าที่ได้จึงใช้ **เปรียบเทียบระหว่างสองเงื่อนไข** ได้ แต่ไม่ใช่ capacity จริงของระบบบนเซิร์ฟเวอร์

การวัด capacity จริงต้องแยกเครื่อง generator ออกจากเครื่องที่รันระบบ ไม่งั้น JMeter เองจะแย่ง CPU
กับสิ่งที่กำลังวัดอยู่
