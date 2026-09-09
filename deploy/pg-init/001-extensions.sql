-- Enables pgvector on first container init (postgres image auto-runs
-- everything in /docker-entrypoint-initdb.d on an empty data volume only).
CREATE EXTENSION IF NOT EXISTS vector;
