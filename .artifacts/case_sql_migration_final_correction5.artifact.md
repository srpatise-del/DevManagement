# Final Review & Correction 5: Complete SQL Migration & Security Audit — DevCase Phase 2.2

รายงานการตรวจสอบสถาปัตยกรรม, SQL Migration Script ฉบับสมบูรณ์ (Final Correction 5), Audit SQL, และ Verification SQL ตามข้อกำหนดความปลอดภัยสูงสุดของโปรเจกต์ DevCase

---

## Part A — Read-only Audit SQL (คำสั่งตรวจสอบโครงสร้างและสิทธิ์เดิมบน Supabase)

รันชุดคำสั่งนี้บน Supabase SQL Editor เพื่อตรวจสอบโครงสร้างตาราง, Columns, Constraints, Foreign Keys, Indexes, RLS Policies, Grants, Sequence state และ Storage Bucket ก่อนรัน Migration:

```sql
-- =========================================================================
-- PART A: READ-ONLY AUDIT SQL
-- =========================================================================

-- 1. ตรวจสอบตารางที่มีอยู่จริงใน schema public
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('profiles', 'teams', 'cases', 'case_comments', 'case_comment_likes', 'case_activity_logs', 'case_attachments');

-- 2. ตรวจสอบ Columns, Data Types และ Nullable ของทุกตารางเคส
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('cases', 'case_comments', 'case_activity_logs', 'case_attachments');

-- 3. ตรวจสอบ Constraints และ Foreign Keys ทั้งหมด
SELECT tc.constraint_name, tc.table_name, kcu.column_name, ccu.table_name AS foreign_table_name, ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_schema = 'public' AND tc.constraint_type IN ('FOREIGN KEY', 'CHECK', 'UNIQUE');

-- 4. ตรวจสอบ Indexes
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename IN ('cases', 'case_comments', 'case_activity_logs', 'case_attachments');

-- 5. ตรวจสอบ RLS Policies ทั้งหมดใน Schema public และ storage
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname IN ('public', 'storage');

-- 6. ตรวจสอบ Table Grants สำหรับ authenticated และ anon
SELECT grantee, table_name, privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name IN ('cases', 'case_comments', 'case_comment_likes', 'case_activity_logs', 'case_attachments');

-- 7. ตรวจสอบ Sequence Grants และ State ของ case_seq
SELECT sequence_name, last_value, start_value, increment_by
FROM information_schema.sequences
WHERE sequence_schema = 'public' AND sequence_name = 'case_seq';

SELECT grantee, sequence_name, privilege_type
FROM information_schema.sequence_privileges
WHERE sequence_schema = 'public' AND sequence_name = 'case_seq';

-- 8. ตรวจสอบ Function Ownership และ SECURITY DEFINER
SELECT routine_name, security_type, external_language
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE 'devc_%';

-- 9. ตรวจสอบสถานะ Storage Bucket 'case-attachments'
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'case-attachments';
```

---

## Part B — Corrected Migration SQL (SQL ฉบับสมบูรณ์)

```sql
-- =========================================================================
-- PART B: FINAL CORRECTION 5 SQL MIGRATION & RLS — CASE MANAGEMENT
-- =========================================================================

BEGIN;

-- 1. Cases Table (Idempotent creation with ALTER TABLE for safe schema updates)
CREATE TABLE IF NOT EXISTS public.cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_no TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  details TEXT,
  priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  status TEXT NOT NULL CHECK (status IN ('open', 'assigned', 'inProgress', 'pending', 'waiting', 'testing', 'done', 'closed')),
  team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE RESTRICT,
  category TEXT NOT NULL,
  assignee_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  system_affected TEXT,
  environment TEXT,
  url TEXT,
  browser TEXT,
  created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- Ensure all required columns exist safely without dropping data
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS details TEXT;
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS system_affected TEXT;
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS environment TEXT;
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS url TEXT;
ALTER TABLE public.cases ADD COLUMN IF NOT EXISTS browser TEXT;

-- 2. Case Number Sequence & Safe Initialization (Guarantees sequence never goes backward)
CREATE SEQUENCE IF NOT EXISTS public.case_seq START WITH 1 INCREMENT BY 1;

-- Revoke direct sequence usage from clients; triggers run with SECURITY DEFINER
REVOKE USAGE, SELECT ON SEQUENCE public.case_seq FROM PUBLIC, anon, authenticated;

-- Lock table during sequence sync to prevent concurrent race conditions
LOCK TABLE public.cases IN EXCLUSIVE MODE;

-- Sync sequence safely considering last_value and is_called to prevent reusing deleted numbers
DO $$
DECLARE
  v_max BIGINT;
  v_curr_last BIGINT;
  v_curr_called BOOLEAN;
  v_target BIGINT;
BEGIN
  SELECT COALESCE(MAX(SUBSTRING(case_no FROM 5)::BIGINT), 0) INTO v_max
  FROM public.cases
  WHERE case_no LIKE 'DEV-%'
    AND SUBSTRING(case_no FROM 5) ~ '^[0-9]+$';

  SELECT last_value, is_called INTO v_curr_last, v_curr_called
  FROM public.case_seq;

  IF v_curr_called THEN
    v_curr_last := v_curr_last + 1;
  END IF;

  v_target := GREATEST(v_curr_last, v_max + 1);

  IF v_target > 1 THEN
    PERFORM setval('public.case_seq', v_target - 1, true);
  ELSE
    PERFORM setval('public.case_seq', 1, false);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.devc_case_generate_case_no()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_seq BIGINT;
BEGIN
  v_seq := nextval('public.case_seq');
  NEW.case_no := 'DEV-' || LPAD(v_seq::TEXT, GREATEST(3, LENGTH(v_seq::TEXT)), '0');
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.devc_case_generate_case_no() FROM PUBLIC, anon, authenticated;

-- 3. Cases INSERT Validation Trigger (Strict Assignee & Team Validation for ALL roles)
CREATE OR REPLACE FUNCTION public.devc_case_validate_case_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID;
  v_role TEXT;
  v_team_id UUID;
  v_is_active BOOLEAN;
  v_assignee_team_id UUID;
  v_assignee_is_active BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF NEW.created_by IS DISTINCT FROM v_user_id THEN
    RAISE EXCEPTION 'created_by must match auth.uid().';
  END IF;

  SELECT role, team_id, is_active
  INTO v_role, v_team_id, v_is_active
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'User account is inactive.';
  END IF;

  IF v_role NOT IN ('admin', 'team_lead', 'developer', 'user') OR v_role IS NULL THEN
    RAISE EXCEPTION 'Invalid or unauthorized user role.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.teams WHERE id = NEW.team_id AND is_active = true) THEN
    RAISE EXCEPTION 'Team does not exist or is inactive.';
  END IF;

  -- Role-based creation rules
  IF v_role = 'team_lead' OR v_role = 'developer' THEN
    IF NEW.team_id IS DISTINCT FROM v_team_id THEN
      RAISE EXCEPTION 'Team Lead and Developer can only create cases within their own team.';
    END IF;
  END IF;

  IF v_role = 'developer' THEN
    IF NEW.assignee_id IS NOT NULL THEN
      RAISE EXCEPTION 'Developer must create cases with assignee_id = NULL.';
    END IF;
  END IF;

  IF v_role = 'user' THEN
    IF NEW.assignee_id IS NOT NULL THEN
      RAISE EXCEPTION 'User must create cases with assignee_id = NULL.';
    END IF;
    IF NEW.status != 'open' THEN
      RAISE EXCEPTION 'User can only create cases with open status.';
    END IF;
    IF NEW.priority NOT IN ('low', 'medium') THEN
      RAISE EXCEPTION 'User can only set low or medium priority on create.';
    END IF;
  END IF;

  -- Verify assignee if provided (ENFORCED FOR ALL ROLES INCLUDING ADMIN)
  IF NEW.assignee_id IS NOT NULL THEN
    SELECT team_id, is_active INTO v_assignee_team_id, v_assignee_is_active
    FROM public.profiles
    WHERE id = NEW.assignee_id;

    IF v_assignee_is_active IS NOT TRUE THEN
      RAISE EXCEPTION 'Assignee must be an active user.';
    END IF;

    IF v_assignee_team_id IS DISTINCT FROM NEW.team_id THEN
      RAISE EXCEPTION 'Assignee must belong to the case team.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.devc_case_validate_case_insert() FROM PUBLIC, anon, authenticated;

-- 4. Cases UPDATE Column-Level Validation Trigger (Strict Allowlist per Role)
CREATE OR REPLACE FUNCTION public.devc_case_validate_case_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID;
  v_role TEXT;
  v_team_id UUID;
  v_is_active BOOLEAN;
  v_assignee_team_id UUID;
  v_assignee_is_active BOOLEAN;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
     OR NEW.case_no IS DISTINCT FROM OLD.case_no
     OR NEW.created_by IS DISTINCT FROM OLD.created_by
     OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Cannot modify immutable case attributes (id, case_no, created_by, created_at).';
  END IF;

  SELECT role, team_id, is_active
  INTO v_role, v_team_id, v_is_active
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'User account is inactive.';
  END IF;

  IF v_role NOT IN ('admin', 'team_lead', 'developer', 'user') OR v_role IS NULL THEN
    RAISE EXCEPTION 'Invalid or unauthorized user role.';
  END IF;

  -- Validate assignee on EVERY update (ENFORCED FOR ALL ROLES)
  IF NEW.assignee_id IS NOT NULL THEN
    SELECT team_id, is_active INTO v_assignee_team_id, v_assignee_is_active
    FROM public.profiles
    WHERE id = NEW.assignee_id;

    IF v_assignee_is_active IS NOT TRUE THEN
      RAISE EXCEPTION 'Assignee must be an active user.';
    END IF;
    IF v_assignee_team_id IS DISTINCT FROM NEW.team_id THEN
      RAISE EXCEPTION 'Assignee must belong to the case team.';
    END IF;
  END IF;

  -- 1. Admin: Can update all fields except system attributes
  IF v_role = 'admin' THEN
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
  END IF;

  -- 2. Team Lead: Manage cases within own team only. Can update ONLY status and assignee_id.
  IF v_role = 'team_lead' THEN
    IF OLD.team_id IS DISTINCT FROM v_team_id THEN
      RAISE EXCEPTION 'Team Lead can only manage cases assigned to their own team.';
    END IF;
    IF NEW.team_id IS DISTINCT FROM OLD.team_id THEN
      RAISE EXCEPTION 'Team Lead cannot change case team.';
    END IF;
    IF NEW.title IS DISTINCT FROM OLD.title
       OR NEW.details IS DISTINCT FROM OLD.details
       OR NEW.priority IS DISTINCT FROM OLD.priority
       OR NEW.category IS DISTINCT FROM OLD.category
       OR NEW.system_affected IS DISTINCT FROM OLD.system_affected
       OR NEW.environment IS DISTINCT FROM OLD.environment
       OR NEW.url IS DISTINCT FROM OLD.url
       OR NEW.browser IS DISTINCT FROM OLD.browser THEN
      RAISE EXCEPTION 'Team Lead is only permitted to update status and assignee_id.';
    END IF;
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
  END IF;

  -- 3. Developer: Assigned cases or cases in own team. Can update status, details, system_affected, environment, url, browser.
  IF v_role = 'developer' THEN
    IF OLD.team_id IS DISTINCT FROM v_team_id AND OLD.assignee_id IS DISTINCT FROM v_user_id THEN
      RAISE EXCEPTION 'Developer can only update assigned cases or cases in their team.';
    END IF;
    IF NEW.team_id IS DISTINCT FROM OLD.team_id
       OR NEW.assignee_id IS DISTINCT FROM OLD.assignee_id
       OR NEW.priority IS DISTINCT FROM OLD.priority
       OR NEW.title IS DISTINCT FROM OLD.title
       OR NEW.category IS DISTINCT FROM OLD.category THEN
      RAISE EXCEPTION 'Developer cannot change team, assignee, priority, title, or category.';
    END IF;
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
  END IF;

  -- 4. User: Edit details, system_affected, environment, url, browser on own/assigned cases when status is open or pending.
  IF v_role = 'user' THEN
    IF OLD.created_by IS DISTINCT FROM v_user_id AND OLD.assignee_id IS DISTINCT FROM v_user_id THEN
      RAISE EXCEPTION 'User can only update their own or assigned cases.';
    END IF;
    IF OLD.status NOT IN ('open', 'pending') THEN
      RAISE EXCEPTION 'User cannot update case once in progress or closed.';
    END IF;
    IF NEW.team_id IS DISTINCT FROM OLD.team_id
       OR NEW.assignee_id IS DISTINCT FROM OLD.assignee_id
       OR NEW.priority IS DISTINCT FROM OLD.priority
       OR NEW.status IS DISTINCT FROM OLD.status
       OR NEW.title IS DISTINCT FROM OLD.title
       OR NEW.category IS DISTINCT FROM OLD.category THEN
      RAISE EXCEPTION 'User is not permitted to modify management or system attributes.';
    END IF;
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Unauthorized update attempt.';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.devc_case_validate_case_update() FROM PUBLIC, anon, authenticated;

-- Attach Triggers to Cases Table
DROP TRIGGER IF EXISTS tr_cases_insert_validation ON public.cases;
CREATE TRIGGER tr_cases_insert_validation
  BEFORE INSERT ON public.cases
  FOR EACH ROW
  EXECUTE FUNCTION public.devc_case_validate_case_insert();

DROP TRIGGER IF EXISTS tr_cases_update_validation ON public.cases;
CREATE TRIGGER tr_cases_update_validation
  BEFORE UPDATE ON public.cases
  FOR EACH ROW
  EXECUTE FUNCTION public.devc_case_validate_case_update();

DROP TRIGGER IF EXISTS tr_generate_case_no ON public.cases;
CREATE TRIGGER tr_generate_case_no
  BEFORE INSERT ON public.cases
  FOR EACH ROW
  EXECUTE FUNCTION public.devc_case_generate_case_no();

CREATE INDEX IF NOT EXISTS idx_cases_team_id ON public.cases(team_id);
CREATE INDEX IF NOT EXISTS idx_cases_assignee_id ON public.cases(assignee_id);
CREATE INDEX IF NOT EXISTS idx_cases_created_by ON public.cases(created_by);
CREATE INDEX IF NOT EXISTS idx_cases_status ON public.cases(status);

-- 5. Case Comments Table (with attached_image_path for storage path)
CREATE TABLE IF NOT EXISTS public.case_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  attached_image_path TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.case_comments ADD COLUMN IF NOT EXISTS attached_image_path TEXT;
CREATE INDEX IF NOT EXISTS idx_case_comments_case_id ON public.case_comments(case_id);

-- 6. Case Comment Likes Table (Composite PK prevents duplicate likes)
CREATE TABLE IF NOT EXISTS public.case_comment_likes (
  comment_id UUID NOT NULL REFERENCES public.case_comments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (comment_id, user_id)
);

-- 7. Case Activity Logs Table & Automated Audit Trigger (author_id nullable for system events)
CREATE TABLE IF NOT EXISTS public.case_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  author_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  author_name TEXT NOT NULL,
  icon_name TEXT,
  icon_color TEXT,
  icon_bg_color TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE OR REPLACE FUNCTION public.devc_case_audit_logger()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_author_id UUID;
  v_author_name TEXT;
BEGIN
  v_author_id := auth.uid();

  IF v_author_id IS NOT NULL THEN
    SELECT full_name INTO v_author_name
    FROM public.profiles
    WHERE id = v_author_id;
  END IF;

  v_author_name := COALESCE(v_author_name, 'System User');

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.case_activity_logs (case_id, author_id, title, author_name, icon_name, icon_color, icon_bg_color)
    VALUES (NEW.id, v_author_id, 'สร้างเคส: ' || NEW.title, v_author_name, 'add_circle', 'blue', '#DBEAFE');
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      INSERT INTO public.case_activity_logs (case_id, author_id, title, author_name, icon_name, icon_color, icon_bg_color)
      VALUES (NEW.id, v_author_id, 'เปลี่ยนสถานะ: ' || OLD.status || ' → ' || NEW.status, v_author_name, 'sync', 'teal', '#CCFBF1');
    END IF;
    IF OLD.priority IS DISTINCT FROM NEW.priority THEN
      INSERT INTO public.case_activity_logs (case_id, author_id, title, author_name, icon_name, icon_color, icon_bg_color)
      VALUES (NEW.id, v_author_id, 'เปลี่ยนความสำคัญ: ' || OLD.priority || ' → ' || NEW.priority, v_author_name, 'flag', 'orange', '#FFEDD5');
    END IF;
    IF OLD.team_id IS DISTINCT FROM NEW.team_id THEN
      INSERT INTO public.case_activity_logs (case_id, author_id, title, author_name, icon_name, icon_color, icon_bg_color)
      VALUES (NEW.id, v_author_id, 'เปลี่ยนทีมรับผิดชอบ', v_author_name, 'groups', 'purple', '#F3E8FF');
    END IF;
    IF OLD.assignee_id IS DISTINCT FROM NEW.assignee_id THEN
      INSERT INTO public.case_activity_logs (case_id, author_id, title, author_name, icon_name, icon_color, icon_bg_color)
      VALUES (NEW.id, v_author_id, 'เปลี่ยนผู้รับผิดชอบเคส', v_author_name, 'person_add', 'indigo', '#E0E7FF');
    END IF;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.devc_case_audit_logger() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS tr_cases_audit_log ON public.cases;
CREATE TRIGGER tr_cases_audit_log
  AFTER INSERT OR UPDATE ON public.cases
  FOR EACH ROW
  EXECUTE FUNCTION public.devc_case_audit_logger();

CREATE INDEX IF NOT EXISTS idx_case_activity_logs_case_id ON public.case_activity_logs(case_id);

-- 8. Case Attachments Table (file_size as BIGINT in bytes)
CREATE TABLE IF NOT EXISTS public.case_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  file_type TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  uploaded_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS idx_case_attachments_case_id ON public.case_attachments(case_id);

-- 9. Storage Bucket Setup (Guaranteed Private, size limit 50MB, specific MIME types)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'case-attachments',
  'case-attachments',
  false,
  52428800,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'text/plain']
)
ON CONFLICT (id) DO UPDATE
SET public = false, file_size_limit = 52428800, allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'text/plain'];

-- =========================================================================
-- SECURE HELPER FUNCTIONS
-- =========================================================================
CREATE OR REPLACE FUNCTION public.devc_case_user_can_access_case(p_user_id UUID, p_case_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_role TEXT;
  v_team_id UUID;
  v_is_active BOOLEAN;
  v_case_created_by UUID;
  v_case_assignee_id UUID;
  v_case_team_id UUID;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RETURN FALSE;
  END IF;

  -- Verify case exists first
  SELECT created_by, assignee_id, team_id
  INTO v_case_created_by, v_case_assignee_id, v_case_team_id
  FROM public.cases
  WHERE id = p_case_id;

  IF v_case_created_by IS NULL THEN
    RETURN FALSE;
  END IF;

  SELECT role, team_id, is_active
  INTO v_role, v_team_id, v_is_active
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_is_active IS NOT TRUE THEN
    RETURN FALSE;
  END IF;

  IF v_role = 'admin' THEN
    RETURN TRUE;
  END IF;

  IF v_case_created_by = p_user_id OR v_case_assignee_id = p_user_id THEN
    RETURN TRUE;
  END IF;

  IF (v_role = 'team_lead' OR v_role = 'developer') AND v_team_id IS NOT NULL AND v_team_id = v_case_team_id THEN
    RETURN TRUE;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.case_comments
    WHERE case_id = p_case_id AND author_id = p_user_id
  ) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.devc_case_user_can_access_case(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.devc_case_user_can_access_case(UUID, UUID) TO authenticated;

-- Storage Path Validation Helper Function (Strict Exact Path Validation for Everyone including Admin)
CREATE OR REPLACE FUNCTION public.devc_case_validate_storage_path(p_name TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_parts TEXT[];
  v_case_id UUID;
  v_comment_id UUID;
  v_filename TEXT;
BEGIN
  v_parts := storage.foldername(p_name);
  v_filename := storage.filename(p_name);

  IF v_filename IS NULL OR v_filename = '' THEN
    RETURN NULL;
  END IF;

  -- Pattern 1: cases/{case_id}/{file_name} -> foldername returns ['cases', '{case_id}'] (length 2)
  IF array_length(v_parts, 1) = 2 AND v_parts[1] = 'cases' THEN
    BEGIN
      v_case_id := v_parts[2]::UUID;
    EXCEPTION WHEN others THEN
      RETURN NULL;
    END;

    IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = v_case_id) THEN
      RETURN NULL;
    END;

  -- Pattern 2: cases/{case_id}/comments/{comment_id}/{file_name} -> foldername returns ['cases', '{case_id}', 'comments', '{comment_id}'] (length 4)
  ELSIF array_length(v_parts, 1) = 4 AND v_parts[1] = 'cases' AND v_parts[3] = 'comments' THEN
    BEGIN
      v_case_id := v_parts[2]::UUID;
      v_comment_id := v_parts[4]::UUID;
    EXCEPTION WHEN others THEN
      RETURN NULL;
    END;

    IF v_case_id IS NULL THEN
      RETURN NULL;
    END;
  ELSE
    RETURN NULL;
  END IF;

  IF NOT public.devc_case_user_can_access_case(auth.uid(), v_case_id) THEN
    RETURN NULL;
  END IF;

  RETURN v_case_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.devc_case_validate_storage_path(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.devc_case_validate_storage_path(TEXT) TO authenticated;

-- =========================================================================
-- TABLE AND SEQUENCE GRANTS FOR AUTHENTICATED ROLE
-- =========================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cases TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.case_comments TO authenticated; -- No UPDATE grant on comments
GRANT SELECT, INSERT, DELETE ON public.case_comment_likes TO authenticated;
GRANT SELECT ON public.case_activity_logs TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.case_attachments TO authenticated;

-- NOTE: case_seq usage is revoked from authenticated/anon as triggers run as SECURITY DEFINER owner.

REVOKE ALL ON public.cases FROM anon;
REVOKE ALL ON public.case_comments FROM anon;
REVOKE ALL ON public.case_comment_likes FROM anon;
REVOKE ALL ON public.case_activity_logs FROM anon;
REVOKE ALL ON public.case_attachments FROM anon;
REVOKE ALL ON SEQUENCE public.case_seq FROM PUBLIC, anon, authenticated;

-- =========================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =========================================================================

ALTER TABLE public.cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_attachments ENABLE ROW LEVEL SECURITY;

-- Cases Policies
DROP POLICY IF EXISTS "Users can view accessible cases" ON public.cases;
DROP POLICY IF EXISTS "Active users can create cases" ON public.cases;
DROP POLICY IF EXISTS "Users can update accessible cases" ON public.cases;
DROP POLICY IF EXISTS "Admins can delete cases" ON public.cases;

CREATE POLICY "Users can view accessible cases"
  ON public.cases FOR SELECT
  TO authenticated
  USING (public.devc_case_user_can_access_case(auth.uid(), id));

CREATE POLICY "Active users can create cases"
  ON public.cases FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = auth.uid() AND COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), false)
  );

CREATE POLICY "Users can update accessible cases"
  ON public.cases FOR UPDATE
  TO authenticated
  USING (public.devc_case_user_can_access_case(auth.uid(), id))
  WITH CHECK (public.devc_case_user_can_access_case(auth.uid(), id));

CREATE POLICY "Admins can delete cases"
  ON public.cases FOR DELETE
  TO authenticated
  USING (public.devc_case_is_active_admin());

-- Comments Policies (NO UPDATE POLICY OR GRANT)
DROP POLICY IF EXISTS "Users can view comments on accessible cases" ON public.case_comments;
DROP POLICY IF EXISTS "Active users can insert comments" ON public.case_comments;
DROP POLICY IF EXISTS "Authors or admins can delete comments" ON public.case_comments;

CREATE POLICY "Users can view comments on accessible cases"
  ON public.case_comments FOR SELECT
  TO authenticated
  USING (public.devc_case_user_can_access_case(auth.uid(), case_id));

CREATE POLICY "Active users can insert comments"
  ON public.case_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND public.devc_case_user_can_access_case(auth.uid(), case_id)
    AND COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), false)
  );

CREATE POLICY "Authors or admins can delete comments"
  ON public.case_comments FOR DELETE
  TO authenticated
  USING (
    public.devc_case_user_can_access_case(auth.uid(), case_id)
    AND (
      (author_id = auth.uid() AND COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), false))
      OR public.devc_case_is_active_admin()
    )
  );

-- Comment Likes Policies (Strict Case Access check on DELETE)
DROP POLICY IF EXISTS "Users can view comment likes" ON public.case_comment_likes;
DROP POLICY IF EXISTS "Users can insert comment likes" ON public.case_comment_likes;
DROP POLICY IF EXISTS "Users can delete own comment likes" ON public.case_comment_likes;

CREATE POLICY "Users can view comment likes"
  ON public.case_comment_likes FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.case_comments cc
      WHERE cc.id = comment_id AND public.devc_case_user_can_access_case(auth.uid(), cc.case_id)
    )
  );

CREATE POLICY "Users can insert comment likes"
  ON public.case_comment_likes FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), false)
    AND EXISTS (
      SELECT 1 FROM public.case_comments cc
      WHERE cc.id = comment_id AND public.devc_case_user_can_access_case(auth.uid(), cc.case_id)
    )
  );

CREATE POLICY "Users can delete own comment likes"
  ON public.case_comment_likes FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    AND COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), false)
    AND EXISTS (
      SELECT 1 FROM public.case_comments cc
      WHERE cc.id = comment_id AND public.devc_case_user_can_access_case(auth.uid(), cc.case_id)
    )
  );

-- Activity Logs Policies (SELECT only; INSERT is handled by trigger)
DROP POLICY IF EXISTS "Users can view activity logs on accessible cases" ON public.case_activity_logs;

CREATE POLICY "Users can view activity logs on accessible cases"
  ON public.case_activity_logs FOR SELECT
  TO authenticated
  USING (public.devc_case_user_can_access_case(auth.uid(), case_id));

-- Attachments Policies (Strict Case Access check on DELETE)
DROP POLICY IF EXISTS "Users can view attachments on accessible cases" ON public.case_attachments;
DROP POLICY IF EXISTS "Active users can insert attachments" ON public.case_attachments;
DROP POLICY IF EXISTS "Uploaders or admins can delete attachments" ON public.case_attachments;

CREATE POLICY "Users can view attachments on accessible cases"
  ON public.case_attachments FOR SELECT
  TO authenticated
  USING (public.devc_case_user_can_access_case(auth.uid(), case_id));

CREATE POLICY "Active users can insert attachments"
  ON public.case_attachments FOR INSERT
  TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid()
    AND public.devc_case_user_can_access_case(auth.uid(), case_id)
    AND COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), false)
  );

CREATE POLICY "Uploaders or admins can delete attachments"
  ON public.case_attachments FOR DELETE
  TO authenticated
  USING (
    public.devc_case_user_can_access_case(auth.uid(), case_id)
    AND (
      (uploaded_by = auth.uid() AND COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), false))
      OR public.devc_case_is_active_admin()
    )
  );

-- =========================================================================
-- SUPABASE STORAGE SECURITY POLICIES (Private Bucket 'case-attachments')
-- =========================================================================
DROP POLICY IF EXISTS "Users can view attachments of accessible cases" ON storage.objects;
DROP POLICY IF EXISTS "Active users can upload attachments to accessible cases" ON storage.objects;
DROP POLICY IF EXISTS "Uploaders or admins can delete storage attachments" ON storage.objects;

-- Storage SELECT Policy
CREATE POLICY "Users can view attachments of accessible cases"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'case-attachments' AND
    public.devc_case_validate_storage_path(name) IS NOT NULL
  );

-- Storage INSERT Policy (Note: Flutter app must pass upsert: false when uploading new files)
CREATE POLICY "Active users can upload attachments to accessible cases"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'case-attachments' AND
    COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), false) AND
    public.devc_case_validate_storage_path(name) IS NOT NULL
  );

-- Storage DELETE Policy (Checks path, case access, and owner / admin)
CREATE POLICY "Uploaders or admins can delete storage attachments"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'case-attachments' AND
    public.devc_case_validate_storage_path(name) IS NOT NULL AND (
      public.devc_case_is_active_admin() OR
      owner = auth.uid()
    )
  );

COMMIT;
