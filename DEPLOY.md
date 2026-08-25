# Deploy

เอาระบบขึ้นออนไลน์ฟรี — API บน Render, ฐานข้อมูลบน Neon, client บน GitHub Pages

```
Angular   →  golfcnt19.github.io/expense-tracker/         (GitHub Pages)
Flutter   →  golfcnt19.github.io/expense-tracker/mobile/  (GitHub Pages)
API       →  expense-api.onrender.com                     (Render, free)
Database  →  neon.tech                                     (Neon, free)
```

## ต้องสมัครบัญชีสองที่

ทั้งสองที่สมัครด้วย GitHub ได้ ไม่ต้องใส่บัตรเครดิต

| บริการ | ให้อะไรฟรี | ข้อจำกัด |
|---|---|---|
| [Neon](https://neon.tech) | Postgres 0.5 GB | scale-to-zero ตอนไม่มีใครใช้ |
| [Render](https://render.com) | 750 ชม./เดือน · 512 MB | หลับหลังไม่มี traffic 15 นาที ตื่นใช้เวลา 30–50 วิ |

Postgres ฟรีของ Render เองก็มี แต่**หมดอายุใน 90 วัน** ส่วนของ Neon ฟรีถาวร จึงแยกกันแบบนี้

---

## ขั้นที่ 1 — ฐานข้อมูลบน Neon

1. สมัครที่ neon.tech แล้วสร้าง project ใหม่
2. เลือก region ที่ใกล้ Render ที่สุด (Singapore)
3. คัดลอกค่าเชื่อมต่อจากหน้า Dashboard → **Connection string**

Neon ให้ connection string แบบ `postgresql://...` แต่ Java ต้องการแบบ `jdbc:postgresql://...`
แปลงตามนี้

```
Neon ให้มา
  postgresql://alice:secret@ep-cool-123.ap-southeast-1.aws.neon.tech/neondb?sslmode=require

แยกเป็นสามค่า
  DB_URL       jdbc:postgresql://ep-cool-123.ap-southeast-1.aws.neon.tech/neondb?sslmode=require
  DB_USER      alice
  DB_PASSWORD  secret
```

**ห้ามใส่รหัสผ่านลงใน `DB_URL`** — แยกเป็น `DB_USER` กับ `DB_PASSWORD` เพื่อไม่ให้รหัสไปโผล่ใน log
ตอน Spring Boot พิมพ์ URL ออกมา

ไม่ต้องสร้างตารางเอง Flyway จะ migrate ให้ตอน API สตาร์ทครั้งแรก

## ขั้นที่ 2 — API บน Render

1. สมัครที่ render.com ด้วยบัญชี GitHub
2. **New → Blueprint** แล้วเลือก repo `expense-tracker`
3. Render อ่าน [`render.yaml`](render.yaml) แล้วตั้งค่าให้เองทั้งหมด
4. กรอกสามค่าที่มันถามในหน้า Environment

```
DB_URL       jdbc:postgresql://...
DB_USER      ...
DB_PASSWORD  ...
```

5. กด Apply แล้วรอ build ประมาณ 5–8 นาที (build image จาก Containerfile)

ตรวจว่าขึ้นแล้ว

```bash
curl https://expense-api.onrender.com/actuator/health
```

ควรได้ `{"status":"UP"}` — ครั้งแรกอาจช้าเพราะ service เพิ่งตื่น

### ใส่ข้อมูลตัวอย่าง

ฐานข้อมูลใหม่จะว่างเปล่า ยิง SQL นี้ผ่าน SQL Editor ของ Neon

```sql
INSERT INTO expense (id, amount, category, note, spent_on, created_at, updated_at)
SELECT gen_random_uuid(),
       ROUND((random() * 4990 + 10)::numeric, 2),
       (ARRAY['FOOD','TRANSPORT','HOUSING','UTILITIES','HEALTH','ENTERTAINMENT','OTHER'])[1 + floor(random()*7)::int],
       'demo ' || g,
       CURRENT_DATE - (floor(random()*365))::int,
       now(), now()
FROM generate_series(1, 500) g;
```

500 แถวพอสำหรับเดโม — ไม่ต้อง 200,000 แถวเพราะ Neon ฟรีให้ 0.5 GB

## ขั้นที่ 3 — client ขึ้น GitHub Pages

หลังจาก API ขึ้นแล้วและรู้ URL จริง

1. ไปที่ repo → **Settings → Secrets and variables → Actions → Variables**
2. สร้าง variable ชื่อ `API_BASE` ค่าเป็น URL ของ API เช่น `https://expense-api.onrender.com`
3. ไปที่ **Settings → Pages** → Source เลือก **GitHub Actions**
4. push อะไรก็ได้ขึ้น `main` — workflow จะ build แล้ว deploy ให้เอง

CI จะแทนค่า `window.__API_BASE__` ใน `index.html` ของ Angular และส่ง `--dart-define=API_BASE`
ให้ Flutter ตอน build

---

## เรื่องที่ต้องรู้

**Render free หลับหลัง 15 นาที** คนเปิดลิงก์ครั้งแรกจะรอ 30–50 วินาที
ถ้าจะเอาไปโชว์ตอนสัมภาษณ์ ให้เปิดลิงก์ทิ้งไว้ก่อนสัก 1 นาที

**512 MB ตึงสำหรับ JVM** `render.yaml` ตั้ง `MaxRAMPercentage=65` กับ `SerialGC` ไว้แล้ว
ถ้ายังโดน OOM ให้ลดเหลือ 60 หรือพิจารณาคอมไพล์เป็น GraalVM native image
ซึ่งกินหน่วยความจำราว 50 MB และสตาร์ทใน 50 ms

**CORS ต้องตรงกับ origin ของ client** ตั้งใน `render.yaml` ที่ `APP_CORS_ORIGINS`
ถ้า client ย้าย URL ต้องแก้ตรงนี้ด้วย ไม่งั้นเบราว์เซอร์จะบล็อกทุกคำขอ

**connection pool ตั้งไว้ 5** เพราะ Neon ฟรีจำกัดจำนวน connection
ถ้าตั้งสูงกว่านี้จะโดนปฏิเสธตอนมีคนใช้พร้อมกัน

## ถ้าไม่อยากให้ service หลับ

[Oracle Cloud Always Free](https://www.oracle.com/cloud/free/) ให้ 4 vCPU ARM กับ RAM 24 GB
ตลอดชีพ รันทั้ง API และ Postgres บนเครื่องเดียวได้สบาย ไม่หลับ แลกกับการตั้งค่าที่ยุ่งกว่ามาก
และขั้นตอนสมัครที่ผ่านยาก
