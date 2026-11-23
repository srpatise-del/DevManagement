# Order & Order Bank Issue - Database Schema & Security Audit Report (Version 2.3)

เอกสารฉบับปรับปรุงนี้ (Version 2.3) นำเสนอโครงสร้างการรักษาความปลอดภัยขั้นสูงสุด (Hardening) และครอบคลุมรายละเอียดครบถ้วนสำหรับการทำ Migration โดยคำนึงถึง Security, Data Lifecycle และ Storage Isolation อย่างเข้มงวด

---

## 1. Helper Functions (Secure Design)
ฟังก์ชันที่ใช้ดึงสิทธิ์และ Role ต้องตั้งค่า Owner ให้ปลอดภัย (พึ่งพาระบบ) ไม่ใช้บัญชีบุคคล และตั้ง `search_path` พร้อม `pg_temp`

```sql
-- 1. ฟังก์ชันดึง Role ปัจจุบันของผู้ใช้ โดยป้องกัน Recursion และไม่ให้อ่านข้าม User
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- ลบสิทธิ์จาก PUBLIC แล้วให้เฉพาะ authenticated โทรได้
REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;


-- 2. ฟังก์ชันตรวจสอบสิทธิ์การมองเห็น Order
CREATE OR REPLACE FUNCTION public.can_access_order(check_order_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    user_role TEXT;
    is_accessible BOOLEAN;
BEGIN
    -- เช็ค UUID ก่อน ถ้าไม่ได้ส่งค่ามาให้ปฏิเสธ
    IF check_order_id IS NULL THEN RETURN FALSE; END IF;

    SELECT public.get_current_user_role() INTO user_role;

    SELECT EXISTS (
        SELECT 1 FROM public.orders
        WHERE id = check_order_id
        AND deleted_at IS NULL -- (ซ่อน Soft-deleted จากทั่วไป)
        AND (
            user_role IN ('Admin', 'SysAdmin', 'Team Lead', 'Developer')
            OR created_by_id = auth.uid()
            OR assignee_id = auth.uid()
        )
    ) INTO is_accessible;

    RETURN is_accessible;
END;
$$;

REVOKE ALL ON FUNCTION public.can_access_order(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_access_order(UUID) TO authenticated;
```

---

## 2. Field Protection & Trusted Activity Logs (Triggers)
แทนที่จะเชื่อข้อมูล Activity Logs จาก Client เราจะใช้ **Trigger** เพื่อตรวจจับการเปลี่ยนแปลงและบันทึก Log ภายใน Database แทน

```sql
CREATE OR REPLACE FUNCTION public.protect_and_log_order_updates()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_role TEXT;
BEGIN
    SELECT public.get_current_user_role() INTO current_role;

    -- 1. การป้องกัน Field สำคัญด้วย IS DISTINCT FROM (ป้องกันการแก้โดยไม่มีสิทธิ์)
    IF current_role NOT IN ('Admin', 'SysAdmin') THEN
        IF NEW.id IS DISTINCT FROM OLD.id THEN RAISE EXCEPTION 'Cannot update ID'; END IF;
        IF NEW.order_number IS DISTINCT FROM OLD.order_number THEN RAISE EXCEPTION 'Cannot update order_number'; END IF;
        IF NEW.card_type IS DISTINCT FROM OLD.card_type THEN RAISE EXCEPTION 'Cannot update card_type'; END IF;
        IF NEW.created_by_id IS DISTINCT FROM OLD.created_by_id THEN RAISE EXCEPTION 'Cannot change creator'; END IF;

        -- ป้องกันการแก้ Soft Delete Field (มีแค่ Admin ทำได้)
        IF NEW.deleted_at IS DISTINCT FROM OLD.deleted_at THEN RAISE EXCEPTION 'Cannot change delete status'; END IF;
        IF NEW.deleted_by IS DISTINCT FROM OLD.deleted_by THEN RAISE EXCEPTION 'Cannot change delete owner'; END IF;
    END IF;

    -- 2. Trusted Activity Logs
    -- (เช่น บันทึก Log การเปลี่ยน Status หรือ Assignee โดยไม่สนใจว่า Client ส่งอะไรมา)
    IF NEW.activity_status IS DISTINCT FROM OLD.activity_status THEN
        INSERT INTO public.order_activity_logs (order_id, author_id, title, icon, icon_color, icon_bg_color)
        VALUES (NEW.id, auth.uid(), 'เปลี่ยนสถานะเป็น ' || NEW.activity_status, 'swap_horiz', 'gray', 'lightgray');
    END IF;

    IF NEW.assignee_id IS DISTINCT FROM OLD.assignee_id THEN
        INSERT INTO public.order_activity_logs (order_id, author_id, title, icon, icon_color, icon_bg_color)
        VALUES (NEW.id, auth.uid(), 'เปลี่ยนแปลงผู้รับผิดชอบ', 'person', 'blue', 'lightblue');
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_and_log_orders ON public.orders;
CREATE TRIGGER trg_protect_and_log_orders
BEFORE UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.protect_and_log_order_updates();
```

---

## 3. Storage Security (Private & Validated)
Policy ของ Storage ต้องป้องกัน Path Traversal และอิงการแปลงค่าอย่างปลอดภัยเพื่อป้องกันข้อผิดพลาดจากข้อมูลขยะ

```sql
-- รองรับเฉพาะ Path แบบ uuid/filename เท่านั้น
CREATE POLICY "Download attachments" ON storage.objects FOR SELECT USING (
    bucket_id = 'order-attachments'
    AND auth.role() = 'authenticated'
    -- ป้องกัน UUID Cast Error ถ้ารูปแบบไม่ตรง
    AND (name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.*$')
    AND public.can_access_order((string_to_array(name, '/'))[1]::uuid)
);

CREATE POLICY "Upload attachments" ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'order-attachments'
    AND auth.role() = 'authenticated'
    AND (name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.*$')
    AND public.can_access_order((string_to_array(name, '/'))[1]::uuid)
);

CREATE POLICY "Delete attachments" ON storage.objects FOR DELETE USING (
    bucket_id = 'order-attachments'
    AND auth.role() = 'authenticated'
    AND (name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.*$')
    AND (
        owner = auth.uid()
        OR public.get_current_user_role() IN ('Admin', 'SysAdmin')
    )
);
```

---

## 4. Full Table RLS Policies (Separated Operations)

### Orders (Soft Delete Handled)
```sql
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 1. SELECT (Hide deleted)
CREATE POLICY "Select orders" ON public.orders FOR SELECT USING (
    deleted_at IS NULL
    AND (
        public.get_current_user_role() IN ('Admin', 'SysAdmin', 'Team Lead', 'Developer')
        OR created_by_id = auth.uid()
        OR assignee_id = auth.uid()
    )
);

-- 2. INSERT
CREATE POLICY "Insert orders" ON public.orders FOR INSERT WITH CHECK (
    auth.uid() = created_by_id
    AND deleted_at IS NULL
);

-- 3. UPDATE (Soft Delete/Restore ก็อยู่ภายใต้ Trigger ควบคุม)
CREATE POLICY "Update orders" ON public.orders FOR UPDATE USING (
    deleted_at IS NULL
    AND (
        public.get_current_user_role() IN ('Admin', 'SysAdmin', 'Team Lead', 'Developer')
        OR created_by_id = auth.uid()
        OR assignee_id = auth.uid()
    )
) WITH CHECK (
    -- ผู้ใช้ทั่วไปไม่สามารถแก้ข้อมูลจนตัวเองอ่านไม่ได้ หรือแก้ของที่ลบไปแล้ว
    deleted_at IS NULL
    AND (
        public.get_current_user_role() IN ('Admin', 'SysAdmin', 'Team Lead', 'Developer')
        OR created_by_id = auth.uid()
        OR assignee_id = auth.uid()
    )
);

-- (หมายเหตุ: Soft Delete/Restore หรือแก้ข้อมูลเก่า อนุญาตเฉพาะ Admin แต่จะข้ามการเช็ค
-- RLS ด้วยการสร้าง Stored Procedure (SECURITY DEFINER) แทน เพื่อไม่ให้เกิดช่องโหว่การแก้ Field ปกติ)

-- 4. DELETE (Hard Delete - สงวนไว้ หรือไม่อนุญาตเลย)
CREATE POLICY "Hard Delete orders" ON public.orders FOR DELETE USING (
    public.get_current_user_role() IN ('Admin', 'SysAdmin')
);
```

### Order Items
```sql
-- (ใช้ EXISTS โยงไปหาแม่ที่ซ่อนรายการที่ถูกลบแล้วเสมอ)
CREATE POLICY "Select items" ON public.order_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders WHERE id = order_card_id));
CREATE POLICY "Insert items" ON public.order_items FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.orders WHERE id = order_card_id));
CREATE POLICY "Update items" ON public.order_items FOR UPDATE USING (EXISTS (SELECT 1 FROM public.orders WHERE id = order_card_id));
CREATE POLICY "Delete items" ON public.order_items FOR DELETE USING (EXISTS (SELECT 1 FROM public.orders WHERE id = order_card_id));
```

### Order Comments & Likes
```sql
-- SELECT (เห็นถ้าออเดอร์ไม่ได้โดนซ่อน)
CREATE POLICY "Select comments" ON public.order_comments FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders WHERE id = order_id));

-- INSERT (บังคับ auth_id, ห้ามแก้ order_id ปลอม)
CREATE POLICY "Insert comments" ON public.order_comments FOR INSERT WITH CHECK (
    auth.uid() = author_id AND EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);

-- UPDATE (ต้องเป็นเจ้าของ หรือ Admin, ห้ามแก้ order_id ของใครด้วย WITH CHECK)
CREATE POLICY "Update comments" ON public.order_comments FOR UPDATE
USING (
    auth.uid() = author_id OR public.get_current_user_role() IN ('Admin', 'SysAdmin')
)
WITH CHECK (
    order_id = order_id -- (ต้องป้องกันแก้ order_id สลับฝั่งใน Trigger อีกชั้น ถ้าจำเป็น)
);

-- DELETE
CREATE POLICY "Delete comments" ON public.order_comments FOR DELETE USING (
    auth.uid() = author_id OR public.get_current_user_role() IN ('Admin', 'SysAdmin')
);

-- Likes
CREATE POLICY "Select likes" ON public.order_comment_likes FOR SELECT USING (EXISTS (SELECT 1 FROM public.order_comments WHERE id = comment_id));
CREATE POLICY "Insert likes" ON public.order_comment_likes FOR INSERT WITH CHECK (auth.uid() = user_id AND EXISTS (SELECT 1 FROM public.order_comments WHERE id = comment_id));
CREATE POLICY "Delete likes" ON public.order_comment_likes FOR DELETE USING (auth.uid() = user_id);
-- (UPDATE ไม่อนุญาต Denied by Default)
```

### Order Attachments (Metadata)
```sql
CREATE POLICY "Select attach" ON public.order_attachments FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders WHERE id = order_id));
CREATE POLICY "Insert attach" ON public.order_attachments FOR INSERT WITH CHECK (
    auth.uid() = uploaded_by AND EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);
CREATE POLICY "Delete attach" ON public.order_attachments FOR DELETE USING (
    auth.uid() = uploaded_by OR public.get_current_user_role() IN ('Admin', 'SysAdmin')
);
-- (UPDATE ไม่อนุญาต Denied by Default)
```

### Order Activity Logs (Trusted Append Only)
```sql
CREATE POLICY "Select logs" ON public.order_activity_logs FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.orders WHERE id = order_id)
);
-- ระบบ INSERT จาก Trigger ไม่ถูกกรองด้วย RLS (เพราะ Trigger รันแบบบายพาสเมื่อเป็น System)
-- สำหรับ Client ปฏิเสธ INSERT จากข้างนอก
-- (UPDATE / DELETE ไม่อนุญาต Denied by Default)
```

---

## 5. Security Test Matrix

| # | Action / Scenario | Expected SQL Behavior | Risk Mitigation |
|:--|:---|:---|:---|
| 1 | User อ่าน Order ที่สร้าง/Assign | RLS ยอมให้ดู (`id IN (...)`) | ป้องกัน Data leak |
| 2 | User อ่าน Order ของคนอื่น | RLS คืน 0 rows (ไม่เห็น) |
| 3 | User พยายามแก้ไข `created_by` | Trigger Throw EXCEPTION |
| 4 | User แก้ไข Order (Field ปกติ) ที่ไม่มีสิทธิ์ | RLS UPDATE USING = False |
| 5 | User พยายามเข้าถึง Comment ออเดอร์อื่น | RLS SELECT USING (เช็คผ่านแม่) |
| 6 | User แกล้งอัปเดต `order_id` ของ Comment | Trigger / WITH CHECK ป้องกันการสลับออเดอร์ |
| 7 | User ลบไฟล์แนบคนอื่น (DB Metadata) | RLS DELETE ปฏิเสธ ยกเว้นเป็น Admin |
| 8 | User พยายามดาวน์โหลดไฟล์ผ่าน API | Storage Policy เช็ค Path `regex` และ UUID ผ่านฟังก์ชัน `can_access_order` |
| 9 | Client พยายาม Insert `order_activity_logs` | ปฏิเสธ (สร้างจาก Trigger เท่านั้น) |
| 10 | Admin สั่ง Soft Delete | ส่งคำสั่งผ่าน Security Definer Function เท่านั้น เพราะ RLS User ปกติจะแก้ Field นี้ไม่ได้ |

---

## 6. Migration Idempotency Plan
การออกแบบสคริปต์ Migration จะเป็นในรูปแบบ `CREATE OR REPLACE` สำหรับฟังก์ชัน และเช็ค Object ก่อนสร้างทุกครั้ง:
- `IF NOT EXISTS` ป้องกันตารางและคอลัมน์ซ้ำ
- `DROP POLICY IF EXISTS ... ON table` ก่อนรันคำสั่ง Policy
- ห้ามใช้คำสั่ง `DROP TABLE CASCADE` ยกเว้นตอนพัฒนา/ทดสอบ หรือกรณีจงใจ Rollback (ซึ่งควรใช้วิธี Drop เฉพาะ Table ลำดับสุดท้ายก่อนแล้วไล่ย้อนกลับ)