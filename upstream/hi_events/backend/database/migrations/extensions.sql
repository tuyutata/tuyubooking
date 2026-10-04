-- pg_trgm is provisioned by TuyuBooking before the restricted app-role migration.
-- Keep this upstream hook executable without granting CREATE EXTENSION to the app role.
SELECT 1;
