-- QiEvidence Domain Schema
-- Version: 1.0 (MVP-ready)
-- Schema: qievidence

CREATE SCHEMA IF NOT EXISTS qievidence;

SET search_path TO qievidence, public;

-- Enums for Evidence
CREATE TYPE qievidence.inference_type AS ENUM (
    'observed', 
    'stated', 
    'ocr_extracted', 
    'metadata_derived', 
    'inferred', 
    'uncertain', 
    'conflict_detected'
);

CREATE TYPE qievidence.confidence_score AS DOMAIN AS NUMERIC(3, 2) CHECK (VALUE >= 0.0 AND VALUE <= 1.0);

-- Table 1: evidence_records - Master artifact registry
CREATE TABLE qievidence.evidence_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL, -- FK to tenants
    case_id UUID NOT NULL, -- FK to cases
    parent_record_id UUID REFERENCES qievidence.evidence_records(id),
    file_path TEXT NOT NULL,
    file_hash TEXT UNIQUE NOT NULL,
    metadata JSONB DEFAULT '{}',
    status TEXT DEFAULT 'pending', -- pending, processing, completed, error
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID -- FK to profiles/members
);

-- Table 2: evidence_segments - Chunked slices of long media/documents
CREATE TABLE qievidence.evidence_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_record_id UUID NOT NULL REFERENCES qievidence.evidence_records(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    start_timestamp INTERVAL,
    end_timestamp INTERVAL,
    page_number INTEGER,
    segment_type TEXT, -- frame, audio_chunk, page_range
    content_summary TEXT,
    raw_data JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 3: evidence_entities - Canonical people, vehicles, locations, accounts
CREATE TABLE qievidence.evidence_entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    entity_type TEXT NOT NULL, -- person, vehicle, location, account, etc.
    name TEXT NOT NULL,
    canonical_id TEXT, -- For normalization across cases
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 4: evidence_entity_mentions - Where each entity appears
CREATE TABLE qievidence.evidence_entity_mentions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id UUID NOT NULL REFERENCES qievidence.evidence_entities(id) ON DELETE CASCADE,
    source_record_id UUID NOT NULL REFERENCES qievidence.evidence_records(id) ON DELETE CASCADE,
    segment_id UUID REFERENCES qievidence.evidence_segments(id),
    tenant_id UUID NOT NULL,
    inference qievidence.inference_type NOT NULL,
    confidence qievidence.confidence_score DEFAULT 1.0,
    uncertainty_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 5: evidence_events - Observed or extracted events
CREATE TABLE qievidence.evidence_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    case_id UUID NOT NULL,
    source_record_id UUID REFERENCES qievidence.evidence_records(id),
    segment_id UUID REFERENCES qievidence.evidence_segments(id),
    event_type TEXT NOT NULL,
    event_timestamp TIMESTAMP WITH TIME ZONE,
    relative_timestamp INTERVAL,
    description TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 6: evidence_claims - Statements/assertions extracted
CREATE TABLE qievidence.evidence_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    source_record_id UUID NOT NULL REFERENCES qievidence.evidence_records(id),
    segment_id UUID REFERENCES qievidence.evidence_segments(id),
    claimant_entity_id UUID REFERENCES qievidence.evidence_entities(id),
    claim_text TEXT NOT NULL,
    is_contested BOOLEAN DEFAULT FALSE,
    confidence qievidence.confidence_score DEFAULT 1.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 7: evidence_observations - Machine-grounded visual/textual facts
CREATE TABLE qievidence.evidence_observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    source_record_id UUID NOT NULL REFERENCES qievidence.evidence_records(id),
    segment_id UUID REFERENCES qievidence.evidence_segments(id),
    observation_text TEXT NOT NULL,
    observation_type TEXT, -- visual, ocr, audio_event
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 8: evidence_links - Cross-references between any two objects
CREATE TABLE qievidence.evidence_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    source_type TEXT NOT NULL, -- evidence_events, evidence_claims, etc.
    source_id UUID NOT NULL,
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    link_type TEXT NOT NULL, -- references, supports, contradicts, overlaps
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 9: evidence_conflicts - Detected inconsistencies
CREATE TABLE qievidence.evidence_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    case_id UUID NOT NULL,
    conflict_type TEXT NOT NULL, -- internal_contradiction, cross_reference_conflict
    description TEXT NOT NULL,
    severity TEXT DEFAULT 'medium', -- low, medium, high, critical
    evidence_link_ids UUID[] DEFAULT '{}',
    status TEXT DEFAULT 'open', -- open, acknowledged, resolved, dismissed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 10: evidence_timelines - Named timeline containers
CREATE TABLE qievidence.evidence_timelines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    case_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 11: evidence_timeline_items - Ordered items in timelines
CREATE TABLE qievidence.evidence_timeline_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timeline_id UUID NOT NULL REFERENCES qievidence.evidence_timelines(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL,
    item_type TEXT NOT NULL, -- event, observation, claim
    item_id UUID NOT NULL, -- polymorphic reference
    sort_order INTEGER NOT NULL,
    overridden_timestamp TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Table 12: evidence_reviews - Human review queue
CREATE TABLE qievidence.evidence_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    reference_type TEXT NOT NULL, -- evidence_records, evidence_conflicts, etc.
    reference_id UUID NOT NULL,
    reviewer_id UUID, -- FK to profiles/members
    review_notes TEXT,
    resolution TEXT,
    status TEXT DEFAULT 'pending', -- pending, in_review, completed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

-- Indexes for performance
CREATE INDEX idx_evidence_records_tenant_case ON qievidence.evidence_records(tenant_id, case_id);
CREATE INDEX idx_evidence_segments_source ON qievidence.evidence_segments(source_record_id);
CREATE INDEX idx_evidence_entities_tenant ON qievidence.evidence_entities(tenant_id);
CREATE INDEX idx_evidence_mentions_entity ON qievidence.evidence_entity_mentions(entity_id);
CREATE INDEX idx_evidence_mentions_source ON qievidence.evidence_entity_mentions(source_record_id);
CREATE INDEX idx_evidence_events_case ON qievidence.evidence_events(tenant_id, case_id);
CREATE INDEX idx_evidence_claims_source ON qievidence.evidence_claims(source_record_id);
CREATE INDEX idx_evidence_observations_source ON qievidence.evidence_observations(source_record_id);
CREATE INDEX idx_evidence_links_source ON qievidence.evidence_links(source_id);
CREATE INDEX idx_evidence_links_target ON qievidence.evidence_links(target_id);
CREATE INDEX idx_evidence_conflicts_case ON qievidence.evidence_conflicts(tenant_id, case_id);
CREATE INDEX idx_evidence_timeline_items_timeline ON qievidence.evidence_timeline_items(timeline_id);
CREATE INDEX idx_evidence_reviews_tenant ON qievidence.evidence_reviews(tenant_id);
CREATE INDEX idx_evidence_reviews_status ON qievidence.evidence_reviews(status);
