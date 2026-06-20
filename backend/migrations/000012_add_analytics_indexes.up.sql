-- Faster event counting by type+period for dashboard queries
CREATE INDEX idx_provider_events_dashboard
    ON provider_events(provider_id, event_type, occurred_at DESC);

-- Covering index for category ranking (providers sorted by score within category)
CREATE INDEX idx_provider_services_category_score
    ON provider_services(category_id, community_id)
    INCLUDE (provider_id);
