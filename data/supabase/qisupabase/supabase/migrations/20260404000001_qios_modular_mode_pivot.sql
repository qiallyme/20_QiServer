-- QiOS v0.4 Modular Mode Pivot — Single-Account Implementation
-- Date: 2026-04-04
-- Pivot: Unified Profiles + owner_user_id + Module Registry

CREATE SCHEMA IF NOT EXISTS qione;
CREATE SCHEMA IF NOT EXISTS qicase;

-- 1. UNIFIED PROFILES (qione)
-- Consolidate legacy profile attempts into a canonical platform profile.
CREATE TABLE IF NOT EXISTS qione.profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role            TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('user', 'admin')),
    full_name       TEXT,
    avatar_url      TEXT,
    metadata        JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE qione.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view and update their own profile" 
ON qione.profiles FOR ALL USING (auth.uid() = id);

-- 2. MODULAR APP REGISTRY
-- Defines which "Apps" or "Modules" are available in the portal.
CREATE TABLE IF NOT EXISTS qione.app_module_registry (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            TEXT UNIQUE NOT NULL, -- e.g. 'cases', 'vault', 'knowledge', 'tax'
    name            TEXT NOT NULL,
    icon            TEXT,
    description     TEXT,
    default_enabled BOOLEAN DEFAULT true,
    order_int       SERIAL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- USER MODULE SETTINGS
-- Controls which modules appear for which user.
CREATE TABLE IF NOT EXISTS qione.user_module_settings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES qione.profiles(id) ON DELETE CASCADE,
    module_id       UUID NOT NULL REFERENCES qione.app_module_registry(id) ON DELETE CASCADE,
    is_enabled      BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, module_id)
);

ALTER TABLE qione.app_module_registry ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Everyone can read modules" ON qione.app_module_registry FOR SELECT USING (true);

ALTER TABLE qione.user_module_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users control their own modules" ON qione.user_module_settings FOR ALL USING (auth.uid() = user_id);

-- 3. DOMAIN ID CONSOLIDATION (owner_user_id)
-- Rename existing references for blueprint compliance.
DO $$ 
BEGIN 
    -- Matter (Legal) Alignment
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'matter' AND column_name = 'user_id') THEN
        ALTER TABLE public.matter RENAME COLUMN user_id TO owner_user_id;
    END IF;

    -- Profiles (Legal) Cleanup
    -- If 'profiles' existed in public, we move data to qione and drop public one.
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'profiles') THEN
        BEGIN
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'user_id') THEN
                INSERT INTO qione.profiles (id, role, full_name, avatar_url, created_at, updated_at)
                SELECT user_id, role, full_name, avatar_url, created_at, updated_at 
                FROM public.profiles
                ON CONFLICT (id) DO NOTHING;
            ELSE
                INSERT INTO qione.profiles (id, role, full_name, avatar_url, created_at, updated_at)
                SELECT id, role, full_name, avatar_url, created_at, updated_at 
                FROM public.profiles
                ON CONFLICT (id) DO NOTHING;
            END IF;
            DROP TABLE public.profiles CASCADE;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Skipping public.profiles migration due to structural mismatch: %', SQLERRM;
        END;
    END IF;

    -- Legacy user_profiles (qione_admin_invite) Cleanup
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'user_profiles') THEN
        INSERT INTO qione.profiles (id, full_name, updated_at)
        SELECT id, full_name, updated_at
        FROM public.user_profiles
        ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, updated_at = EXCLUDED.updated_at;
        DROP TABLE public.user_profiles CASCADE;
    END IF;
END $$;

-- 4. PROFILE AUTO-CREATION TRIGGER
-- Ensures every auth.user gets a qione.profile
CREATE OR REPLACE FUNCTION qione.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO qione.profiles (id, full_name, avatar_url)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'avatar_url');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION qione.handle_new_user();

-- 5. INITIAL SEED: MODULES
INSERT INTO qione.app_module_registry (slug, name, icon, description)
VALUES 
    ('cases', 'Case Management', 'Legal', 'Legal case planning, facts, and timeline.'),
    ('vault', 'File Vault', 'Folder', 'Secure document storage and extraction.'),
    ('knowledge', 'Knowledge Base', 'Book', 'Case research and document summaries.'),
    ('tax', 'Tax & Finance', 'DollarSign', 'Financial records and expense tracking.')
ON CONFLICT (slug) DO NOTHING;

-- 6. RPC: MODULE MANAGEMENT
CREATE OR REPLACE FUNCTION qione.get_user_modules(p_user_id UUID)
RETURNS SETOF qione.app_module_registry AS $$
BEGIN
    RETURN QUERY
    SELECT r.*
    FROM qione.app_module_registry r
    LEFT JOIN qione.user_module_settings s ON r.id = s.module_id AND s.user_id = p_user_id
    WHERE (s.is_enabled IS NULL AND r.default_enabled = true) -- not set, use default
       OR (s.is_enabled = true); -- explicitly set to true
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
