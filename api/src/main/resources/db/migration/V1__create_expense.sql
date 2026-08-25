-- ตารางหลักของระบบบันทึกค่าใช้จ่าย
CREATE TABLE expense (
    id          UUID           PRIMARY KEY,
    amount      NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    category    VARCHAR(32)    NOT NULL,
    note        VARCHAR(255),
    spent_on    DATE           NOT NULL,
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- คิวรีที่ใช้บ่อยที่สุดคือ "ดูรายการช่วงวันที่ เรียงจากใหม่ไปเก่า"
-- ทำ index ให้ตรงกับ ORDER BY เพื่อไม่ต้อง sort ทีหลัง
CREATE INDEX idx_expense_spent_on_desc ON expense (spent_on DESC, id DESC);

-- หน้าสรุปกรองด้วย category ร่วมกับช่วงวันที่
CREATE INDEX idx_expense_category_spent_on ON expense (category, spent_on DESC);
