# Final Security Specification — Version 2.6
## Complete Orchestration, Idempotency & RLS Cleanup Blueprint

*Status: AUDIT & SPECIFICATION ONLY*
*Version: 2.6 (Strict Isolation, Validation & Edge Verification)*

## 1. Executive Summary
เอกสารนี้คือ **Final Implementation Blueprint Version 2.6** สำหรับระบบ File Attachments ของโปรเจกต์ DevCase มุ่งเน้นการแก้ไขสถาปัตยกรรมระดับลึกตามการ Audit ล่าสุด ดังนี้:
1. **Safe Migration:** รองรับทั้งตารางใหม่/เก่า และคอลัมน์ที่มีอยู่แล้วโดยไม่ทำข้อมูลเดิมสูญหาย
2. **Permission Segregation:** แยก Internal Helper ออกจาก Public-facing RPC Wrapper อย่างเด็ดขาด พร้อมจัดการ GRANT/REVOKE อย่างรัดกุม
3. **Storage Helper Rigor:** ผสานการตรวจ Path, Parent Record, Comment ID และ Metadata อย่างครบถ้วนทุก Action
4. **Backend-Verified Upload:** ย้ายขั้นตอนการ Confirm Upload ไปยัง Backend (Edge Function) โดยต้องใช้ Admin API ตรวจสอบ Object จริงบน Storage เสมอ
5. **Delete Idempotency Auth:** สลับลำดับให้ตรวจสิทธิ์ Authorization ก่อนที่จะคืนค่า Idempotency เพื่อไม่ให้ผู้ไม่มีสิทธิ์สามารถสอดแนมสถานะการลบได้
6. **Permissive RLS Eradication:** ล้างบาง Policy เก่าที่เป็นแบบ "Permissive (OR)" อย่างถูกวิธี เพราะการเพิ่ม Deny Policy ไม่สามารถหักล้าง Permissive Policy เดิมได้
7. **Robust Test Matrix:** ขยายขอบเขตการทดสอบครอบคลุม Normal Cases, Attack Vectors, และ System Failures

สถานะของเอกสารคือ **Audit & Specification Only** จุดที่ยังไม่ได้รันบนฐานข้อมูลจริงถูกระบุด้วย `[UNVERIFIED]` หรือ `[BLOCKED]`

---

## 2. Safe Database Migration Plan
ออกแบบ Migration Script ที่สามารถรันซ้ำได้ (Idempotent) ตรวจสอบและรองรับทั้ง Schema เก่าและใหม่ `[DESIGNED]`

```sql
DO $$ 
BEGIN
    -- 1. Create UNIQUE constraint for comments safely
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_case_comments_id_case') THEN
        ALTER TABLE public.case_comments ADD CONSTRAINT uq_case_comments_id_case UNIQUE (id, case_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_order_comments_id_order') THEN
        -- [BLOCKED] Requires orders table to be migrated first
        -- ALTER TABLE public.order_comments ADD CONSTRAINT uq_order_comments_id_order UNIQUE (id, order_id);
    END IF;

    -- 2. Migrate existing case_attachments securely without data loss
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='case_attachments' AND column_name='comment_id') THEN
        ALTER TABLE public.case_attachments ADD COLUMN comment_id UUID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='case_attachments' AND column_name='status') THEN
        ALTER TABLE public.case_attachments ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'PENDING';
        -- Update existing legacy files to ACTIVE to prevent breakage
        UPDATE public.case_attachments SET status = 'ACTIVE' WHERE status = 'PENDING';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='case_attachments' AND column_name='expires_at') THEN
        ALTER TABLE public.case_attachments ADD COLUMN expires_at TIMESTAMPTZ;
    END IF;

    -- 3. Apply Constraints carefully
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_case_att_status') THEN
        ALTER TABLE public.case_attachments ADD CONSTRAINT chk_case_att_status CHECK (status IN ('PENDING', 'ACTIVE', 'DELETE_PENDING', 'METADATA_CLEANED', 'FAILED'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_case_att_file_size') THEN
        ALTER TABLE public.case_attachments ADD CONSTRAINT chk_case_att_file_size CHECK (file_size > 0 AND file_size <= 52428800);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_case_storage_path') THEN
        ALTER TABLE public.case_attachments ADD CONSTRAINT uq_case_storage_path UNIQUE (storage_path);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_case_comments_composite') THEN
        ALTER TABLE public.case_attachments ADD CONSTRAINT fk_case_comments_composite FOREIGN KEY (comment_id, case_id) REFERENCES public.case_comments(id, case_id) ON DELETE CASCADE;
    END IF;
END $$;
```

---

## 3. Strict Permission Segregation
### 3.1 Internal Base Permission
ฟังก์ชันจัดการ Logic ภายใน ฐานข้อมูลเท่านั้น ห้ามเรียกจาก Client `[DESIGNED]`

```sql
CREATE OR REPLACE FUNCTION public.devc_internal_case_permission(p_user_id UUID, p_case_id UUID, p_action TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role TEXT;
  v_team_id UUID;
  v_case_created_by UUID;
  v_case_assignee_id UUID;
  v_case_team_id UUID;
BEGIN
  IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN RETURN FALSE; END IF;
  IF p_action NOT IN ('READ', 'UPLOAD') THEN RETURN FALSE; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id) THEN RETURN FALSE; END IF;
  
  SELECT created_by, assignee_id, team_id INTO v_case_created_by, v_case_assignee_id, v_case_team_id FROM public.cases WHERE id = p_case_id;
  SELECT role, team_id INTO v_role, v_team_id FROM public.profiles WHERE id = p_user_id AND is_active = true;
  IF v_role IS NULL THEN RETURN FALSE; END IF;
  IF v_role = 'admin' THEN RETURN TRUE; END IF;
  
  IF p_action = 'READ' THEN
    IF v_role = 'team_lead' AND v_team_id = v_case_team_id THEN RETURN TRUE; END IF;
    IF v_role = 'developer' AND (v_team_id = v_case_team_id OR v_case_assignee_id = p_user_id) THEN RETURN TRUE; END IF;
    IF v_role = 'user' AND (v_case_created_by = p_user_id OR v_case_assignee_id = p_user_id) THEN RETURN TRUE; END IF;
    IF EXISTS (SELECT 1 FROM public.case_comments WHERE case_id = p_case_id AND author_id = p_user_id) THEN RETURN TRUE; END IF;
  END IF;

  IF p_action = 'UPLOAD' THEN
    IF v_role = 'team_lead' AND v_team_id = v_case_team_id THEN RETURN TRUE; END IF;
    IF v_role = 'developer' AND (v_team_id = v_case_team_id OR v_case_assignee_id = p_user_id) THEN RETURN TRUE; END IF;
    IF v_role = 'user' AND v_case_created_by = p_user_id THEN RETURN TRUE; END IF;
  END IF;

  RETURN FALSE;
END;
$$;
-- [STRICT GRANT]
REVOKE ALL ON FUNCTION public.devc_internal_case_permission(UUID, UUID, TEXT) FROM PUBLIC, anon, authenticated;
```

### 3.2 Storage Helper (Public-facing Wrapper for RLS)
รับประกันการตรวจ `comment_id`, Path, และ Expiration แบบครบวงจร `[DESIGNED]`

```sql
CREATE OR REPLACE FUNCTION public.devc_can_access_case_storage(p_path TEXT, p_action TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_parts TEXT[];
  v_case_id UUID;
  v_comment_id UUID := NULL;
  v_meta_status TEXT;
  v_meta_uploader UUID;
  v_expires_at TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL OR p_action NOT IN ('READ', 'UPLOAD') THEN RETURN FALSE; END IF;

  -- 1. Canonical Verification
  IF position('..' IN p_path)>0 OR position('//' IN p_path)>0 OR position('%' IN p_path)>0 OR position('\' IN p_path)>0 THEN RETURN FALSE; END IF;

  v_parts := storage.foldername(p_path);
  IF storage.filename(p_path) IS NULL OR storage.filename(p_path) = '' THEN RETURN FALSE; END IF;

  IF array_length(v_parts, 1) = 3 AND v_parts[1] = 'cases' AND v_parts[3] = 'main' THEN
    BEGIN v_case_id := v_parts[2]::UUID; EXCEPTION WHEN others THEN RETURN FALSE; END;
  ELSIF array_length(v_parts, 1) = 4 AND v_parts[1] = 'cases' AND v_parts[3] = 'comments' THEN
    BEGIN v_case_id := v_parts[2]::UUID; v_comment_id := v_parts[4]::UUID; EXCEPTION WHEN others THEN RETURN FALSE; END;
  ELSE RETURN FALSE; END IF;

  -- 2. Metadata Consistency Verification (IS NOT DISTINCT FROM is crucial for NULL matching)
  IF p_action = 'READ' THEN
    SELECT status INTO v_meta_status FROM public.case_attachments 
    WHERE storage_path = p_path 
      AND case_id = v_case_id 
      AND comment_id IS NOT DISTINCT FROM v_comment_id 
    LIMIT 1;
    IF v_meta_status IS NULL OR v_meta_status NOT IN ('ACTIVE', 'COMPLETED') THEN RETURN FALSE; END IF;
    RETURN public.devc_internal_case_permission(v_user_id, v_case_id, 'READ');
  END IF;

  IF p_action = 'UPLOAD' THEN
    SELECT status, uploaded_by, expires_at INTO v_meta_status, v_meta_uploader, v_expires_at 
    FROM public.case_attachments 
    WHERE storage_path = p_path 
      AND case_id = v_case_id 
      AND comment_id IS NOT DISTINCT FROM v_comment_id 
    LIMIT 1;
    
    IF v_meta_status IS NULL OR v_meta_status <> 'PENDING' THEN RETURN FALSE; END IF;
    IF v_meta_uploader IS DISTINCT FROM v_user_id THEN RETURN FALSE; END IF;
    IF v_expires_at IS NULL OR clock_timestamp() > v_expires_at THEN RETURN FALSE; END IF;
    
    RETURN public.devc_internal_case_permission(v_user_id, v_case_id, 'UPLOAD');
  END IF;
  
  RETURN FALSE;
END;
$$;
-- [WRAPPER GRANT]
REVOKE ALL ON FUNCTION public.devc_can_access_case_storage(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.devc_can_access_case_storage(TEXT, TEXT) TO authenticated;
```
*(Order Helper จะมีโครงสร้างเหมือนกันแต่ล้อมด้วย `IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders')`)*

---

## 4. Backend-Verified Upload Lifecycle
ยกเลิกการให้ Client สรุปผลการอัปโหลด เปลี่ยนเป็นตรวจสอบความจริงที่ Storage Object `[DESIGNED]`

1. **Client -> DB:** ยิง RPC `rpc_create_upload_intent` สร้าง Metadata `status='PENDING'`, `expires=15m`
2. **Client -> Storage:** อัปโหลดไฟล์ด้วย SDK (Supabase RLS อนุญาตเพราะตรง Intent)
3. **Client -> Edge Function:** ยิง HTTP Request แจ้ง Backend `confirm_upload(path)`
4. **Edge Function (Service Role) -> Storage API:** Backend ใช้ Admin SDK สั่ง `storage.from('case-attachments').info(path)`
5. **Backend Verification:**
   - ถ้า Backend ไม่พบ Object (404) หรือ Size = 0 -> ปฏิเสธการ Confirm 
   - ถ้าพบ Object จริง -> Backend ใช้ Service Role ยิง UPDATE Metadata เปลี่ยนจาก `PENDING` เป็น `ACTIVE`
*(หมายเหตุ: กระบวนการนี้ลบ `rpc_confirm_upload` จาก Database ฝั่ง Public ออกถาวร)*

---

## 5. Delete Orchestrator: Idempotency & Auth Fix
แก้ไขลำดับให้ตรวจสอบสิทธิ์ **ก่อน** ที่จะตอบกลับ Idempotent เพื่อไม่ให้แฮกเกอร์เช็คสถานะการลบของไฟล์คนอื่น `[DESIGNED]`

```sql
CREATE OR REPLACE FUNCTION public.rpc_request_delete(p_path TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_role TEXT;
  v_case_id UUID;
  v_uploader UUID;
  v_current_status TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  
  -- 1. Validate Profile & Retrieve Role
  SELECT role INTO v_role FROM public.profiles WHERE id = v_user_id AND is_active = true;
  IF v_role IS NULL THEN RAISE EXCEPTION 'Profile inactive or invalid'; END IF;
  
  -- 2. Lock Row for Concurrency
  SELECT case_id, uploaded_by, status INTO v_case_id, v_uploader, v_current_status
  FROM public.case_attachments WHERE storage_path = p_path
  FOR UPDATE SKIP LOCKED;
  IF NOT FOUND THEN RAISE EXCEPTION 'File metadata not found or already processing'; END IF;
  
  -- 3. Authorize BEFORE Idempotency Check (CRITICAL FIX)
  IF NOT public.devc_internal_case_permission(v_user_id, v_case_id, 'READ') THEN 
    RAISE EXCEPTION 'Permission Denied: Parent inaccessible'; 
  END IF;
  IF v_role <> 'admin' AND v_uploader IS DISTINCT FROM v_user_id THEN 
    RAISE EXCEPTION 'Permission Denied: Only uploader or Admin can delete'; 
  END IF;

  -- 4. Idempotency Return (Safe to return TRUE now since user is authorized)
  IF v_current_status IN ('DELETE_PENDING', 'METADATA_CLEANED', 'STORAGE_DELETED') THEN 
    RETURN TRUE; 
  END IF;

  -- 5. Commit Intent
  UPDATE public.case_attachments SET status = 'DELETE_PENDING' WHERE storage_path = p_path;
  RETURN TRUE;
END;
$$;
-- [RPC GRANT]
REVOKE ALL ON FUNCTION public.rpc_request_delete(TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_request_delete(TEXT) TO authenticated;
```
*(Backend Cron Job คอยวนหา `DELETE_PENDING` ใช้ Service Role ลบ Storage และปรับ Metadata เป็น `METADATA_CLEANED`)*

---

## 6. Permissive RLS Cleanup & Lockdown
ล้าง Policy เก่าที่เป็น `OR` ออกให้หมด ห้ามใช้เพิ่ม Deny อย่างเดียว `[DESIGNED]`

```sql
DO $$ 
DECLARE 
  pol record;
BEGIN
  -- 1. กวาดล้าง Permissive Policy (ที่อาจอนุญาตให้ทะลุ Deny ใหม่)
  FOR pol IN 
    SELECT policyname FROM pg_policies 
    WHERE schemaname = 'storage' AND tablename = 'objects' 
      AND (qual LIKE '%case-attachments%' OR with_check LIKE '%case-attachments%')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
  END LOOP;
END $$;

-- 2. Create Restrictive (but cleanly segregated) Policies
CREATE POLICY "Strict SELECT Storage" ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'case-attachments' AND public.devc_can_access_case_storage(name, 'READ'));

CREATE POLICY "Strict INSERT Storage" ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'case-attachments' AND public.devc_can_access_case_storage(name, 'UPLOAD'));

-- 3. Lock Client Out from Direct Mutation
CREATE POLICY "Deny UPDATE Storage" ON storage.objects FOR UPDATE TO authenticated USING (false);
CREATE POLICY "Deny DELETE Storage" ON storage.objects FOR DELETE TO authenticated USING (false);
```

---

## 7. Extended Test Matrix (Normal, Attack & Failure Vectors)
| ID | Phase | Scenario | Action / Conditions | Expected Result | Status |
|---|---|---|---|---|---|
| 01 | Migration | Table `case_attachments` already has `status` | Run Migration Block | Succeeds w/o data loss | `[UNVERIFIED]` |
| 02 | Attack | Call `devc_internal_case_permission` via SDK | Client RPC Call | `ERROR` (Revoked) | `[UNVERIFIED]` |
| 03 | Attack | Path Traversal: `cases/%2e%2e/main/f.png` | UPLOAD / READ | `FALSE` (Canonical Block) | `[UNVERIFIED]` |
| 04 | Attack | Spoof `p_user_id` in Storage Helper | Direct call with fake UUID| `FALSE` (`auth.uid` checked)| `[UNVERIFIED]` |
| 05 | Normal | Admin READ deleted case | READ `cases/{del_id}/...` | `FALSE` (Parent Must Exist)| `[UNVERIFIED]` |
| 06 | Normal | Delete Idempotency | Double call `request_delete`| `TRUE` (No Error) | `[UNVERIFIED]` |
| 07 | Attack | Attacker checks delete status of others | Call `request_delete` | `ERROR` (Auth checked 1st) | `[UNVERIFIED]` |
| 08 | Failure | Edge Function sees no file | Call Confirm Upload | Edge Returns 404/Error | `[UNVERIFIED]` |
| 09 | Failure | Storage SDK Delete (`remove`) | Call via Flutter | `FALSE` (RLS Deny DELETE) | `[UNVERIFIED]` |
| 10 | Security| Old Permissive RLS Policy (`OR true`) | Read arbitrary object | Blocked (Dropped by script)| `[UNVERIFIED]` |
| 11 | Failure | Upload Intent Expires | Upload after 16 mins | `FALSE` (Expiration Block) | `[UNVERIFIED]` |
| 12 | Normal | Order Helper (Before DB migration) | Call `devc_can_access_order`| `FALSE` (Graceful Fail) | `[UNVERIFIED]` |

---

## 8. Final Deliverables Summary
### 8.1 Critical Vulnerabilities Resolved
- **Migration Data Loss:** ปรับสคริปต์ให้รันซ้ำได้อย่างปลอดภัยและรองรับคอลัมน์เดิมเพื่อไม่ให้ระบบเก่าพัง
- **Function Exploitation:** จัดการ `REVOKE/GRANT` อย่างชัดเจน แยก Internal (ห้ามแอปเรียก) และ Wrapper (แอปเรียกทางอ้อมผ่าน RLS)
- **Upload Illusion:** ยกเลิกความเชื่อใจ Client ฝั่งแอป ย้ายการคอนเฟิร์มว่าอัปโหลดสำเร็จไปให้ Backend ดึงข้อมูลจาก Storage API มายืนยันก่อนบันทึกลง Metadata
- **Auth before Idempotency:** แก้บั๊กในฟังก์ชัน Delete ที่แต่เดิมยอมคืนค่า TRUE ทันทีถ้าไฟล์มีสถานะ `DELETE_PENDING` ทำให้คนอื่นแอบเช็คสถานะไฟล์ได้ (ตอนนี้ต้องตรวจสิทธิ์ก่อนเสมอ)
- **RLS Permissive Overriding:** สคริปต์ลบ Policy เก่าทำงานอย่างแม่นยำ เพื่อไม่ให้มีคำสั่ง `OR true` ใดๆ หลงเหลือไปกลบกฎ `USING (false)` ในเรื่องของการ Deny Delete/Update ฝั่ง Client

### 8.2 Remaining Execution Blockers
- โมดูล Order ยังถูกจัดอยู่ในสถานะ `[BLOCKED]` เนื่องจากต้องรอ Migration ของ `orders` ลงฐานข้อมูลให้เสร็จสมบูรณ์ก่อน
- การลบ (Delete Orchestrator) และการยืนยันอัปโหลด (Upload Confirmation) ต้องการ **Supabase Edge Function** ที่พัฒนาด้วย Node.js/Deno เพื่อเรียก Admin API ควบคู่กับสเปค SQL ฉบับนี้

**[END OF FINAL SPECIFICATION V2.6]**