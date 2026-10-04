-- TuyuBooking framework bootstrap. The installer connects to the existing
-- merchant-owned `tuyubooking` database and never creates another database.
CREATE SCHEMA IF NOT EXISTS tuyu_core;
CREATE SCHEMA IF NOT EXISTS module_kamra AUTHORIZATION tuyu_kamra_app;

GRANT USAGE ON SCHEMA tuyu_core TO tuyu_kamra_app;
GRANT ALL PRIVILEGES ON SCHEMA module_kamra TO tuyu_kamra_app;
ALTER ROLE tuyu_kamra_app IN DATABASE tuyubooking
  SET search_path TO module_kamra, pg_catalog;

CREATE TABLE IF NOT EXISTS tuyu_core.module_registry (
  module_id text PRIMARY KEY,
  schema_name text UNIQUE NOT NULL CHECK (schema_name LIKE 'module\_%'),
  enabled boolean NOT NULL DEFAULT true,
  installed_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO tuyu_core.module_registry (module_id, schema_name)
VALUES ('kamra', 'module_kamra')
ON CONFLICT (module_id) DO UPDATE SET schema_name = EXCLUDED.schema_name;

-- URY is an independent Frappe site and never shares Kamra's schema or role.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tuyu_ury_app') THEN
        CREATE ROLE tuyu_ury_app LOGIN;
    END IF;
END
$$;
CREATE SCHEMA IF NOT EXISTS module_ury AUTHORIZATION tuyu_ury_app;
GRANT USAGE, CREATE ON SCHEMA module_ury TO tuyu_ury_app;
ALTER ROLE tuyu_ury_app IN DATABASE tuyubooking SET search_path TO module_ury, public;

-- URY is an independent Frappe site and never shares Kamra's schema or role.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tuyu_ury_app') THEN
        CREATE ROLE tuyu_ury_app LOGIN;
    END IF;
END
$$;
CREATE SCHEMA IF NOT EXISTS module_ury AUTHORIZATION tuyu_ury_app;
GRANT USAGE, CREATE ON SCHEMA module_ury TO tuyu_ury_app;
ALTER ROLE tuyu_ury_app IN DATABASE tuyubooking SET search_path TO module_ury, public;
