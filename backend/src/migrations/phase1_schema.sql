-- =========================================================================
-- PHASE 1: SUPABASE DATABASE & SECURITY MIGRATION SCRIPT (FIXED VERSION)
-- =========================================================================

-- 1. TEAMS TABLE
CREATE TABLE IF NOT EXISTS public.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Ensure required columns exist if teams table already pre-existed
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'teams' AND column_name = 'is_active') THEN
        ALTER TABLE public.teams ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'teams' AND column_name = 'code') THEN
        ALTER TABLE public.teams ADD COLUMN code VARCHAR(50);
    END IF;
END $$;

-- Seed Teams matching existing Flutter TeamType enum
INSERT INTO public.teams (name, code, is_active) VALUES
    ('Web Team', 'web', true),
    ('Mobile Team', 'mobile', true),
    ('Backend Team', 'backend', true),
    ('Infra', 'infra', true),
    ('Other', 'other', true)
ON CONFLICT (code) DO NOTHING;


-- 2. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_code VARCHAR(50),
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
    requested_team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL,
    team_status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Ensure profiles columns exist if table pre-existed
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'requested_team_id') THEN
        ALTER TABLE public.profiles ADD COLUMN requested_team_id UUID REFERENCES public.teams(id) ON DELETE SET NULL;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'team_status') THEN
        ALTER TABLE public.profiles ADD COLUMN team_status VARCHAR(50) DEFAULT 'pending';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'employee_code') THEN
        ALTER TABLE public.profiles ADD COLUMN employee_code VARCHAR(50);
    END IF;
END $$;


-- 3. HELPER FUNCTIONS FOR ADMIN CHECK & ROLE MANAGEMENT
CREATE OR REPLACE FUNCTION public.devc_case_is_active_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'admin'
      AND is_active = true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.devc_case_set_profile_role(p_user_id UUID, p_new_role TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.devc_case_is_active_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required.';
  END IF;

  UPDATE public.profiles
  SET role = p_new_role,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = p_user_id;

  RETURN TRUE;
END;
$$;


-- 4. AUTH TRIGGER FUNCTION (Handle New Auth User)
CREATE OR REPLACE FUNCTION public.devc_case_handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_full_name TEXT;
  v_requested_team_id UUID;
  v_team_status TEXT := 'pending';
BEGIN
  -- Extract metadata safely from raw_user_meta_data
  v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email);

  -- Extract requested_team_id if provided and valid
  IF NEW.raw_user_meta_data->>'requested_team_id' IS NOT NULL AND (NEW.raw_user_meta_data->>'requested_team_id') <> '' THEN
    BEGIN
      v_requested_team_id := (NEW.raw_user_meta_data->>'requested_team_id')::UUID;
      IF NOT EXISTS (SELECT 1 FROM public.teams WHERE id = v_requested_team_id AND is_active = true) THEN
        v_requested_team_id := NULL;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_requested_team_id := NULL;
    END;
  END IF;

  -- Insert into profiles (Forcing role='user', team_id=NULL, no user can override this)
  INSERT INTO public.profiles (
    id,
    employee_code,
    full_name,
    email,
    role,
    team_id,
    requested_team_id,
    team_status,
    is_active
  ) VALUES (
    NEW.id,
    'EMP-' || LPAD(CAST(floor(random() * 89999 + 10000) AS TEXT), 5, '0'),
    v_full_name,
    NEW.email,
    'user',
    NULL,
    v_requested_team_id,
    v_team_status,
    true
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Create Trigger on auth.users
DROP TRIGGER IF EXISTS devcase_on_auth_user_created ON auth.users;
CREATE TRIGGER devcase_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.devc_case_handle_new_auth_user();


-- 5. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Teams RLS Policies
DROP POLICY IF EXISTS "Anyone authenticated can view active teams" ON public.teams;
CREATE POLICY "Anyone authenticated can view active teams"
  ON public.teams FOR SELECT
  TO authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS "Admins can manage teams" ON public.teams;
CREATE POLICY "Admins can manage teams"
  ON public.teams FOR ALL
  TO authenticated
  USING (public.devc_case_is_active_admin())
  WITH CHECK (public.devc_case_is_active_admin());


-- Profiles RLS Policies
DROP POLICY IF EXISTS "Users can view own profile or admins view all" ON public.profiles;
CREATE POLICY "Users can view own profile or admins view all"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid() OR public.devc_case_is_active_admin());

DROP POLICY IF EXISTS "Users can update non-sensitive fields of own profile" ON public.profiles;
CREATE POLICY "Users can update non-sensitive fields of own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND role = (SELECT role FROM public.profiles WHERE id = auth.uid())
    AND team_id IS NOT DISTINCT FROM (SELECT team_id FROM public.profiles WHERE id = auth.uid())
    AND team_status IS NOT DISTINCT FROM (SELECT team_status FROM public.profiles WHERE id = auth.uid())
    AND is_active = (SELECT is_active FROM public.profiles WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "Admins can manage profiles" ON public.profiles;
CREATE POLICY "Admins can manage profiles"
  ON public.profiles FOR ALL
  TO authenticated
  USING (public.devc_case_is_active_admin())
  WITH CHECK (public.devc_case_is_active_admin());


-- 6. CUSTOM DATABASE FUNCTIONS (Request, Approve, Reject Team)

-- Request Team function for users
CREATE OR REPLACE FUNCTION public.request_team(p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify team exists and is active
  IF NOT EXISTS (SELECT 1 FROM public.teams WHERE id = p_team_id AND is_active = true) THEN
    RAISE EXCEPTION 'Team does not exist or is inactive.';
  END IF;

  UPDATE public.profiles
  SET requested_team_id = p_team_id,
      team_status = 'pending',
      updated_at = CURRENT_TIMESTAMP
  WHERE id = auth.uid();

  RETURN TRUE;
END;
$$;

-- Approve Team function for admins
CREATE OR REPLACE FUNCTION public.approve_team(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requested_team UUID;
BEGIN
  -- Check if executor is active admin
  IF NOT public.devc_case_is_active_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required.';
  END IF;

  -- Get requested team
  SELECT requested_team_id INTO v_requested_team
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_requested_team IS NULL THEN
    RAISE EXCEPTION 'No pending team request found for this user.';
  END IF;

  UPDATE public.profiles
  SET team_id = v_requested_team,
      team_status = 'approved',
      updated_at = CURRENT_TIMESTAMP
  WHERE id = p_user_id;

  RETURN TRUE;
END;
$$;

-- Reject Team function for admins
CREATE OR REPLACE FUNCTION public.reject_team(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if executor is active admin
  IF NOT public.devc_case_is_active_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required.';
  END IF;

  UPDATE public.profiles
  SET team_status = 'rejected',
      updated_at = CURRENT_TIMESTAMP
  WHERE id = p_user_id;

  RETURN TRUE;
END;
$$;

-- =========================================================================
-- GRANT EXECUTE PERMISSIONS TO AUTHENTICATED ROLE
-- =========================================================================
GRANT EXECUTE ON FUNCTION public.devc_case_is_active_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.devc_case_set_profile_role(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_team(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_team(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_team(UUID) TO authenticated;

