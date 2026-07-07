-- 1. Helper Table for user settings / active tenant persistence if not existing
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  active_tenant_id uuid references public.tenants(id),
  full_name text,
  updated_at timestamp with time zone default now()
);

-- Enable RLS on profiles to prevent cross-user leakage
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view and update their own profile" 
ON public.user_profiles 
FOR ALL USING (auth.uid() = id);

-- 2. Define ENUM for Member Roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tenant_role') THEN
        CREATE TYPE public.tenant_role AS ENUM ('owner', 'admin', 'manager', 'member', 'viewer');
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tenant_status') THEN
        CREATE TYPE public.tenant_status AS ENUM ('active', 'invited', 'disabled');
    END IF;
END $$;

-- 3. Ensure tenant_members has required structure
-- Assumes tenants and tenant_members exist; if not, defining safe basic schema logic
CREATE TABLE IF NOT EXISTS public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  created_at timestamp with time zone default now()
);

CREATE TABLE IF NOT EXISTS public.tenant_members (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade,
  email text,
  role public.tenant_role default 'member'::public.tenant_role,
  status public.tenant_status default 'active'::public.tenant_status,
  created_at timestamp with time zone default now(),
  UNIQUE(tenant_id, email) -- prevent duplicate invites for the same email
);

-- Note: RLS on tenant_members is recommended but deliberately bypassed in RPC using SECURITY DEFINER

-- 4. RPC for Secure Admin Invite
CREATE OR REPLACE FUNCTION public.qione_admin_invite_tenant_member(
    p_tenant_id uuid,
    p_email text,
    p_role text,
    p_invited_by uuid
) 
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_requester_role text;
    v_existing_status text;
    v_invited_user_id uuid;
    v_result jsonb;
BEGIN
    -- 1. Verify requester is admin or owner of the tenant
    SELECT role INTO v_requester_role 
    FROM public.tenant_members 
    WHERE tenant_id = p_tenant_id AND user_id = p_invited_by
    AND role IN ('admin', 'owner');
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Requester is not an active admin/owner of this tenant';
    END IF;

    -- 2. Validate Role Assignment
    IF p_role NOT IN ('admin', 'member', 'viewer') THEN
        RAISE EXCEPTION 'Invalid role assignment';
    END IF;

    -- 3. Check for existing invites or membership
    SELECT status INTO v_existing_status
    FROM public.tenant_members
    WHERE tenant_id = p_tenant_id AND email = p_email;

    IF FOUND THEN
        IF v_existing_status = 'active' THEN
            RAISE EXCEPTION 'User is already an active member of this tenant';
        ELSIF v_existing_status = 'invited' THEN
            RAISE EXCEPTION 'User has already been invited to this tenant';
        ELSE
            -- User might be disabled, reactivate with invite
            UPDATE public.tenant_members
            SET status = 'invited', role = p_role::public.tenant_role
            WHERE tenant_id = p_tenant_id AND email = p_email;
            
            RETURN json_build_object('success', true, 'action', 'reactivated');
        END IF;
    END IF;

    -- 4. Check if auth user exists for email
    -- Since we aren't in auth schema, we can't reliably read auth.users.email easily 
    -- unless we join through a trigger table or accept that the user_id starts null.
    -- Assuming they don't exist yet, user_id remains null.
    SELECT id INTO v_invited_user_id FROM auth.users WHERE email = p_email LIMIT 1;

    -- 5. Insert new member row
    INSERT INTO public.tenant_members(tenant_id, user_id, email, role, status)
    VALUES (p_tenant_id, v_invited_user_id, p_email, p_role::public.tenant_role, 'invited');

    -- NOTE: At this point, you'd trigger an edge function or real email integration natively.
    -- For now, the DB state is valid.

    v_result := jsonb_build_object(
        'success', true, 
        'tenant_id', p_tenant_id,
        'email', p_email,
        'role', p_role,
        'status', 'invited'
    );
    
    RETURN v_result;
END;
$$;
