# Fork notes — Noon Studio Africa

Why this fork exists, what's been changed from `tonehq/tone`, and the
constraints that matter before this becomes a client-facing product.

`upstream` remote = `tonehq/tone`. `origin` = this private fork.

## Business model this fork operates under

We host one instance, sell agents as a service (phone number / chat widget
per client). We do **not** distribute this codebase, a deployment, or a repo
copy to clients. That's a deliberate choice — see Licensing below.

## Licensing — read before reselling anything

- **Root `LICENSE` is MIT** (copyright techasso labs private limited). Core
  app code (everything outside `ee/`) is genuinely open — use, modify,
  self-host, no restriction beyond keeping the notice.
- **`ee/` folder** (Enterprise Edition) has a runtime license-key gate
  (`core/internal/license.py`, tiers free/pro/enterprise) but *no separate
  LICENSE file* carving it out of the root MIT grant. That's a real
  ambiguity in upstream's own repo, not something we introduced. We sidestep
  it entirely: `SKIP_LICENSE_CHECK=true` + no `TONE_LICENSE_KEY` means
  `is_ee_enabled()` is always `False`, so `main.py` never mounts the EE
  routers — that code is present in the checkout but never executes. If you
  ever want real EE features, get a written license from tonehq first;
  don't rely on the ambiguity.
- **`tone-pipecat` (private, Cloudsmith) is NOT open source** and is not in
  this repo. See "Voice pipeline" below — this is the actual blocker.

## Voice pipeline — the real gap

`requirements.txt` has `tone-pipecat` commented out (we don't have Cloudsmith
access). In its place, dev used the public `pipecat-ai` PyPI package, which
provides the same `pipecat.*` import namespace so the app *imports* cleanly.

This is **not** a real fix. `core/services/pipeline/` and `core/bot.py` are
written against tonehq's private fork's API surface, which has diverged from
public pipecat-ai in ways we've already hit (an OpenRouter LLM call failed
with "Missing Authentication header" during testing — root-caused to a bad
key, but the swap is a live risk for every other provider integration too,
untested). Two real paths forward, not yet decided:

1. Get Cloudsmith access from tonehq (partner/reseller conversation) and
   restore the real `tone-pipecat` dependency.
2. Commit to rewriting `core/services/pipeline/service_factory.py` and
   related files against public `pipecat-ai`'s actual API — a real
   engineering project, not a config change.

**Until one of these happens, this deployment cannot place or receive real
voice calls.** Everything else (dashboard, agent config, knowledge base
RAG, org/user management) works standalone.

## Local dev environment substitutions (don't carry these to prod as-is)

Built while getting this running the first time — `docker-compose.prod.yml`
uses real services instead, but noting what stood in for what during dev:

- **MinIO** stood in for Cloudflare R2 (`R2_ENDPOINT_URL=http://localhost:9500`
  — note: port 9000 was blocked by this dev sandbox's network policy, 9500
  worked; irrelevant once you're on a real VM with real R2).
- **Alembic migration bug**: `alembic/versions/e4a1c8b9f2d7_drop_orphan_agent_llm_eval_tables.py`
  used plain `op.drop_table(...)` on tables that only exist in some deployed
  envs (created outside migration history). On a fresh DB built purely from
  migrations, that crashes. Patched to `DROP TABLE IF EXISTS` — this is a
  real upstream bug, worth reporting to tonehq or fixing again if you rebase
  past this commit.
- **`shared/config.py` `MANDATORY_PROD_KEYS`**: dropped `INFISICAL_TOKEN`,
  `INFISICAL_PROJECT_ID`, `LOKI_URL`, `GRAFANA_API_KEY` — see the comment
  left in that file. Those are tonehq's managed-cloud secrets/observability
  stack, not core requirements. R2 and `BASE_CALL_URL` stay mandatory.

## Provider keys — a note on getting them right

We burned real time on this once already: a pasted "OpenRouter key" turned
out to be 32 characters with no recognizable prefix. Real OpenRouter keys
start with `sk-or-v1-` and run ~73 characters (from openrouter.ai/keys).
Before treating any provider key as good, check it against the provider's
actual documented format — the Agent Readiness panel's "Run deep test" in
the dashboard makes a real API call and will surface a genuine auth failure,
which is the reliable way to confirm a key works.

## Scaling considerations, not yet addressed

- `organizations.max_agents` defaults to 5 (seeded free tier). Check whether
  this is enforced anywhere before you're onboarding a 6th client agent —
  if so, raise it directly in the DB or find the upgrade path.
- Single-VM, single-Postgres — fine for a handful of clients, revisit if
  this grows into real scale (managed Postgres, more than one app instance
  behind Caddy, etc.).
