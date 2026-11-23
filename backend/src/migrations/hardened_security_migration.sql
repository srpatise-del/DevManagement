-- =========================================================================
-- ULTIMATE HARDENED SECURITY MIGRATION SCRIPT FOR SUPABASE DATABASE FUNCTIONS
-- =========================================================================

BEGIN;

-- 1. devc_case_is_active_admin()
CREATE OR REPLACE FUNCTION public.devc_case_is_active_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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


-- 2. devc_case_set_profile_role(UUID, TEXT)
-- Uses a transaction-level advisory lock to serialize role change and last-admin check.
CREATE OR REPLACE FUNCTION public.devc_case_set_profile_role(p_user_id UUID, p_new_role TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_current_role TEXT;
  v_target_is_active BOOLEAN;
  v_admin_count INT;
BEGIN
  -- Acquire a fixed transaction-level advisory lock to serialize admin role changes & demotions
  -- Lock key 8675309 (arbitrary unique integer for admin role management)
  PERFORM pg_advisory_xact_lock(8675309);

  -- Re-verify caller is active admin after acquiring lock
  IF NOT public.devc_case_is_active_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Active Admin access required.';
  END IF;

  -- Validate role input against NULL/blank and allowed list
  IF p_new_role IS NULL OR trim(p_new_role) = '' THEN
    RAISE EXCEPTION 'Role cannot be null or empty.';
  END IF;

  p_new_role := lower(trim(p_new_role));
  IF p_new_role NOT IN ('user', 'developer', 'team_lead', 'admin') THEN
    RAISE EXCEPTION 'Invalid role specified. Allowed roles: user, developer, team_lead, admin.';
  END IF;

  -- Lock target profile row for update
  SELECT role, is_active INTO v_current_role, v_target_is_active
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_current_role IS NULL THEN
    RAISE EXCEPTION 'Target user profile does not exist.';
  END IF;

  IF v_target_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'Target user account is inactive.';
  END IF;

  -- Protect against demoting or altering the last active admin
  IF v_current_role = 'admin' AND p_new_role <> 'admin' THEN
    SELECT count(*) INTO v_admin_count
    FROM public.profiles
    WHERE role = 'admin' AND is_active = true;

    IF v_admin_count <= 1 THEN
      RAISE EXCEPTION 'Cannot demote the last remaining active admin.';
    END IF;
  END IF;

  -- Update role securely
  UPDATE public.profiles
  SET role = p_new_role,
      updated_at = clock_timestamp()
  WHERE id = p_user_id;

  RETURN TRUE;
END;
$$;


-- 3. request_team(UUID)
-- Workflow: Prevents duplicate pending requests, checks if user is already in target team, preserves existing team_id until admin approval.
CREATE OR REPLACE FUNCTION public.request_team(p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id UUID;
  v_is_active BOOLEAN;
  v_team_status TEXT;
  v_current_team_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Lock user profile row and check active status, team status, and current team ID
  SELECT is_active, team_status, team_id
  INTO v_is_active, v_team_status, v_current_team_id
  FROM public.profiles
  WHERE id = v_user_id
  FOR UPDATE;

  IF v_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'User account is inactive or not found.';
  END IF;

  -- Prevent duplicate requests if a request is already pending
  IF v_team_status = 'pending' THEN
    RAISE EXCEPTION 'You already have a pending team change request awaiting approval.';
  END IF;

  -- Check if user is already assigned to this team
  IF v_current_team_id = p_team_id THEN
    RAISE EXCEPTION 'You are already assigned to this team.';
  END IF;

  -- Verify requested team exists and is active
  IF NOT EXISTS (SELECT 1 FROM public.teams WHERE id = p_team_id AND is_active = true) THEN
    RAISE EXCEPTION 'Team does not exist or is inactive.';
  END IF;

  -- Update profile with requested team and set status to pending. Existing team_id remains untouched.
  UPDATE public.profiles
  SET requested_team_id = p_team_id,
      team_status = 'pending',
      updated_at = clock_timestamp()
  WHERE id = v_user_id;

  RETURN TRUE;
END;
$$;


-- 4. approve_team(UUID)
-- Uses advisory lock 8675309 to serialize admin operations, locks profile & team rows, verifies team is active.
CREATE OR REPLACE FUNCTION public.approve_team(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_requested_team UUID;
  v_team_status TEXT;
  v_target_is_active BOOLEAN;
  v_team_exists_and_active BOOLEAN;
BEGIN
  -- Acquire advisory lock to serialize admin operations
  PERFORM pg_advisory_xact_lock(8675309);

  -- Verify caller is active admin after acquiring lock
  IF NOT public.devc_case_is_active_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Active Admin access required.';
  END IF;

  -- Lock target user profile row to prevent concurrent race conditions
  SELECT requested_team_id, team_status, is_active
  INTO v_requested_team, v_team_status, v_target_is_active
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_target_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'Target user account is inactive or not found.';
  END IF;

  -- Ensure request is strictly pending
  IF v_team_status IS DISTINCT FROM 'pending' OR v_requested_team IS NULL THEN
    RAISE EXCEPTION 'No pending team request found for this user.';
  END IF;

  -- Lock and verify requested team is still active to prevent concurrent deactivation
  SELECT is_active INTO v_team_exists_and_active
  FROM public.teams
  WHERE id = v_requested_team
  FOR UPDATE;

  IF v_team_exists_and_active IS NOT TRUE THEN
    RAISE EXCEPTION 'The requested team does not exist or is no longer active.';
  END IF;

  -- Approve team: set team_id from requested_team_id, set status to approved
  UPDATE public.profiles
  SET team_id = v_requested_team,
      team_status = 'approved',
      updated_at = clock_timestamp()
  WHERE id = p_user_id;

  RETURN TRUE;
END;
$$;


-- 5. reject_team(UUID)
-- Uses advisory lock 8675309 to serialize admin operations, locks profile row.
CREATE OR REPLACE FUNCTION public.reject_team(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_team_status TEXT;
  v_target_is_active BOOLEAN;
BEGIN
  -- Acquire advisory lock to serialize admin operations
  PERFORM pg_advisory_xact_lock(8675309);

  -- Verify caller is active admin after acquiring lock
  IF NOT public.devc_case_is_active_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Active Admin access required.';
  END IF;

  -- Lock target user profile row to prevent concurrent race conditions
  SELECT team_status, is_active
  INTO v_team_status, v_target_is_active
  FROM public.profiles
  WHERE id = p_user_id
  FOR UPDATE;

  IF v_target_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'Target user account is inactive or not found.';
  END IF;

  -- Ensure request is strictly pending
  IF v_team_status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'No pending team request to reject for this user.';
  END IF;

  -- Reject team: update status to rejected, retaining requested_team_id for audit history, without altering existing team_id
  UPDATE public.profiles
  SET team_status = 'rejected',
      updated_at = clock_timestamp()
  WHERE id = p_user_id;

  RETURN TRUE;
END;
$$;


-- =========================================================================
-- REVOKE & GRANT EXECUTE PRIVILEGES
-- =========================================================================
REVOKE EXECUTE ON FUNCTION public.devc_case_is_active_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.devc_case_is_active_admin() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.devc_case_set_profile_role(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.devc_case_set_profile_role(UUID, TEXT) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.request_team(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_team(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.approve_team(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_team(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.reject_team(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_team(UUID) TO authenticated;

COMMIT;
