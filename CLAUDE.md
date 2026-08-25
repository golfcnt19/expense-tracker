# CLAUDE.md

บริบทของโปรเจคนี้ อ่านก่อนแก้อะไร

## นี่คืออะไร

โปรเจคโชว์ฝีมือสำหรับพอร์ตโฟลิโอ — REST API หนึ่งตัว ต่อด้วย client สองแบบ พร้อม load test ที่วัดผลจริง
เจ้าของเป็น software engineer 12 ปี ที่งานบริษัทเอามาโชว์ไม่ได้เพราะ NDA จึงสร้างตัวนี้ขึ้นมาแทน

**จุดขายคือตัวเลข 13.8×** ที่วัดผลของ index ด้วย JMeter — อย่าแก้อะไรที่ทำให้ตัวเลขนี้เล่าไม่ได้
ถ้าเปลี่ยน index หรือคิวรี ต้องรัน load test ใหม่แล้วอัปเดต `loadtest/README.md` ด้วย

## รันในเครื่อง

ต้องมี JDK 25, Node 24, Flutter 3.47, PostgreSQL 18 — ดูรายละเอียดใน [README.md](README.md)

```bash
cd api && ./mvnw spring-boot:run      # :8080
cd web && npm start                    # :4200 มี proxy ไป 8080
```

Postgres ในเครื่องต้องสั่งสตาร์ทเอง

```bash
C:\Users\USER\tools\pgsql\bin\pg_ctl.exe -D C:\Users\USER\tools\pgdata start
```

## ข้อตกลงที่ห้ามพัง

**Flyway เป็นเจ้าของ schema · `ddl-auto=validate`** — เปลี่ยนโครงสร้างต้องเขียนไฟล์ migration ใหม่
ห้ามให้ Hibernate สร้างตารางเอง

**เพิ่ม/แก้อะไรต้องทำครบทั้งสาม** — API, `web/`, `mobile/`
ทั้งสอง client ต้องมีความสามารถเท่ากัน (เพิ่ม/แก้/ลบ/กรอง/สรุป) ต่างได้แค่วิธีนำเสนอตามอุปกรณ์

**เทสต์รันกับ PostgreSQL จริง ไม่ใช่ H2** ทั้งในเครื่องและใน CI
ถ้าเปลี่ยนไปใช้ in-memory จะไม่จับปัญหาที่เกิดเฉพาะ Postgres

**`api/mvnw` ต้องมีสิทธิ์ execute ใน git** ถ้าเผลอทำหาย CI บน Linux จะพัง

```bash
git update-index --chmod=+x api/mvnw
```

## สภาพแวดล้อม

- Windows, PowerShell 5.1 (ไม่มี `&&`) — บัญชีนี้**ไม่ใช่ admin ลง Docker/WSL ไม่ได้**
- container image จึง build ใน GitHub Actions เท่านั้น ทดสอบในเครื่องไม่ได้
- JMeter 5.6.3 ใช้ Groovy บน JDK 25 ไม่ได้ — test plan ใช้ฟังก์ชันในตัวแทน อย่าเปลี่ยนกลับ

## Deploy

ออนไลน์อยู่แล้ว ดู [DEPLOY.md](DEPLOY.md) — API บน Render, ฐานข้อมูลบน Neon, client บน GitHub Pages

**อย่าเดา URL ของ API** ชื่อจริงมีตัวอักษรสุ่มต่อท้าย ดูใน repo variable `API_BASE`

CORS อนุญาตเฉพาะ origin ของ Pages — ยิงจาก localhost ไปหา API บน Render จะโดน 403

## ที่ยังไม่มี

auth (ใครรู้ URL ก็แก้ข้อมูลได้), export, field วิธีจ่าย (คุยไว้แล้วว่าจะทำทีหลัง),
load test จากเครื่องแยก
