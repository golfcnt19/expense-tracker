# Expense Tracker

ระบบบันทึกค่าใช้จ่าย — REST API หนึ่งตัว ต่อด้วย client สองแบบ พร้อมชุดทดสอบโหลดที่วัดผลจริง

สร้างขึ้นเพื่อแสดงวิธีทำงานแบบ full stack ตั้งแต่การออกแบบ schema ไปจนถึงหน้าจอที่ผู้ใช้กด
และการพิสูจน์ว่าระบบรับโหลดไหวก่อนขึ้นใช้งาน

---

## ผลที่วัดได้: index ทำให้ throughput ต่างกัน 13.8 เท่า

รัน JMeter ด้วยพารามิเตอร์เดียวกันเป๊ะสองรอบ บนข้อมูล 200,000 แถว
ต่างกันแค่ว่ามี index สองตัวที่ออกแบบไว้หรือไม่

| | มี index | ไม่มี index |
|---|---:|---:|
| Throughput | **2,675 req/s** | 194 req/s |
| `GET /expenses` p99 | **32 ms** | 528 ms |
| `GET /expenses/summary` p99 | **36 ms** | 473 ms |
| Error rate | 0.00% | 0.00% |

```
Index Scan using idx_expense_spent_on_desc
  Buffers: shared hit=20 read=3        ← อ่าน 23 หน้า แทนที่จะสแกน 200,000 แถว
```

`ORDER BY spent_on DESC, id DESC` ถูกออกแบบให้ตรงกับลำดับของ index พอดี ฐานข้อมูลจึงอ่าน
20 แถวแรกแล้วหยุด ไม่ต้อง sort เลย — **index ไม่ได้ใส่ตามความรู้สึก แต่ใส่ตามคิวรีที่โค้ดยิงจริง**

วิธีทำซ้ำและรายละเอียดทั้งหมดอยู่ที่ [`loadtest/README.md`](loadtest/README.md)

วิธีเอาขึ้นออนไลน์ฟรี ดูที่ [`DEPLOY.md`](DEPLOY.md)

---

## สถาปัตยกรรม

```
                    ┌──────────────────────┐
   Angular 22  ────▶│                      │
                    │   Spring Boot 4      │
   Flutter web ────▶│   Kotlin · JDK 25    │────▶  PostgreSQL 18
                    │                      │       (Flyway migrations)
   JMeter      ────▶│   REST · 6 endpoints │
                    └──────────────────────┘
```

| โฟลเดอร์ | คืออะไร |
|---|---|
| [`api/`](api) | Spring Boot 4.1 + Kotlin · JPA · Flyway · Bean Validation |
| [`web/`](web) | Angular 22 · signals · `httpResource` |
| [`mobile/`](mobile) | Flutter 3.47 · build เป็น web ได้ |
| [`loadtest/`](loadtest) | JMeter test plan + ผลการวัด |
| [`Containerfile`](Containerfile) | multi-stage build · รันด้วย non-root |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | CI 4 jobs |
| [`Jenkinsfile`](Jenkinsfile) | pipeline เทียบเท่า สำหรับองค์กรที่ใช้ Jenkins |

## API

| Method | Path | ทำอะไร |
|---|---|---|
| `POST` | `/api/expenses` | เพิ่มรายการ · คืน `201` + `Location` |
| `GET` | `/api/expenses` | ดึงรายการ · กรองช่วงวันที่และหมวด · แบ่งหน้า |
| `GET` | `/api/expenses/{id}` | ดึงรายตัว |
| `PUT` | `/api/expenses/{id}` | แก้ไข |
| `DELETE` | `/api/expenses/{id}` | ลบ · คืน `204` |
| `GET` | `/api/expenses/summary` | รวมยอดต่อหมวดในช่วงวันที่ |

## เทสต์

```
api      16 tests   รันกับ PostgreSQL จริง ไม่ใช่ H2
mobile    9 tests   models, HTTP client, การจัดการ error
```

เทสต์ฝั่ง API ยิงผ่าน Flyway migration และ SQL จริงทุกครั้ง — ถ้าใช้ H2 ในหน่วยความจำ
ปัญหาที่เกิดเฉพาะกับ PostgreSQL จะไม่ถูกจับ ใน CI ใช้ service container `postgres:18` ตัวเดียวกัน

---

## รันในเครื่อง

ต้องมี **JDK 25**, **Node 24**, **Flutter 3.47**, **PostgreSQL 18**

### 1. ฐานข้อมูล

```bash
createdb expense_tracker
```

Flyway จะสร้างตารางให้เองตอน API สตาร์ทครั้งแรก

### 2. API

```bash
cd api && ./mvnw spring-boot:run
```

ขึ้นที่ `http://localhost:8080` · ตรวจสถานะที่ `/actuator/health`

ตั้งค่าผ่าน environment variable ได้: `DB_URL`, `DB_USER`, `DB_PASSWORD`, `PORT`, `DB_POOL_MAX`

### 3. Angular

```bash
cd web && npm ci && npm start
```

`http://localhost:4200` — proxy `/api` ไปที่ 8080 ให้แล้ว

### 4. Flutter

```bash
cd mobile && flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

หรือ build เป็นไฟล์ static

```bash
flutter build web --release --dart-define=API_BASE=https://your-api.example.com
```

### 5. Load test

```bash
cd loadtest
jmeter -n -t expense-api.jmx -Jusers=50 -Jduration=60 -l results/run.jtl
node summarise.js results/run.jtl
```

---

## การตัดสินใจเชิงออกแบบ

**Flyway เป็นเจ้าของ schema · Hibernate ตั้ง `ddl-auto=validate`**
ไม่ปล่อยให้ ORM แก้โครงสร้างฐานข้อมูลเอง ทุกการเปลี่ยนแปลง schema เป็นไฟล์ migration
ที่ review ได้และย้อนดูได้ว่าใครเปลี่ยนอะไรเมื่อไร

**`summary` รวมยอดในฐานข้อมูล ไม่ดึงทุกแถวมารวมในแอป**
`GROUP BY` ที่ฐานข้อมูลแทนที่จะโหลด 200,000 แถวเข้าหน่วยความจำแล้ววนลูป

**`GET /expenses` มีค่าเริ่มต้นเป็น 30 วันล่าสุด และจำกัด `size` ไม่เกิน 100**
กันไม่ให้ client ที่ลืมใส่พารามิเตอร์ทำให้ระบบสแกนทั้งตาราง

**DTO แยกจาก entity**
client กำหนด `id` หรือ `createdAt` เองไม่ได้ ต่อให้ส่งมาใน body ก็ไม่มีผล

**error รายฟิลด์ ไม่ใช่ข้อความรวม**

```json
{
  "status": 400,
  "error": "Validation Failed",
  "message": "Request body failed validation",
  "fieldErrors": { "amount": "amount must be greater than 0" }
}
```

ทั้ง Angular และ Flutter อ่าน `fieldErrors` ไปแสดงตรงช่องที่ผิด

**`-XX:MaxRAMPercentage=75` แทน `-Xmx` ตายตัว**
JVM อ่านโควตาหน่วยความจำของคอนเทนเนอร์เอง ย้ายไปเครื่องขนาดอื่นไม่ต้องแก้ config

**CORS ระบุ origin เป็นรายการ ไม่ใช้ `*`**
`*` ใช้ร่วมกับ credentials ไม่ได้และเปิดกว้างเกินจำเป็น — origin ที่ไม่อยู่ในรายการได้ `403`

**หมวดที่ client ไม่รู้จักตกไปที่ `OTHER`**
ถ้า API เพิ่มหมวดใหม่ แอปเวอร์ชันเก่าที่ผู้ใช้ยังไม่อัปเดตจะไม่ crash

---

## สถานะปัจจุบัน

ทำงานได้ครบและทดสอบแล้วในเครื่อง ยังไม่ได้ deploy ขึ้น production

**ยังไม่มี** — ระบบยืนยันตัวตน (ข้อมูลทั้งหมดใช้ร่วมกัน),
export ข้อมูล, และการทดสอบโหลดจากเครื่องแยกต่างหาก

ตัวเลขในหัวข้อแรกวัดจากเครื่องพัฒนาเครื่องเดียวที่รันทั้ง JMeter, API และ PostgreSQL พร้อมกัน
จึงใช้ **เปรียบเทียบระหว่างสองเงื่อนไข** ได้ แต่ไม่ใช่ capacity จริงบนเซิร์ฟเวอร์
