# Deploying to agents.noonstudio.africa

Internal runbook for Noon Studio Africa's self-hosted fork of Tone. This is
**not** upstream tonehq documentation — see `FORK_NOTES.md` for what's been
changed and why, and for the licensing/product constraints this deployment
operates under (read that before onboarding your first paying client).

## Model

Single self-hosted instance, one Noon Studio org. Clients get an agent (a
phone number and/or a website chat widget), not a login. You manage
everything from this one dashboard. This avoids the multi-tenant /
per-client-repo complexity and the licensing questions that come with
redistributing the software itself.

## Prerequisites (accounts you need before starting)

1. **A VM** — Hetzner CX22 or DigitalOcean equivalent (4GB RAM minimum),
   Ubuntu 22.04+, Docker + Docker Compose plugin installed.
2. **DNS access** for noonstudio.africa — you'll add one A record.
3. **Cloudflare account** with an R2 bucket created (object storage for call
   recordings and knowledge-base uploads). Cloudflare dashboard → R2 →
   create bucket `noonstudio-tone-recordings` → Manage API tokens → create a
   token scoped to that bucket with Object Read & Write.
4. **Provider API keys** — at minimum an LLM key (OpenRouter, real one this
   time — see `FORK_NOTES.md` for how to verify it's the right format) and
   an embeddings key (OpenAI or Google) if you want the knowledge-base RAG
   feature working.
5. **Voice**: still blocked — see `FORK_NOTES.md` "Voice pipeline" section.
   Everything below stands up the dashboard, agent config, and knowledge
   base; it does not get you live phone calls yet.

## First deploy

```bash
# On the VM, as a non-root user in the docker group:
git clone git@github.com:pharisjohnson/tone.git
cd tone
cp .env.production.example .env.production
# Edit .env.production: fill in every TODO — DB password, JWT_SECRET_KEY
# (generate with: python3 -c "import secrets; print(secrets.token_urlsafe(64))"),
# R2 credentials, and your LLM/embedding provider keys.

docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build

# First-time DB setup (same steps as local dev, against the prod containers):
docker compose -f docker-compose.prod.yml --env-file .env.production exec api alembic upgrade head
docker compose -f docker-compose.prod.yml --env-file .env.production exec api python dev/seed.py
```

The seed script is interactive (org name / owner email / password) — run it
with `-it` if compose exec doesn't attach a TTY by default:
`docker compose -f docker-compose.prod.yml --env-file .env.production exec -it api python dev/seed.py`

## DNS

Add an **A record**: `agents.noonstudio.africa` → your VM's public IP.
Caddy (already in the compose stack) auto-provisions a Let's Encrypt cert on
first request to that hostname — no manual TLS setup.

## Verifying it's up

- `https://agents.noonstudio.africa` → login page
- `https://agents.noonstudio.africa/docs` → FastAPI Swagger UI
- `docker compose -f docker-compose.prod.yml --env-file .env.production logs -f api` to watch startup

## Ongoing maintenance

- **Pulling upstream fixes:** `git fetch upstream && git merge upstream/dev`
  (or cherry-pick) — `upstream` remote points at `tonehq/tone`.
- **Redeploy after a change:** `docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build`
- **DB backups:** the `postgres_data` volume is the source of truth. At
  minimum, cron a nightly `docker compose exec postgres pg_dump -U tone tone`
  to somewhere off the VM (R2 works fine for this too).
- **New client agent:** create it in the dashboard like we did for the Noon
  Studio Africa website assistant — no deploy needed, it's just DB rows.

## Known gaps before this is client-ready

See `FORK_NOTES.md` for the full list. Headline items:
1. No working voice pipeline (`tone-pipecat` access or an open-`pipecat-ai`
   rewrite — neither done yet).
2. `organizations.max_agents` defaults to 5 on the seeded org — check/raise
   before you have more than 5 client agents.
3. No automated backups configured yet (see above — you have to set this up).
