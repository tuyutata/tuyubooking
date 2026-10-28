-- TuyuBooking 唯一核心数据库结构基线。
-- 中文注释：业务实体由 Rust 生成 UUIDv7；幂等记录和一对一实例绑定直接使用现有自然键。

CREATE SCHEMA IF NOT EXISTS tuyu_core;

CREATE TABLE tuyu_core.baselines (
    schema_name text PRIMARY KEY,
    schema_hash char(64) NOT NULL,
    initialized_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tuyu_core.installation (
    initialized_at timestamptz,
    id uuid PRIMARY KEY,
    instance_name text NOT NULL,
    status text NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'retired')),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE tuyu_core.modules (
    installation_id uuid NOT NULL REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    module_key text NOT NULL
        CHECK (module_key IN ('hotel', 'restaurant', 'tour', 'ticket')),
    is_enabled boolean NOT NULL DEFAULT false,
    PRIMARY KEY (installation_id, module_key)
);

CREATE TABLE tuyu_core.merchants (
    merchant_id uuid PRIMARY KEY,
    installation_id uuid NOT NULL REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    institution_id text,
    merchant_name text NOT NULL,
    legal_name text,
    locale_code text NOT NULL DEFAULT 'zh-CN' CHECK (locale_code IN ('zh-CN', 'en-US')),
    time_zone text NOT NULL,
    currency_code char(3) NOT NULL,
    merchant_state text NOT NULL DEFAULT 'active'
        CHECK (merchant_state IN ('active', 'suspended', 'closed')),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_version bigint NOT NULL DEFAULT 1 CHECK (row_version > 0),
    UNIQUE (installation_id, merchant_name)
);

CREATE TABLE tuyu_core.identities (
    installation_id uuid PRIMARY KEY REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    instance_id text NOT NULL UNIQUE CHECK (instance_id ~ '^tmi_[0-9a-f]{32}$'),
    owner_id text NOT NULL,
    instance_key bytea NOT NULL CHECK (octet_length(instance_key) = 32),
    instance_state text NOT NULL DEFAULT 'active' CHECK (instance_state IN ('active', 'suspended', 'retired')),
    registered_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_version bigint NOT NULL DEFAULT 1 CHECK (row_version > 0)
);

CREATE TABLE tuyu_core.local_system_administrator (
    id uuid PRIMARY KEY,
    installation_id uuid NOT NULL REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    public_key bytea NOT NULL CHECK (octet_length(public_key) = 32),
    name varchar(30),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
    UNIQUE (installation_id, public_key),
    CHECK (name IS NULL OR char_length(btrim(name)) BETWEEN 1 AND 30)
);

CREATE TABLE tuyu_core.administrator_audit_log (
    id uuid PRIMARY KEY,
    installation_id uuid NOT NULL REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    administrator_id uuid REFERENCES tuyu_core.local_system_administrator(id) ON DELETE SET NULL,
    actor_public_key_fingerprint char(64),
    target_administrator_id uuid REFERENCES tuyu_core.local_system_administrator(id)
        ON DELETE SET NULL,
    target_public_key_fingerprint char(64) NOT NULL,
    session_id uuid,
    action text NOT NULL,
    outcome text NOT NULL DEFAULT 'success' CHECK (outcome IN ('success', 'denied')),
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tuyu_core.publications (
    installation_id uuid PRIMARY KEY REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    instance_id text NOT NULL UNIQUE,
    owner_id text NOT NULL,
    instance_key bytea NOT NULL CHECK (octet_length(instance_key) = 32),
    publication_revision bigint NOT NULL DEFAULT 1 CHECK (publication_revision > 0),
    enabled_modules jsonb NOT NULL DEFAULT '[]'::jsonb,
    service_endpoint text,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tuyu_core.staff (
    staff_id uuid PRIMARY KEY,
    merchant_id uuid NOT NULL REFERENCES tuyu_core.merchants(merchant_id) ON DELETE CASCADE,
    staff_name text NOT NULL,
    employee_code text,
    staff_state text NOT NULL DEFAULT 'active'
        CHECK (staff_state IN ('active', 'disabled')),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_version bigint NOT NULL DEFAULT 1 CHECK (row_version > 0),
    UNIQUE (merchant_id, employee_code)
);

CREATE TABLE tuyu_core.roles (
    assignment_id uuid PRIMARY KEY,
    staff_id uuid NOT NULL REFERENCES tuyu_core.staff(staff_id) ON DELETE CASCADE,
    domain_name text NOT NULL CHECK (domain_name IN ('hotel', 'restaurant', 'tour', 'ticket')),
    role_code text NOT NULL,
    scope_id uuid,
    granted_by uuid REFERENCES tuyu_core.staff(staff_id) ON DELETE SET NULL,
    granted_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_version bigint NOT NULL DEFAULT 1 CHECK (row_version > 0),
    UNIQUE NULLS NOT DISTINCT (staff_id, domain_name, role_code, scope_id)
);

CREATE TABLE tuyu_core.customers (
    customer_id uuid PRIMARY KEY,
    merchant_id uuid NOT NULL REFERENCES tuyu_core.merchants(merchant_id) ON DELETE CASCADE,
    tuyu_id text,
    customer_name text,
    contact_fingerprint char(64),
    customer_state text NOT NULL DEFAULT 'active'
        CHECK (customer_state IN ('active', 'anonymized', 'blocked')),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_version bigint NOT NULL DEFAULT 1 CHECK (row_version > 0)
);

CREATE TABLE tuyu_core.requests (
    installation_id uuid NOT NULL REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    request_scope text NOT NULL,
    request_key text NOT NULL,
    request_hash char(64) NOT NULL,
    response_status integer,
    response_body jsonb,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_version bigint NOT NULL DEFAULT 1 CHECK (row_version > 0),
    PRIMARY KEY (installation_id, request_scope, request_key)
);

CREATE TABLE tuyu_core.events (
    event_id uuid PRIMARY KEY,
    installation_id uuid NOT NULL REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    domain_name text NOT NULL CHECK (domain_name IN ('core', 'hotel', 'restaurant', 'tour', 'ticket')),
    aggregate_type text NOT NULL,
    aggregate_id uuid NOT NULL,
    event_type text NOT NULL,
    event_data jsonb NOT NULL,
    occurred_at timestamptz NOT NULL,
    published_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_version bigint NOT NULL DEFAULT 1 CHECK (row_version > 0)
);

CREATE TABLE tuyu_core.audits (
    audit_id uuid PRIMARY KEY,
    installation_id uuid NOT NULL REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    actor_id uuid,
    domain_name text NOT NULL CHECK (domain_name IN ('core', 'hotel', 'restaurant', 'tour', 'ticket')),
    audit_action text NOT NULL,
    object_type text NOT NULL,
    object_id uuid NOT NULL,
    audit_reason text,
    before_digest char(64),
    after_digest char(64),
    audit_data jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    row_version bigint NOT NULL DEFAULT 1 CHECK (row_version > 0)
);

CREATE INDEX staff_merchant_idx ON tuyu_core.staff(merchant_id, staff_state);
CREATE INDEX idx_core_local_administrator_status
    ON tuyu_core.local_system_administrator(installation_id, status);
CREATE INDEX idx_core_admin_audit_actor ON tuyu_core.administrator_audit_log(
    installation_id, administrator_id, occurred_at DESC
);

CREATE OR REPLACE FUNCTION tuyu_core.reject_administrator_identity_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.installation_id <> OLD.installation_id OR NEW.public_key <> OLD.public_key THEN
        RAISE EXCEPTION 'administrator public key is immutable';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER local_system_administrator_identity_immutable
BEFORE UPDATE ON tuyu_core.local_system_administrator
FOR EACH ROW EXECUTE FUNCTION tuyu_core.reject_administrator_identity_change();
CREATE INDEX customers_merchant_idx ON tuyu_core.customers(merchant_id, customer_state);
CREATE INDEX events_pending_idx ON tuyu_core.events(created_at) WHERE published_at IS NULL;
CREATE INDEX audits_object_idx ON tuyu_core.audits(domain_name, object_type, object_id, occurred_at);
CREATE INDEX requests_expiry_idx ON tuyu_core.requests(expires_at);

CREATE TABLE IF NOT EXISTS tuyu_core.administrator_assertion (
    assertion_hash bytea PRIMARY KEY,
    installation_id uuid NOT NULL
        REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    local_session_id uuid NOT NULL,
    administrator_id uuid NOT NULL
        REFERENCES tuyu_core.local_system_administrator(id) ON DELETE CASCADE,
    administrator_public_key_fingerprint char(64) NOT NULL
        CHECK (administrator_public_key_fingerprint ~ '^[0-9a-f]{64}$'),
    local_session_expires_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    consumed_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (expires_at <= local_session_expires_at)
);

CREATE INDEX IF NOT EXISTS administrator_assertion_expiry_idx
    ON tuyu_core.administrator_assertion (expires_at)
    WHERE consumed_at IS NULL AND revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS administrator_assertion_administrator_idx
    ON tuyu_core.administrator_assertion (installation_id, administrator_id);

CREATE TABLE IF NOT EXISTS tuyu_core.upstream_administrator_session (
    upstream_session_id text PRIMARY KEY,
    assertion_hash bytea NOT NULL
        REFERENCES tuyu_core.administrator_assertion(assertion_hash) ON DELETE CASCADE,
    installation_id uuid NOT NULL
        REFERENCES tuyu_core.installation(id) ON DELETE CASCADE,
    administrator_id uuid NOT NULL,
    administrator_public_key_fingerprint char(64) NOT NULL
        CHECK (administrator_public_key_fingerprint ~ '^[0-9a-f]{64}$'),
    upstream_user text NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS upstream_administrator_session_expiry_idx
    ON tuyu_core.upstream_administrator_session (expires_at)
    WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS upstream_administrator_session_administrator_idx
    ON tuyu_core.upstream_administrator_session (installation_id, administrator_id);

CREATE TABLE IF NOT EXISTS tuyu_core.administrator_bridge_audit (
    audit_id bigserial PRIMARY KEY,
    assertion_hash bytea,
    upstream_session_id text,
    installation_id uuid REFERENCES tuyu_core.installation(id) ON DELETE SET NULL,
    administrator_id uuid,
    administrator_public_key_fingerprint char(64),
    action text NOT NULL,
    outcome text NOT NULL CHECK (outcome IN ('SUCCESS', 'DENIED')),
    request_path text,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS administrator_bridge_audit_local_identity_idx
    ON tuyu_core.administrator_bridge_audit
       (installation_id, administrator_id, created_at DESC);
