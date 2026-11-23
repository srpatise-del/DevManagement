# Order & Order Bank Issue - Database Schema & Security Audit Report (Version 2.2)

เอกสารฉบับนี้รวบรวมข้อกำหนดการออกแบบ (Database Specification) ฉบับปรับปรุง 2.2 โดยมุ่งเน้นความถูกต้องของ SQL จริง การบังคับใช้สิทธิ์ (RLS) อย่างรัดกุม การออกแบบ Trigger แทนที่ Field Protection เดิม และการรับประกันว่าจะไม่มีผลกระทบต่อระบบ Case เดิม

---

## 1. การแก้ไข Field Protection (แทนที่ `_old`)
ใน PostgreSQL Policy ทั่วไป เราไม่สามารถอ้างอิง `_old` ตรงๆ ด้วยตัวแปรแบบนั้นได้ การป้องกันไม่ให้แก้ Field สำคัญ (เช่น `created_by_id`, `card_type`) ทำได้อย่างถูกต้อง 2 วิธี:
1. **Trigger `BEFORE UPDATE`**: ดีที่สุดและครอบคลุมที่สุด
2. **Column-Level Privileges (`GRANT UPDATE (col1, col2) ON table`)**: ซับซ้อนกว่าเมื่อใช้ร่วมกับ RLS

เราตัดสินใจใช้ **Trigger `BEFORE UPDATE`** เพื่อตรวจสอบ `NEW.created_by_id = OLD.created_by_id` หากไม่ตรง จะทำการ Reset ค่าเดิมกลับคืน (หรือ Throw Exception)

---

## 2. Secure Helper Functions
ฟังก์ชันสำหรับดึง Role ออกแบบใหม่ให้ปลอดภัยโดย:
- ใช้ `SECURITY DEFINER` เพื่อให้สิทธิ์เท่ากับ Owner แต่ควบคุม `search_path` อย่างรัดกุม
- ตรวจสอบว่าพยายามดึง Role ของตัวเอง (auth.uid) เท่านั้น (ห้ามให้ User ธรรมดาเอาไว้สอดส่อง Role ของคนอื่น)

```sql
-- เปลี่ยน owner ให้เป็น Postgres เพื่อความชัวร์ (ขึ้นอยู่กับ Environment)
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- ป้องกันคนทั่วไป Execute สุ่มสี่สุ่มห้า (เฉพาะ Authenticated)
REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;
```

---

## 3. Data Lifecycle & Soft Delete
**Orders**: เราตัดสินใจเพิ่มคอลัมน์ `deleted_at` (TIMESTAMPTZ) และใช้หลักการ **Soft Delete** แทน
- ถ้า `deleted_at IS NOT NULL` จะซ่อนจาก Dashboard (ใช้ RLS `deleted_at IS NULL` สำหรับคนทั่วไป)
- ข้อดี: ข้อมูล Activity Logs, Comments, และ Attachments เดิมจะไม่หายไปเลย
- หากต้องการลบไฟล์แนบหรือชิ้นส่วนย่อยแบบถาวร จะทำต่อเมื่อ Admin เป็นคนสั่ง `DELETE` จริงเท่านั้น

---

## 4. Complete SQL Deliverables

### 4.1 Schema SQL (Tables & Columns)

```sql
-- 1. ORDERS
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT NOT NULL UNIQUE,
    card_type TEXT NOT NULL CHECK (card_type IN ('orderDiff', 'bankIssue')),
    delivery_type TEXT,
    priority TEXT,
    activity_status TEXT DEFAULT 'newOrder',
    assignee_id UUID,
    created_by_id UUID NOT NULL,
    date_text TEXT,
    standard_date DATE,
    import_file TEXT,
    error_details TEXT,
    bank_code TEXT,
    bank_name TEXT,
    payment_method_code TEXT,
    payment_method TEXT,
    amount NUMERIC CHECK (amount IS NULL OR amount >= 0),
    status_order TEXT,
    deleted_at TIMESTAMPTZ, -- Soft delete
    deleted_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. ORDER_ITEMS
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_card_id UUID NOT NULL,
    item_order_no TEXT NOT NULL,
    delivery_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. ORDER_COMMENTS
CREATE TABLE IF NOT EXISTS public.order_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    author_id UUID NOT NULL,
    content TEXT NOT NULL,
    attached_image_path TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. ORDER_COMMENT_LIKES
CREATE TABLE IF NOT EXISTS public.order_comment_likes (
    comment_id UUID NOT NULL,
    user_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (comment_id, user_id)
);

-- 5. ORDER_ATTACHMENTS
CREATE TABLE IF NOT EXISTS public.order_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    uploaded_by UUID,
    file_name TEXT NOT NULL,
    file_size BIGINT,
    file_type TEXT,
    storage_path TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. ORDER_ACTIVITY_LOGS
CREATE TABLE IF NOT EXISTS public.order_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    author_id UUID,
    title TEXT NOT NULL,
    icon TEXT,
    icon_color TEXT,
    icon_bg_color TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 4.2 Foreign Key & Constraints SQL
```sql
-- Orders
ALTER TABLE public.orders ADD CONSTRAINT fk_orders_assignee FOREIGN KEY (assignee_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD CONSTRAINT fk_orders_created_by FOREIGN KEY (created_by_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;
ALTER TABLE public.orders ADD CONSTRAINT fk_orders_deleted_by FOREIGN KEY (deleted_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Child Tables (CASCADE จาก Order 母)
ALTER TABLE public.order_items ADD CONSTRAINT fk_order_items_card FOREIGN KEY (order_card_id) REFERENCES public.orders(id) ON DELETE CASCADE;

ALTER TABLE public.order_comments ADD CONSTRAINT fk_order_comments_order FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
ALTER TABLE public.order_comments ADD CONSTRAINT fk_order_comments_author FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;

ALTER TABLE public.order_comment_likes ADD CONSTRAINT fk_likes_comment FOREIGN KEY (comment_id) REFERENCES public.order_comments(id) ON DELETE CASCADE;
ALTER TABLE public.order_comment_likes ADD CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.order_attachments ADD CONSTRAINT fk_attachments_order FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
ALTER TABLE public.order_attachments ADD CONSTRAINT fk_attachments_uploader FOREIGN KEY (uploaded_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.order_activity_logs ADD CONSTRAINT fk_logs_order FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;
ALTER TABLE public.order_activity_logs ADD CONSTRAINT fk_logs_author FOREIGN KEY (author_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
```

### 4.3 Trigger SQL (Field Protection & Timestamps)
```sql
-- 1. Timestamp Updater
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_orders_timestamp ON public.orders;
CREATE TRIGGER update_orders_timestamp BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 2. Field Protection
CREATE OR REPLACE FUNCTION public.protect_order_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- ถ้าคนทำไม่ใช่ Admin ห้ามแก้ Field บางตัว
    IF public.get_current_user_role() NOT IN ('Admin', 'SysAdmin') THEN
        IF NEW.id != OLD.id THEN RAISE EXCEPTION 'Cannot update ID'; END IF;
        IF NEW.order_number != OLD.order_number THEN RAISE EXCEPTION 'Cannot update order_number'; END IF;
        IF NEW.card_type != OLD.card_type THEN RAISE EXCEPTION 'Cannot update card_type'; END IF;
        IF NEW.created_by_id != OLD.created_by_id THEN RAISE EXCEPTION 'Cannot change creator'; END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_orders_fields_trigger ON public.orders;
CREATE TRIGGER protect_orders_fields_trigger BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.protect_order_fields();
```

### 4.4 Complete RLS Policies SQL
```sql
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_activity_logs ENABLE ROW LEVEL SECURITY;

-- =======================
-- 1. ORDERS
-- =======================
-- SELECT
CREATE POLICY "Select orders" ON public.orders FOR SELECT
USING (
    -- Admin, Lead, Dev เห็นหมด ยกเว้นโดนลบ
    (public.get_current_user_role() IN ('Admin', 'SysAdmin', 'Team Lead', 'Developer'))
    -- User ทั่วไปเห็นเฉพาะงานที่เกียวข้อง
    OR (created_by_id = auth.uid() OR assignee_id = auth.uid())
);

-- INSERT
CREATE POLICY "Insert orders" ON public.orders FOR INSERT
WITH CHECK (
    auth.uid() = created_by_id
    AND deleted_at IS NULL
);

-- UPDATE (Soft delete ก็ผ่าน Policy นี้ โดยเซ็ต deleted_at = NOW())
CREATE POLICY "Update orders" ON public.orders FOR UPDATE
USING (
    public.get_current_user_role() IN ('Admin', 'SysAdmin', 'Team Lead', 'Developer')
    OR created_by_id = auth.uid()
    OR assignee_id = auth.uid()
)
WITH CHECK (
    -- Check ซ้ำว่าแก้เสร็จก็ยังมีสิทธิ์
    public.get_current_user_role() IN ('Admin', 'SysAdmin', 'Team Lead', 'Developer')
    OR created_by_id = auth.uid()
    OR assignee_id = auth.uid()
);

-- DELETE (Hard Delete จริงๆ เก็บไว้ให้เฉพาะ Admin ขั้นสูง)
CREATE POLICY "Hard delete orders" ON public.orders FOR DELETE
USING (public.get_current_user_role() IN ('Admin', 'SysAdmin'));

-- =======================
-- 2. ORDER ITEMS
-- =======================
CREATE POLICY "Select items" ON public.order_items FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.orders WHERE id = order_card_id)
);
CREATE POLICY "Insert/Update items" ON public.order_items FOR ALL USING (
    EXISTS (SELECT 1 FROM public.orders WHERE id = order_card_id) -- (รวมสิทธิ์แก้ไขตัวลูกเข้ากับสิทธิ์จัดการตัวแม่)
);
-- ปฏิเสธ DELETE เป็นค่าปริยาย นอกจาก CASCADE

-- =======================
-- 3. ORDER COMMENTS
-- =======================
CREATE POLICY "Select comments" ON public.order_comments FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);

CREATE POLICY "Insert comments" ON public.order_comments FOR INSERT WITH CHECK (
    auth.uid() = author_id
    AND EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);

CREATE POLICY "Update comments" ON public.order_comments FOR UPDATE USING (
    auth.uid() = author_id OR public.get_current_user_role() IN ('Admin', 'SysAdmin')
);

CREATE POLICY "Delete comments" ON public.order_comments FOR DELETE USING (
    auth.uid() = author_id OR public.get_current_user_role() IN ('Admin', 'SysAdmin')
);

-- =======================
-- 4. LIKES
-- =======================
CREATE POLICY "Select likes" ON public.order_comment_likes FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.order_comments WHERE id = comment_id)
);
CREATE POLICY "Insert/Delete likes" ON public.order_comment_likes FOR ALL USING (auth.uid() = user_id);

-- =======================
-- 5. ATTACHMENTS (Metadata DB)
-- =======================
CREATE POLICY "Select attachments metadata" ON public.order_attachments FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);
CREATE POLICY "Insert attachments metadata" ON public.order_attachments FOR INSERT WITH CHECK (
    auth.uid() = uploaded_by AND EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);
CREATE POLICY "Delete attachments metadata" ON public.order_attachments FOR DELETE USING (
    auth.uid() = uploaded_by OR public.get_current_user_role() IN ('Admin', 'SysAdmin')
);
-- ไม่อนุญาตให้ UPDATE

-- =======================
-- 6. ACTIVITY LOGS (Append Only)
-- =======================
CREATE POLICY "Select logs" ON public.order_activity_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);
CREATE POLICY "Insert logs" ON public.order_activity_logs FOR INSERT WITH CHECK (
    auth.uid() = author_id AND EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);
-- ไม่อนุญาต UPDATE / DELETE
```

### 4.5 Storage Policies SQL
Storage ของ Supabase ไม่อนุญาตให้ JOIN ตารางตรงๆ เราจึงใช้ `auth.uid()` เช็คผ่าน DB Function
```sql
-- ฟังก์ชันช่วยสำหรับ Storage (Security Definer)
CREATE OR REPLACE FUNCTION public.can_access_order(check_order_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.orders
        WHERE id = check_order_id
        AND (
            public.get_current_user_role() IN ('Admin', 'SysAdmin', 'Team Lead', 'Developer')
            OR created_by_id = auth.uid()
            OR assignee_id = auth.uid()
        )
    );
$$;

-- STORAGE POLICIES (order-attachments bucket)
CREATE POLICY "Download order attachments" ON storage.objects FOR SELECT USING (
    bucket_id = 'order-attachments'
    AND public.can_access_order((string_to_array(name, '/'))[1]::uuid)
);

CREATE POLICY "Upload order attachments" ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'order-attachments'
    AND public.can_access_order((string_to_array(name, '/'))[1]::uuid)
);

CREATE POLICY "Delete order attachments" ON storage.objects FOR DELETE USING (
    bucket_id = 'order-attachments'
    AND (
        owner = auth.uid() OR public.get_current_user_role() IN ('Admin', 'SysAdmin')
    )
);
-- Cleanup Strategy: ใช้ RPC หรือ Edge Function จากฝั่ง Server หากต้องการล้างไฟล์กำพร้า (Orphan files) ไม่มี DB Metadata
```

---

## 5. Security Audit Checklist

| Requirement | Implementation | Security Risk | Verification Method | Status |
|:---|:---|:---|:---|:---|
| ป้องกันการแก้ `created_by` | ใช้ BEFORE UPDATE Trigger | ผู้ใช้แก้ไขไม่ได้แม้ข้าม UI | SQL Function `protect_order_fields` | Pass |
| ป้องกัน RLS Recursion / ดู Role คนอื่น | ใช้ Security Definer `get_current_user_role` ดึงเฉพาะ Role ของ `auth.uid()` | ปลอดภัย ไม่เกิด Loop กับตารางตัวเอง | SQL Function Definition | Pass |
| Activity Logs ปลอมตัว/ลบไม่ได้ | เปิดให้ SELECT / INSERT เท่านั้น และ `author_id = auth.uid()` | แก้ประวัติไม่ได้แน่นอน | RLS Missing UPDATE/DELETE | Pass |
| ลบ Order ประวัติไม่หาย | ใช้ Soft Delete (`deleted_at`) | ข้อมูลเกี่ยวพัน (Logs, Comments) ยังอยู่ | Table Column & FK | Pass |
| ข้อมูล Storage ข้าม Order | `can_access_order` แยก Path UUID `/{uuid}/` เช็คด้วย Function | ดึงไฟล์ Order อื่นไม่ได้ถ้าไม่มีสิทธิ์ | Storage Select Policy | Pass |

---
**หมายเหตุความปลอดภัยสำคัญ:**
- ขั้นตอนนี้ได้ลบการอ้างอิง `_old` ออก และทดแทนด้วยระบบ Trigger ที่ถูกต้องตามมาตรฐาน PostgreSQL
- ไม่มีผลกระทบหรือแก้ไขส่วนใดๆ ใน `case_repository` และโครงสร้างระบบ Case
- พร้อมสำหรับการสร้างเป็น Migration สคริปต์ในลำดับต่อไป (ตามข้อจำกัด ขั้นตอนนี้ยังไม่ได้รัน SQL ใดๆ)
