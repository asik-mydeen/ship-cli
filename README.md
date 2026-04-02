# ship — Zero-Fuss Deploy CLI

One command to go from idea to live app. Scaffolds a project, pushes to GitHub, deploys to Dokploy, wires up Supabase, creates DNS, configures auto-deploy — all in about 60 seconds.

```
ship new    →  answer 5 questions  →  live at https://myapp.yourdomain.com
```

## What It Does

```
ship new
```

1. **Asks** — project name, type (Node/Python/Rust), framework, port, subdomain
2. **Scaffolds** — full project with Supabase client pre-wired, TypeScript, health endpoints
3. **Creates GitHub repo** — pushes initial code
4. **Creates Dokploy project** — configures app, env vars, build type, domain
5. **Creates Cloudflare DNS** — CNAME + Tunnel ingress rule
6. **Sets up GitHub Actions** — workflow + encrypted secrets for auto-deploy
7. **Triggers first deploy** — your app is building before you finish reading the output

After that, every `git push` to `main` auto-deploys. No CI/CD config, no dashboards, no manual steps.

## Architecture

```
git push → GitHub Actions → Dokploy API (deploy) → Nixpacks build → Traefik
         → Cloudflare Tunnel → https://app.yourdomain.com
         → Supabase (auth + database + storage)
```

### Infrastructure Stack

| Layer | Service | Purpose |
|---|---|---|
| **Hosting** | [Dokploy](https://dokploy.com) | Container orchestration + Traefik reverse proxy |
| **Database** | [Supabase](https://supabase.com) (self-hosted) | Auth, Postgres, Storage |
| **DNS + CDN** | [Cloudflare](https://cloudflare.com) | DNS, TLS termination, Tunnel |
| **CI/CD** | GitHub Actions | Trigger Dokploy deploy on push |
| **Server** | TrueNAS / any Linux box | Runs Dokploy + Supabase via Docker |

## Supported Stacks

| Type | Frameworks | Build |
|---|---|---|
| **Node.js** | Next.js, Express, Fastify | Nixpacks (auto-detected) |
| **Python** | FastAPI, Flask | Nixpacks + Procfile |
| **Rust** | Axum, Actix | Nixpacks (cargo build) |

All scaffolds include TypeScript (Node), health endpoints, Supabase client, and `.env.example`.

## Setup on a New Machine

### Prerequisites

- **bash** (macOS/Linux)
- **git**
- **curl**
- **python3** with `pynacl` (`pip3 install pynacl`) — needed for encrypting GitHub Actions secrets

### 1. Clone and install

```bash
git clone https://github.com/asik-mydeen/ship-cli.git ~/.autodeploy
chmod +x ~/.autodeploy/ship
sudo ln -sf ~/.autodeploy/ship /usr/local/bin/ship
```

Or without sudo:

```bash
mkdir -p ~/.local/bin
ln -sf ~/.autodeploy/ship ~/.local/bin/ship
# Add to your shell profile if not already:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

### 2. Create `.env` (secrets)

```bash
cat > ~/.autodeploy/.env << 'EOF'
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
GITHUB_USERNAME=your-github-username
CLOUDFLARE_API_TOKEN=your-cloudflare-api-token
CLOUDFLARE_ZONE_ID=your-zone-id-hex-string
EOF
```

### 3. Create `.env.infra` (infrastructure config)

```bash
cat > ~/.autodeploy/.env.infra << 'EOF'
# Dokploy
DOKPLOY_URL="https://projects.yourdomain.com"
DOKPLOY_API_KEY="your-dokploy-api-key"

# Supabase (self-hosted)
SUPABASE_URL="https://supabase.yourdomain.com"
SUPABASE_API_URL="https://supabase-api.yourdomain.com"
SUPABASE_ANON_KEY="your-supabase-anon-key"
SUPABASE_SERVICE_KEY="your-supabase-service-role-key"

# Domain
DOMAIN_SUFFIX="yourdomain.com"

# Cloudflare Tunnel
CF_TUNNEL_CNAME="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.cfargotunnel.com"
CF_TUNNEL_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
CF_ACCOUNT_ID="your-cloudflare-account-id"

# Dokploy Traefik target (internal IP where Traefik listens)
DOKPLOY_TRAEFIK_TARGET="http://172.16.0.1:80"
EOF
```

### 4. Verify

```bash
ship          # Should print the help menu
ship status   # Should list your Dokploy projects
```

## Credentials Reference

Here's every credential needed and where to get it:

### `.env` — Secrets (never commit this)

| Variable | Where to get it | Scopes / permissions |
|---|---|---|
| `GITHUB_PAT` | [GitHub → Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens) | `repo`, `workflow`, `admin:repo_hook`, `delete_repo` |
| `GITHUB_USERNAME` | Your GitHub username (e.g. `asik-mydeen`) | — |
| `CLOUDFLARE_API_TOKEN` | [Cloudflare → Profile → API Tokens → Create Token](https://dash.cloudflare.com/profile/api-tokens) | Zone: DNS Edit · Account: Cloudflare Tunnel Edit |
| `CLOUDFLARE_ZONE_ID` | Cloudflare dashboard → your domain → Overview → right sidebar | — |

### `.env.infra` — Infrastructure config

| Variable | Where to get it |
|---|---|
| `DOKPLOY_URL` | Your Dokploy dashboard URL (e.g. `https://projects.yourdomain.com`) |
| `DOKPLOY_API_KEY` | Dokploy → Settings → Profile → API/CLI Section → Generate Token |
| `SUPABASE_URL` | Your Supabase Studio URL (e.g. `https://supabase.yourdomain.com`) |
| `SUPABASE_API_URL` | Your Supabase Kong API URL (e.g. `https://supabase-api.yourdomain.com`) |
| `SUPABASE_ANON_KEY` | Supabase Studio → Settings → API → `anon` `public` key |
| `SUPABASE_SERVICE_KEY` | Supabase Studio → Settings → API → `service_role` key |
| `DOMAIN_SUFFIX` | Your root domain (e.g. `yourdomain.com`) |
| `CF_TUNNEL_CNAME` | Cloudflare → Zero Trust → Networks → Tunnels → your tunnel → CNAME target |
| `CF_TUNNEL_ID` | Same place — the UUID in the tunnel CNAME (before `.cfargotunnel.com`) |
| `CF_ACCOUNT_ID` | Cloudflare dashboard → any domain → Overview → right sidebar → Account ID |
| `DOKPLOY_TRAEFIK_TARGET` | Internal IP:port where Dokploy's Traefik listens (usually `http://<server-ip>:80`) |

## Commands

### `ship new`

Interactive project creation wizard. Creates everything from scaffold to live deployment.

### `ship deploy`

Force-deploy the current project (must be in a directory with `.ship.json`).

```bash
cd my-project
ship deploy   # pushes to GitHub + triggers Dokploy deploy
```

### `ship status`

Check if the app is live. Run from inside a project dir, or from anywhere to list all Dokploy projects.

```bash
ship status
# ═══ Status: my-app ═══
#   Domain: https://my-app.yourdomain.com
#   App:    ● LIVE (HTTP 200)
```

### `ship destroy`

Tear down everything: Dokploy app, DNS record, tunnel route, and optionally the GitHub repo.

```bash
cd my-project
ship destroy
# Type project name to confirm: my-project
# ✔ Dokploy project removed
# ✔ DNS record removed
# ✔ Tunnel rule removed
# Also delete GitHub repo? [y/N]
```

## How Auto-Deploy Works

```
1. You push to main
2. GitHub Actions fires (.github/workflows/deploy.yml)
3. The workflow calls: POST dokploy.yourdomain.com/api/application.deploy
4. Dokploy pulls from git, builds with Nixpacks, deploys container
5. Traefik routes traffic via host header
6. Cloudflare Tunnel forwards external traffic to Traefik
7. Your app is live at https://app.yourdomain.com
```

Three GitHub secrets are auto-configured per repo:
- `DOKPLOY_URL` — your Dokploy instance
- `DOKPLOY_API_KEY` — API authentication
- `DOKPLOY_APP_ID` — which app to deploy

## Project Files

Each created project gets:

| File | Purpose |
|---|---|
| `.github/workflows/deploy.yml` | Auto-deploy on push to main |
| `.ship.json` | Project metadata (gitignored) — Dokploy IDs, domain, etc. |
| `.env.example` | Template with **placeholder values only** — never real secrets |
| `.gitignore` | Standard ignores for the language |
| `README.md` | Project readme with dev/deploy instructions |
| `.npmrc` | Forces public npm registry (prevents private registry leaks) |
| `nixpacks.toml` | Optional — pin Node version or customize build |

## ⛔ Security: Secrets

**Real secrets must NEVER appear in any committed file.** This includes `.env.example`, README, commit messages, and generated code.

Secrets live in exactly four places:

| Where | What | Committed? |
|---|---|---|
| `~/.autodeploy/.env` | GitHub PAT, Cloudflare token | ❌ Never |
| `~/.autodeploy/.env.infra` | Dokploy/Supabase keys, tunnel config | ❌ Never |
| Dokploy env vars | Runtime env for deployed apps | ❌ Set via API |
| GitHub Actions secrets | Deploy trigger credentials | ❌ Encrypted via API |

The `.env.example` in every scaffolded project uses **placeholder values only** (e.g. `your-supabase-anon-key`). The heredoc uses single quotes (`<< 'EOF'`) to prevent shell variable expansion.

**If you accidentally commit a secret:**
1. Rewrite history: `git filter-branch --force --tree-filter '...' -- --all`
2. Force-push: `git push --force`
3. Purge local refs: `git reflog expire --expire=now --all && git gc --prune=now`
4. **Rotate the credential** — removing from git is not enough, it was exposed the moment it was pushed

## Gotchas & Lessons Learned

These were discovered during real end-to-end testing:

### GitHub repo push race condition
GitHub returns 201 for repo creation but the repo isn't immediately pushable. `ship` retries up to 5 times with 3-second backoff.

### Cloudflare Tunnel needs ingress rules, not just DNS
A DNS CNAME alone returns 404. Each new subdomain also needs an **ingress rule** in the tunnel config pointing to Dokploy's Traefik (`http://<server-ip>:80`). `ship` does both automatically.

### Dokploy domains: `https: false` behind Cloudflare
Cloudflare terminates TLS at the edge. If Dokploy is configured with `https: true`, Traefik redirects HTTP→HTTPS → **infinite redirect loop**. Always use `https: false, certificateType: none`.

### Next.js `NEXT_PUBLIC_*` at build time
Next.js inlines `NEXT_PUBLIC_*` vars during `next build`. Set them as **Dokploy build args** (not just runtime env vars), otherwise the built app won't have them.

### Private npm registries leak into package-lock.json
If `~/.npmrc` points to a private registry, `npm install` resolves from there. Always add a project `.npmrc` with `registry=https://registry.npmjs.org`.

### Nixpacks > Dockerfile for most cases
Nixpacks auto-detects language/framework and builds without config. Use `nixpacks.toml` to pin Node version. Only use Dockerfile if you need custom multi-stage builds.

### Supabase RLS is mandatory
Always enable Row Level Security on tables with user data. Without it, any authenticated user can read all rows. Create policies scoped to `auth.uid() = user_id`.

### Supabase Google OAuth redirect flow
```
App → signInWithOAuth({redirectTo: "https://app.yourdomain.com/auth/callback"})
  → Supabase Auth → Google consent screen
  → Google → supabase-api.yourdomain.com/auth/v1/callback
  → Supabase → app.yourdomain.com/auth/callback (exchanges code for session)
```
Google Console must have `https://supabase-api.yourdomain.com/auth/v1/callback` as an authorized redirect URI.

### `pynacl` required for GitHub secrets
GitHub Actions secrets must be encrypted with the repo's public key using libsodium sealed boxes. Install: `pip3 install pynacl`.

## Notes

- **TLS is handled by Cloudflare** — Dokploy domains are configured with `https: false` to avoid redirect loops. The Cloudflare Tunnel terminates TLS at the edge.
- **Nixpacks auto-detects** your language and build command. No Dockerfile needed (but you can add one).
- **Supabase is optional** — answer "n" when prompted and the scaffold won't include Supabase dependencies.
- **Python projects** include a `Procfile` for Nixpacks to detect the start command.
- **The CLI is a single bash script** with zero dependencies beyond `bash`, `curl`, `git`, and `python3` + `pynacl`.

## License

MIT
