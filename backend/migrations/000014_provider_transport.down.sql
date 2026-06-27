ALTER TABLE provider_profiles
    DROP COLUMN IF EXISTS transport_type,
    DROP COLUMN IF EXISTS needs_transport;
