ALTER TABLE provider_profiles ALTER COLUMN is_visible SET DEFAULT false;

CREATE TYPE doc_status AS ENUM ('pending', 'under_review', 'approved', 'rejected');
ALTER TABLE provider_profiles ADD COLUMN doc_status doc_status NOT NULL DEFAULT 'pending';
ALTER TABLE provider_profiles ADD COLUMN doc_cpf_key TEXT;
ALTER TABLE provider_profiles ADD COLUMN doc_id_key TEXT;
