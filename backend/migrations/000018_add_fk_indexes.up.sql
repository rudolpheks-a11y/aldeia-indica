-- provider_services.provider_id is queried directly in the search hot path
-- (getCategories / batchCategories) but had no leading index — only
-- (community_id, category_id) and (category_id, community_id) existed.
CREATE INDEX idx_provider_services_provider ON provider_services(provider_id);

-- service_request_responses.request_id had no index at all (only the
-- primary key) despite ListResponses filtering directly on it.
CREATE INDEX idx_service_request_responses_request ON service_request_responses(request_id);
