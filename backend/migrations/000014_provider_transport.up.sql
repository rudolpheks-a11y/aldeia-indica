ALTER TABLE provider_profiles
    ADD COLUMN needs_transport  BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN transport_type   TEXT CHECK (transport_type IN ('public', 'fuel'));
