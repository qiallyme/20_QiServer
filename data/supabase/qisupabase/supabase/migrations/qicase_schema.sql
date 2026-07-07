-- USBLegalAid v2 — Full Schema (PostgreSQL / Supabase)
-- Migrated from SQLite schema with RLS policies

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── PROFILES ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role            TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('user', 'admin')),
    full_name       TEXT,
    avatar_url      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Helper function: check if user is admin
CREATE OR REPLACE FUNCTION is_admin() RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM profiles 
        WHERE user_id = auth.uid() AND role = 'admin'
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── CORE ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS matter (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    case_number     TEXT,
    court           TEXT,
    jurisdiction    TEXT,
    judge           TEXT,
    plaintiff       TEXT,
    defendant       TEXT,
    status          TEXT NOT NULL DEFAULT 'active'
                    CHECK(status IN ('active','closed','settled','dismissed','appeal')),
    phase           TEXT DEFAULT 'pre-trial'
                    CHECK(phase IN ('pre-trial','discovery','motion','trial','post-trial','appeal')),
    opened_at       TIMESTAMPTZ,
    trial_date      TIMESTAMPTZ,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS parties (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    role            TEXT NOT NULL CHECK(role IN (
                        'plaintiff','defendant','plaintiff_counsel','defense_counsel',
                        'judge','mediator','witness','expert','third_party','other')),
    org             TEXT,
    email           TEXT,
    phone           TEXT,
    address         TEXT,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS issues (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    type            TEXT DEFAULT 'claim' CHECK(type IN (
                        'claim','defense','procedural','evidentiary','constitutional','other')),
    status          TEXT DEFAULT 'open' CHECK(status IN ('open','resolved','waived','pending')),
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS facts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    statement       TEXT NOT NULL,
    category        TEXT DEFAULT 'general' CHECK(category IN (
                        'general','liability','damages','procedure',
                        'timeline','admission','contradiction','disputed')),
    status          TEXT DEFAULT 'asserted' CHECK(status IN (
                        'asserted','established','disputed','withdrawn')),
    issue_id        UUID REFERENCES issues(id) ON DELETE SET NULL,
    source_doc_id   UUID,
    source_file_id  UUID,
    excerpt         TEXT,
    page_ref        TEXT,
    date_of_fact    TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS evidence_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    exhibit_number  TEXT,
    title           TEXT NOT NULL,
    description     TEXT,
    type            TEXT DEFAULT 'document' CHECK(type IN (
                        'document','photo','video','audio','physical',
                        'digital','testimony','record','other')),
    status          TEXT DEFAULT 'collected' CHECK(status IN (
                        'collected','authenticated','admitted','excluded','pending','objected')),
    source_file_id  UUID,
    source_doc_id   UUID,
    issue_id        UUID REFERENCES issues(id) ON DELETE SET NULL,
    date_collected  TEXT,
    chain_of_custody TEXT,
    objections      TEXT,
    notes           TEXT,
    pre_marked      BOOLEAN DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    description     TEXT,
    category        TEXT DEFAULT 'general' CHECK(category IN (
                        'general','filing','discovery','research',
                        'trial_prep','motion','deadline','evidence','other')),
    status          TEXT NOT NULL DEFAULT 'open'
                    CHECK(status IN ('open','in_progress','blocked','done','cancelled')),
    priority        TEXT DEFAULT 'normal' CHECK(priority IN ('low','normal','high','urgent')),
    owner           TEXT NOT NULL DEFAULT 'self',
    due_date        TEXT,
    completed_at    TIMESTAMPTZ,
    related_issue_id UUID REFERENCES issues(id) ON DELETE SET NULL,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS deadlines (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    deadline_date   TEXT NOT NULL,
    type            TEXT DEFAULT 'filing' CHECK(type IN (
                        'filing','response','discovery','motion',
                        'hearing','trial','statute_of_limitations','other')),
    status          TEXT DEFAULT 'pending' CHECK(status IN (
                        'pending','met','missed','extended','waived')),
    court_imposed   BOOLEAN DEFAULT true,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS timeline_events (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    event_date      TEXT NOT NULL,
    date_precision  TEXT NOT NULL DEFAULT 'day'
                    CHECK(date_precision IN ('day','month','year','approx')),
    title           TEXT NOT NULL,
    description     TEXT,
    category        TEXT DEFAULT 'event' CHECK(category IN (
                        'event','filing','communication','hearing',
                        'incident','payment','discovery','other')),
    source_doc_id   UUID,
    source_file_id  UUID,
    fact_id         UUID REFERENCES facts(id) ON DELETE SET NULL,
    significance    TEXT DEFAULT 'normal' CHECK(significance IN ('low','normal','high','critical')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS witnesses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    role            TEXT DEFAULT 'fact' CHECK(role IN (
                        'fact','expert','character','hostile','other')),
    contact_info    TEXT,
    subpoena_status TEXT DEFAULT 'not_issued' CHECK(subpoena_status IN (
                        'not_issued','issued','served','quashed','appeared')),
    testimony_summary TEXT,
    credibility_notes TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS checklist_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    category        TEXT NOT NULL,
    label           TEXT NOT NULL,
    done            BOOLEAN DEFAULT false,
    notes           TEXT,
    sort_order      INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── FILES & DOCUMENTS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS file_registry (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    filename        TEXT NOT NULL,
    relative_path   TEXT NOT NULL,
    storage_path    TEXT,
    category        TEXT DEFAULT 'inbox' CHECK(category IN (
                        'inbox','evidence','filing','correspondence',
                        'media','export','other')),
    mime_type       TEXT,
    file_size       BIGINT,
    content_hash    TEXT,
    ingested        BOOLEAN DEFAULT false,
    ingested_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS documents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    file_id         UUID REFERENCES file_registry(id) ON DELETE SET NULL,
    title           TEXT NOT NULL,
    doc_type        TEXT DEFAULT 'other' CHECK(doc_type IN (
                        'filing','motion','order','letter','email','transcript',
                        'contract','report','exhibit','photo','video','other')),
    doc_date        TEXT,
    author          TEXT,
    recipient       TEXT,
    page_count      INTEGER,
    extracted_text  TEXT,
    summary         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS text_chunks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    file_id         UUID REFERENCES file_registry(id) ON DELETE SET NULL,
    chunk_index     INTEGER NOT NULL,
    chunk_text      TEXT NOT NULL,
    page_number     INTEGER,
    char_start      INTEGER,
    char_end        INTEGER,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS citations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_type     TEXT NOT NULL CHECK(source_type IN (
                        'fact','task','document','file','chunk','timeline_event',
                        'evidence_item','witness','deadline','issue')),
    source_id       UUID NOT NULL,
    cited_by_type   TEXT NOT NULL,
    cited_by_id     UUID NOT NULL,
    excerpt         TEXT,
    page_ref        TEXT,
    confidence      REAL DEFAULT 1.0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── KNOWLEDGE GRAPH ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS entity_nodes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    label           TEXT NOT NULL,
    type            TEXT NOT NULL CHECK(type IN (
                        'person','organization','location','document',
                        'event','claim','issue','statute','date','exhibit')),
    canonical_name  TEXT,
    aliases         TEXT,
    source_type     TEXT,
    source_id       UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS entity_edges (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_node_id    UUID NOT NULL REFERENCES entity_nodes(id) ON DELETE CASCADE,
    to_node_id      UUID NOT NULL REFERENCES entity_nodes(id) ON DELETE CASCADE,
    relationship    TEXT NOT NULL CHECK(relationship IN (
                        'involves','mentions','occurred_on','contradicts','supports',
                        'responds_to','filed_by','served_on','linked_to_issue',
                        'cites','derived_from','owns','employed_by','related_to')),
    weight          REAL DEFAULT 1.0,
    source_chunk_id UUID REFERENCES text_chunks(id) ON DELETE SET NULL,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── AGENT ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    title           TEXT,
    mode            TEXT DEFAULT 'qa' CHECK(mode IN (
                        'qa','summarize','chronology','contradiction','task_gen','research')),
    status          TEXT DEFAULT 'active' CHECK(status IN ('active','closed','archived')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agent_messages (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID NOT NULL REFERENCES agent_sessions(id) ON DELETE CASCADE,
    role            TEXT NOT NULL CHECK(role IN ('user','assistant','system','tool')),
    content         TEXT NOT NULL,
    token_count     INTEGER,
    model           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS agent_context_items (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id      UUID NOT NULL REFERENCES agent_sessions(id) ON DELETE CASCADE,
    message_id      UUID REFERENCES agent_messages(id) ON DELETE SET NULL,
    source_type     TEXT NOT NULL,
    source_id       UUID NOT NULL,
    relevance_score REAL,
    included        BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS matter_links (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matter_id       UUID NOT NULL REFERENCES matter(id) ON DELETE CASCADE,
    source_type     TEXT NOT NULL,
    source_id       UUID NOT NULL,
    target_type     TEXT NOT NULL,
    target_id       UUID NOT NULL,
    link_type       TEXT DEFAULT 'supports',
    metadata        JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── INDEXES ───────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_matter_user ON matter(user_id);
CREATE INDEX IF NOT EXISTS idx_facts_matter ON facts(matter_id);
CREATE INDEX IF NOT EXISTS idx_facts_issue ON facts(issue_id);
CREATE INDEX IF NOT EXISTS idx_evidence_matter ON evidence_items(matter_id);
CREATE INDEX IF NOT EXISTS idx_tasks_matter ON tasks(matter_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status, priority);
CREATE INDEX IF NOT EXISTS idx_deadlines_date ON deadlines(deadline_date, status);
CREATE INDEX IF NOT EXISTS idx_timeline_date ON timeline_events(event_date, matter_id);
CREATE INDEX IF NOT EXISTS idx_file_hash ON file_registry(content_hash);
CREATE INDEX IF NOT EXISTS idx_chunks_doc ON text_chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_entity_nodes_type ON entity_nodes(type, matter_id);
CREATE INDEX IF NOT EXISTS idx_entity_edges ON entity_edges(from_node_id, relationship);
CREATE INDEX IF NOT EXISTS idx_citations_source ON citations(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_agent_messages_session ON agent_messages(session_id);

-- ── FULL TEXT SEARCH ──────────────────────────────────────────────
ALTER TABLE facts ADD COLUMN IF NOT EXISTS fts tsvector
    GENERATED ALWAYS AS (to_tsvector('english', coalesce(statement,'') || ' ' || coalesce(excerpt,''))) STORED;
CREATE INDEX IF NOT EXISTS idx_facts_fts ON facts USING GIN(fts);

ALTER TABLE documents ADD COLUMN IF NOT EXISTS fts tsvector
    GENERATED ALWAYS AS (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(extracted_text,''))) STORED;
CREATE INDEX IF NOT EXISTS idx_documents_fts ON documents USING GIN(fts);

ALTER TABLE text_chunks ADD COLUMN IF NOT EXISTS fts tsvector
    GENERATED ALWAYS AS (to_tsvector('english', coalesce(chunk_text,''))) STORED;
CREATE INDEX IF NOT EXISTS idx_chunks_fts ON text_chunks USING GIN(fts);

-- ── ROW LEVEL SECURITY ──────────────────────────────────────────
ALTER TABLE matter ENABLE ROW LEVEL SECURITY;
ALTER TABLE parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE facts ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE deadlines ENABLE ROW LEVEL SECURITY;
ALTER TABLE timeline_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE witnesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE checklist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE file_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE text_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE citations ENABLE ROW LEVEL SECURITY;
ALTER TABLE entity_nodes ENABLE ROW LEVEL SECURITY;
ALTER TABLE entity_edges ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_context_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE matter_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Matter: user can CRUD their own, admins can see all
CREATE POLICY matter_policy ON matter FOR ALL USING (
    auth.uid() = user_id OR is_admin()
);

-- Helper function: check if user owns the matter
CREATE OR REPLACE FUNCTION user_owns_matter(mid UUID) RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM matter WHERE id = mid AND user_id = auth.uid());
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Child tables: user can CRUD if they own the parent matter, admins can access all
CREATE POLICY parties_policy ON parties FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY issues_policy ON issues FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY facts_policy ON facts FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY evidence_policy ON evidence_items FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY tasks_policy ON tasks FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY deadlines_policy ON deadlines FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY timeline_policy ON timeline_events FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY witnesses_policy ON witnesses FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY checklist_policy ON checklist_items FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY file_registry_policy ON file_registry FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY documents_policy ON documents FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY text_chunks_policy ON text_chunks FOR ALL
    USING (EXISTS (SELECT 1 FROM documents d WHERE d.id = document_id AND (user_owns_matter(d.matter_id) OR is_admin())));
CREATE POLICY entity_nodes_policy ON entity_nodes FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY entity_edges_policy ON entity_edges FOR ALL
    USING (EXISTS (SELECT 1 FROM entity_nodes n WHERE n.id = from_node_id AND (user_owns_matter(n.matter_id) OR is_admin())));
CREATE POLICY agent_sessions_policy ON agent_sessions FOR ALL USING (user_owns_matter(matter_id) OR is_admin());
CREATE POLICY agent_messages_policy ON agent_messages FOR ALL
    USING (EXISTS (SELECT 1 FROM agent_sessions s WHERE s.id = session_id AND (user_owns_matter(s.matter_id) OR is_admin())));
CREATE POLICY agent_context_policy ON agent_context_items FOR ALL
    USING (EXISTS (SELECT 1 FROM agent_sessions s WHERE s.id = session_id AND (user_owns_matter(s.matter_id) OR is_admin())));
CREATE POLICY citations_policy ON citations FOR ALL USING (true); -- citations are cross-linked, rely on app logic
CREATE POLICY matter_links_policy ON matter_links FOR ALL USING (user_owns_matter(matter_id) OR is_admin());

-- ── UPDATED_AT TRIGGER ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER matter_updated_at BEFORE UPDATE ON matter FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER facts_updated_at BEFORE UPDATE ON facts FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER evidence_updated_at BEFORE UPDATE ON evidence_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER witnesses_updated_at BEFORE UPDATE ON witnesses FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER documents_updated_at BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER agent_sessions_updated_at BEFORE UPDATE ON agent_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
