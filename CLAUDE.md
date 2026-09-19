# Svapna

Private, password-protected journal/blog. Entries are imported from Apple Notes, then searched, tagged, and analysed (word frequency etc.).

> **Status: mock-up.** Nothing below exists yet. Items marked `TODO` / `OPEN` are undecided. Update this file as decisions are made.

## Stack

- **Rails 8** (Ruby, latest stable), Hotwire (Turbo + Stimulus), Propshaft, importmap (no Node build step)
- **PostgreSQL 17**: primary store *and* the search engine (full-text search + trigram + unaccent)
- **Tailwind CSS v4** via `tailwindcss-rails`
- **Auth**: Rails 8 built-in authentication generator. No public signup; users are created via seed/rake task
- **Search**: `pg_search` gem (tsearch + trigram). Meilisearch is the upgrade path only if Postgres falls short
- **Deploy**: Coolify from git (Dockerfile build) is the primary target. Keep the app portable (12-factor config, Dockerfile, standard Postgres, only contrib extensions `pg_trgm` + `unaccent`) so Railway or Heroku remain possible fallbacks
- **Mobile (future)**: Hotwire Native wrapping this same app. Keep every screen server-rendered and URL-addressable

## Golden rule: nothing is installed locally

Ruby, Node, Postgres etc. are NOT installed on the host. **Every command runs in Docker.** Never suggest `bundle install`, `rails ...`, or `psql` on the host.

```bash
docker compose up                              # dev server on http://localhost:3000
docker compose run --rm web bin/rails c        # console
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bin/rails test     # test suite
docker compose run --rm web bundle add <gem>   # add a gem (then rebuild: docker compose build web)
docker compose run --rm web bin/rails import:notes FILE=path/to/export.txt
docker compose exec db psql -U postgres svapna_development
```

TODO: add a `Makefile` or `bin/d` wrapper so these are shorter (`make console`, `make test`).

### Docker files

| File | Purpose |
|---|---|
| `Dockerfile` | **Production** image. Multi-stage, non-root, precompiled assets. This is what Coolify builds |
| `Dockerfile.dev` | **Development** image. Bind-mounts source, includes dev/test gems |
| `docker-compose.yml` | Dev: `web` + `db` (Postgres), named volumes for gems and pgdata |
| `docker-compose.prod.yml` | Optional: prod-like local run / Coolify compose deploy |

Config comes from environment variables (`DATABASE_URL`, `SECRET_KEY_BASE`/`RAILS_MASTER_KEY`, `APP_HOST`). Never commit secrets. `.env.example` documents them.

## Domain model (planned)

- `Entry`: `body` (text), `written_on` (date from the import), `position` (order within its source note), `important` (bool), `source` (string; the Apple Notes note title, e.g. "Sueños p.14"), `language` (Postgres text-search config name, e.g. `spanish`), `search_vector` (tsvector, generated), timestamps
  - Keep **both** `written_on` and `created_at`. On import set both from the entry's date (`created_at` at midday UTC to avoid timezone off-by-one)
  - Entries have **no title**. An entry is identified by its date (`written_on`), shown as the heading in lists and on the entry page. Several entries may share a date; `position` keeps their order stable. Do not add a `title` column
- `Category`: one per entry (`Entry belongs_to :category, optional`)
- `Tag` + `Tagging`: many-to-many. `important` is auto-applied on import but also a normal tag
- `User`: single/few accounts, has_secure_password

## Notes import

Input is a plain-text export from Apple Notes. Format:

```
<note title>
———
YYYY/MM/DD

<body, may contain blank lines>

———
YYYY/MM/DD

<body>
```

Parser rules (implement as `app/services/notes_importer.rb`, with tests using the sample above as a fixture):

1. First line is the **note title**, which is only a grouping label (the user creates many notes like "Sueños p.1" … "Sueños p.14"). It is stored as `source` on every entry, NOT as the entry title. Split the rest on the `———` divider (three em dashes, on its own line). Also tolerate `---`.
2. In each chunk, the first non-blank line is the date (`YYYY/MM/DD`) → `written_on`. Everything after is the body, preserving paragraph breaks.
3. If the body contains **important** or **importante** (case-insensitive, whole word, accent-insensitive; `( important ? )` matches), tag it `important`. Keep the keyword list in config so Portuguese/French/Italian (`importante`, `important`, `importante`) can be extended.
4. Import must be **idempotent**: re-importing must not create duplicates (dedupe on `source` + `written_on` + body digest). Multiple entries on the same date are allowed.
5. Malformed chunks (no parsable date) are skipped and reported, never silently dropped and never abort the whole import.
6. Detect each entry's `language` on import (en/es/pt/fr/it) and let the user override it afterwards.
7. Provide a rake task (`import:notes`) and a UI that accepts **multiple files or pasted text at once**.
8. UI import flow is **preview first** (dry run): show counts (new / duplicate / skipped), a sample, and detected languages, then confirm to commit. Commit runs in a single transaction per note.

Volume: the user has ~14 notes (Sueños p.1–p.14) with many entries each. That is small data for Postgres (thousands of rows), so no batching infrastructure or background queue is needed beyond a transaction per file.

`OPEN`: how do notes get out of Apple Notes? Baseline is copy/paste into the import form (works today). Possible later: a one-off `osascript` export script.

## Search

- Postgres FTS with a generated `tsvector`: body weight A, tag and category names weight B, `source` (note name) weight C
- Languages: **Spanish and English** now; **Portuguese (BR), French, Italian** later. All ship as built-in Postgres text-search configs (`spanish`, `english`, `portuguese`, `french`, `italian`), so adding one is a config change, not new infrastructure
- Each entry's `search_vector` uses the config named in its `language` column, plus `unaccent`. Queries search across languages (query is parsed with each supported config, or with `simple`), so a Spanish search still finds English entries and vice versa
- Support: body-only / all-fields scope, phrase search, prefix search, typo tolerance (trigram), filters (tag, category, source note, date or date range, important), highlighted snippets (`ts_headline`), ranking
- GIN index on the tsvector and a trigram index on body (for typo tolerance). Check `EXPLAIN` before adding more

## Text analytics

Service objects in `app/services/analytics/`:

- `WordFrequency.call(entries:, stopwords: :default, limit: nil)` → `{ "word" => count }` for any set of entries (1, 5, or all)
- Tokenise with Unicode-aware regex, downcase, strip accents only for grouping (display the original form)
- Stopword lists live in `config/stopwords/{en,es,pt,fr,it}.txt`, are editable, and are selectable per call. Default: apply each entry's own language list, or the union of all lists for mixed selections
- Prefer SQL (`regexp_split_to_table` / `ts_stat`) for whole-corpus queries; plain Ruby is fine for small selections
- Must be exposed both in the UI (an "Insights" page) and callable from the Rails console

## Design system

Simple, clean, reading-first. Mobile-first, then scale up.

- Tailwind v4 with design tokens defined once in `app/assets/tailwind/theme.css` (`@theme`): colours, type scale, spacing, radius. Never hard-code hex values in views
- Fonts: serif for reading body (e.g. Newsreader or Source Serif), sans for UI (e.g. Inter). Self-host with `font-display: swap`. `OPEN`: final picks
- Light and dark mode via `prefers-color-scheme`
- Components as ViewComponent or partials: button, input, tag chip, entry card, search bar
- Comfortable measure (~65ch), generous line-height, 44px minimum touch targets, no hover-only interactions (native app is coming)

## Conventions

- Keep it boring: standard Rails conventions, fat models where sensible, service objects only for the importer and analytics
- Server-rendered HTML first. Add Stimulus only where needed. No SPA, no JSON API until the native app needs one
- Every feature ships with tests (Minitest, fixtures). Importer and analytics need thorough unit tests
- All routes except login require authentication (`before_action` in `ApplicationController`)
- Migrations are reversible. Use `strong_migrations` so we do not lock tables
- Run `docker compose run --rm web bin/rubocop` and `bin/rails test` before committing

## Git

- Default branch: `main`. Feature work on branches (`epic/*`, `feat/*`)
- Small, focused commits. Do not commit unless asked

## Roadmap

1. Scaffold Rails 8 in Docker (dev + prod images), Postgres, Tailwind, auth
2. `Entry` model, list/show/edit, design system baseline
3. Notes importer + upload UI
4. Search
5. Tags/categories
6. Word-frequency insights
7. Deploy on Coolify
8. Hotwire Native shell (iOS/Android)
