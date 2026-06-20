#!/usr/bin/env bash
# Creates the required MinIO buckets for local development.
# Run once after MinIO starts: ./scripts/setup-minio.sh
set -e

MINIO_URL="http://localhost:9000"
ALIAS="aldeia-local"

echo "Waiting for MinIO..."
until curl -sf "$MINIO_URL/minio/health/live" > /dev/null; do sleep 1; done

mc alias set "$ALIAS" "$MINIO_URL" minioadmin minioadmin

mc mb --ignore-existing "$ALIAS/aldeia-public"
mc mb --ignore-existing "$ALIAS/aldeia-private"

# Public bucket: anonymous read (for provider photos)
mc anonymous set download "$ALIAS/aldeia-public"

echo "MinIO buckets ready."
