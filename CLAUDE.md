# Svapna

Private, password-protected journal. Entries are imported from Apple Notes, then searched, tagged, and analysed (word frequency etc.). Long-term the app should replace Apple Notes as the place entries get written.

**Status:** M2 complete — scaffolding, Docker, authentication, and the `Entry` model with its Postgres search layer. See the milestone table at the bottom.

## Stack

- **Rails 8.1.3.1** on **Ruby 3.4.10**, Hotwire (Turbo + Stimulus), Propshaft, importmap (no Node)
  - Ruby 4.x is current but its ecosystem gaps (`OpenStruct`, `cgi/session`) make it a separate upgrade track. Bump `ARG RUBY_VERSION` in both Dockerfiles together
- **PostgreSQL 17** — primary store *and* search engine (FTS + trigram + unaccent)
  - Pinned to 17 because Debian trixie's `postgresql-client` is 17. `structure.sql` is pg_dump output loaded via `psql`, so client and server majors must match. Changing one means changing all three: both Dockerfiles and `docker-compose*.yml`
- **Tailwind CSS v4** via `tailwindcss-rails` 4.6. CSS-first `@theme`, no `tailwind.config.js`, no Node, no PostCSS
- **Auth**: Rails 8 built-in authentication generator (`User` + `Session`, bcrypt). No public signup — create accounts with `bin/d r user:create EMAIL=... PASSWORD=...` (`user:list` to see them)
- **Search**: hand-written query object. **Not `pg_search`** — it supports neither multiple dictionaries in one query nor per-row language configs
- **`schema_format = :sql`** — `db/structure.sql` is the schema of record. `schema.rb` cannot represent text search configurations, custom functions or generated columns. Never reintroduce it
- **Deploy**: Coolify (Git + Dockerfile build pack). Not set up yet. Stay portable: 12-factor config, only trusted extensions, so Railway/Heroku remain fallbacks
- **Mobile (future)**: Hotwire Native over this same app. Keep every screen server-rendered and URL-addressable

## Golden rule: nothing is installed locally

Ruby, Node and Postgres are NOT on the host. **Every command goes through `bin/d`.** Never suggest `bundle install`, `rails ...` or `psql` directly.

```bash
bin/d up                 # start the stack -> http://localhost:3000
bin/d upd                # ... detached
bin/d down               # stop            (bin/d nuke also drops the volumes)
bin/d c                  # rails console
bin/d r db:migrate       # any bin/rails command
bin/d g model Entry      # rails generate
bin/d t                  # test suite
bin/d ci                 # full pipeline: setup, rubocop, audits, tests, seeds
bin/d add <gem>          # bundle add + restart (no rebuild needed)
bin/d psql               # psql into the db container
bin/d prod up --build    # run the real production image at :8080
bin/d                    # full command list
```

`bin/d build` is only needed when `Dockerfile.dev` changes, i.e. for a new OS package. Gems live in a named volume and are installed at container start, so `bin/d add` + restart is enough.

### Docker files

| File | Purpose |
|---|---|
| `Dockerfile` | **Production.** Rails-generated, lightly adapted. What Coolify builds |
| `Dockerfile.dev` | **Development.** No app code, no gems — source is bind-mounted, gems are in a volume |
| `docker-compose.yml` | Dev: `web` + `db`, healthcheck-gated |
| `docker-compose.prod.yml` | Runs the production image locally for verification |
| `bin/d` | Command wrapper |
| `bin/docker-dev-entrypoint` | Dev: `bundle check \|\| bundle install`, clears a stale server pid |
| `bin/docker-entrypoint` | Prod: runs `db:prepare` when the command is the server |

Config is environment variables only (`DATABASE_URL` in prod, `SECRET_KEY_BASE`, `APP_HOST`). Never commit secrets.

### Things that will bite

- **No `DATABASE_URL` in development.** It overrides config for whichever environment loads, so `RAILS_ENV=test` would truncate the development database. Dev uses discrete `DB_HOST`/`DB_USER`/`DB_PASSWORD`
- **Keep `Gemfile.lock` multi-platform.** `bundle lock --add-platform x86_64-linux aarch64-linux` after any regeneration. We develop on arm64; Coolify builds amd64 with a frozen lockfile and will fail the build otherwise
- **Never add the `listen` gem** — it switches Rails to the evented file watcher, which does not work over a bind mount
- **If CSS changes stop appearing**, inotify isn't crossing the bind mount: use `css: bin/rails tailwindcss:watch[poll]` in `Procfile.dev`
- **Destroy the bundle volume after a Ruby bump** (`bin/d nuke`) or native extensions segfault against the old ABI
- **`json` is pinned to `~> 2.7`.** json 3.0 made `JSON.parse` take a single positional argument, but ActiveSupport 8.1.3.1 still passes the options Hash positionally. Under json 3.x every signed cookie read raises `ArgumentError`, so *authentication breaks entirely* and the failure surfaces deep in Rails internals, not in your code. Do not remove the pin without running `bin/d ci`
- Production `CMD` is `["./bin/thrust", "./bin/rails", "server"]`. `bin/docker-entrypoint` matches the *last two* args to decide whether to migrate — do not "simplify" that to `$1`/`$2` or migrations stop running silently

## Domain model

- `Entry`: `body`, `written_on` (date from the import), `position`, `language`, `status` (`draft`/`published`), `source` (Apple Notes note title; NULL = written here), `body_digest`, `import_id`, `search_vector`, `word_vector`, timestamps
  - **No title.** An entry is identified by `written_on`. Several entries may share a date; `position` orders them. Do not add a `title` column
  - Keep both `written_on` and `created_at`; import sets both
  - Dedupe index on `(written_on, body_digest)` is **partial: `WHERE import_id IS NOT NULL`**. Idempotency is for imports; without the partial clause two new empty drafts on the same day collide
  - `body_digest` is set in a **`before_save`**, not `before_validation`, so a bulk import writing with `validate: false` still satisfies the NOT NULL constraint
  - `import_id` exists but has no foreign key and no association yet — M3 adds the `imports` table, the FK, and `belongs_to :import`
- `Tag` + `Tagging`: many-to-many. **No `Category` model** — tags do that job. `important` is an ordinary tag
- `Import`: one row per import run, so entries can be traced and undone
- `User` + `Session`: from the Rails generator

**Two tsvectors, deliberately.** `search_vector` is stemmed and accent-folded for *matching*; `word_vector` is plain `simple` for *counting*, so word frequency reports `sueños`, not `suenos` or the stem `sueñ`.

## Notes import

Plain-text export from Apple Notes:

```
<note title>
———
YYYY/MM/DD

<body>
———
YYYY/MM/DD

<body>
```

Parser rules (`app/services/notes_import/parser.rb`, pure and unit-tested; `committer.rb` does the writing):

1. Normalise line endings and non-breaking spaces first.
2. Divider = a line of 3+ dashes of any kind (`———`, `---`, `–––`).
3. Text before the first divider is the **note title** → stored as `source` on every entry. It is a grouping label ("Sueños p.14"), never an entry title.
4. First non-blank line of each chunk is the date → `written_on`; the rest is the body, paragraph breaks preserved.
5. Tag `important` if the unaccented body matches `important|importante|importantes`. Keyword list in `config/import_keywords.yml`.
6. Detect `language` by stopword ratio (no gem). User-overridable.
7. Idempotent: `body_digest` + the partial unique index.
8. Dateless chunks are recorded in `imports.errors`, never silently dropped, never aborting the run.

**Import + undo, not preview.** Each run creates an `Import`; the result page shows counts and parsed entries and offers Undo, which destroys that batch's entries. Simpler than a stateless preview round-trip and leaves a permanent record of provenance.

Entry points: `bin/d r import:notes FILE=...` and an authenticated UI taking pasted text or multiple files. Import one note first and read the result before doing the rest.

## Search

- `search_vector` is a STORED generated column: `setweight(body,'A') || setweight(source,'C')`, built with the entry's own language config. Generated columns can only reference their own row, so **tags and category are filters, not part of the vector**
- Custom text search configs prepend the `unaccent` *dictionary* to the stemmer (`svapna_es`, `svapna_en`) — this is what makes "sueno" find "sueños". The bare `unaccent()` function is STABLE and unusable in an index; the dictionary route is how that's avoided
- `svapna_regconfig(text)` is a declared-IMMUTABLE CASE over **schema-qualified literal** config names, falling back to `simple`. A plain `language::regconfig` cast is STABLE and rejected in a generated column
- Query with `websearch_to_tsquery` under each active config, OR'd (`||`) — recall beats precision here. Free Google-style syntax, and it never raises on malformed input
- `ts_headline` **only on the current page** — it re-parses the original document and is slow
- Default scope excludes drafts
- Adding a language = one migration: a new config plus a `WHEN` branch in `svapna_regconfig`, and `Entry::LANGUAGES`. Postgres ships stemmers for es/en/pt/fr/it
- **Stopwords vanish inside phrases.** `"con montañas"` reduces to `montañas` under the Spanish configuration, so a phrase search can match more than it looks like it should. Covered by a test so the behaviour is not mistaken for a bug
- **Altering a text search config does not recompute existing generated columns.** Any such migration must drop and re-add the column expression and `REINDEX`

## Text analytics

`Analytics::WordFrequency.call(scope:, stopwords:, limit:)` → one code path via `ts_stat` over `word_vector`, so "these 5 entries" and "all entries" always agree.

- Returns `ndoc` (entries containing) and `nentry` (occurrences)
- `ts_stat` takes its inner query as a **string literal** — build it with `connection.quote(relation.select(:word_vector).to_sql)`, never string interpolation
- Stopword lists in `config/stopwords/{en,es,pt,fr,it}.txt`, editable, applied after aggregation
- Full-corpus scan: cache the all-entries result, bust on import
- Must work from the console as well as the UI

## Design system

Reading-first, mobile-first. Tokens once, never hard-coded hex in views.

- **Newsreader** for entry text, **Inter** for UI. Self-hosted (no Google CDN), subset latin + latin-ext for Spanish accents, `font-display: swap`
- Tokens in `app/assets/tailwind/application.css` under `@theme`
- Light + dark via `prefers-color-scheme`
- ~65ch measure, generous line-height, 44px touch targets, no hover-only interactions (Hotwire Native is coming)
- Partials first; ViewComponent only when they carry real logic

## Conventions

- Keep it boring: standard Rails, service objects only for the importer and analytics, a query object for search
- Server-rendered HTML first. Stimulus where needed. No SPA, no JSON API until the native app needs one
- Minitest + fixtures. The parser and the search/analytics SQL carry the risk and get thorough tests — test search against real Postgres, never stubbed
- All routes except login require authentication
- Reversible migrations. Review `db/structure.sql` diffs rather than skimming them — it is the schema of record
- `bin/d ci` before committing (it runs RuboCop, the security audits, tests and seeds)

## Git

- Default branch `main`; work on `epic/*` / `feat/*`. Currently on `feat/m1`
- Small, focused commits. Do not commit unless asked

## Milestones

Build **one milestone at a time**, then stop for review.

| # | Milestone | State |
|---|---|---|
| M0 | Bootstrap: Rails 8.1 in Docker, dev + prod images, `bin/d`, `structure.sql` | **done** |
| M1 | Auth: `generate authentication`, lock down, user rake task | **done** |
| M2 | `Entry` model + the Postgres search migration + plain CRUD | **done** |
| M3 | Importer: parser, committer, `Import` + undo, rake task + UI | next |
| M4 | Design system + reading UI | |
| M5 | Search: query object, filters, `ts_headline`, results UI | |
| M6 | Tags | |
| M7 | Insights: word frequency, stopwords | |
| M8 | Composer: authoring, autosave, drafts | |
| M9 | Deploy to Coolify (can be pulled forward any time) | |
| M10 | Hotwire Native shell | |
