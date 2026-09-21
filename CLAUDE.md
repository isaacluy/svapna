# Svapna

Private, password-protected journal. Entries are imported from Apple Notes, then searched, tagged, and analysed (word frequency etc.). Long-term the app should replace Apple Notes as the place entries get written.

**Status:** M8 complete — everything through the composer. Svapna can now be written in, not just imported into. See the milestone table at the bottom.

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
bin/d sys                # system tests (starts the browser container)
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
- `Tag` + `Tagging`: many-to-many, names stored downcased so a plain unique index suffices (no `citext`). **No `Category` model** — tags do that job. `important` is an ordinary tag
  - Edited through `Entry#tag_list`, a comma-separated virtual attribute applied in an **`after_save`** (a new entry needs an id before taggings can attach). Assigning it replaces the whole set; leaving it out of an update touches nothing
  - **A tag outlives its last entry on purpose** — undoing an import keeps the vocabulary for reuse. Anything user-facing uses `Tag.in_use`, and `bin/d r tags:prune` clears the rest
- `Import`: one row per import run, so entries can be traced and undone. The skipped-section column is **`parse_errors`, not `errors`** — `errors` collides with `ActiveModel::Errors` and raises `DangerousAttributeError`. Undo is `dependent: :destroy`, which also clears taggings; the tag vocabulary survives
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

Entry points, both going through `NotesImport::Runner`:

```bash
bin/d r import:notes FILE='tmp/notes/*.txt'   # quote it -- Ruby globs, not the shell
bin/d r import:list
bin/d r import:undo IMPORT=3
```

…and the UI at `/imports/new`, taking pasted text or several files at once. Each file becomes its own `Import` so one bad file can be undone alone. Put files under `tmp/notes/` (gitignored, and visible inside the container). Import one note first and read the result before doing the rest.

`NotesImport::Text.normalize` runs first on everything: Apple Notes emits CRLF and non-breaking spaces, and an NBSP beside a divider stops it matching, silently merging two entries into one.

## Search

`EntrySearch` (`app/queries/entry_search.rb`) is the one place search happens. **Browse and search are the same page**: `/entries` with an empty query simply lists everything, so there is one results UI and one set of filter state. The header search box posts there.

- `search_vector` is a STORED generated column: `setweight(body,'A') || setweight(source,'C')`, built with the entry's own language config. Generated columns can only reference their own row, so **tags are filters, not part of the vector**
- Custom text search configs prepend the `unaccent` *dictionary* to the stemmer (`svapna_es`, `svapna_en`) — that is what makes "sueno" find "sueños". The bare `unaccent()` function is STABLE and unusable in an index; the dictionary route is how that is avoided
- `svapna_regconfig(text)` is a declared-IMMUTABLE CASE over **schema-qualified literal** config names, falling back to `simple`. A plain `language::regconfig` cast is STABLE and rejected in a generated column
- `Entry::SEARCH_CONFIGS` maps language => config and is the single source of truth. Adding a language = a migration (new config plus a `WHEN` branch in `svapna_regconfig`) and one line here
- The query is parsed under **every** config and OR'd (`||`), so a Spanish query still finds an English entry. Recall beats precision; ranking sorts it out
- `websearch_to_tsquery` gives `"quoted phrases"`, `or`, and `-exclusion` for free and **never raises on malformed input**
- Filters compose onto the relation: tag, source note, date range (either end open), and status. **Drafts are excluded by default** — the list says how many are hidden and links to show them, so a draft never seems to have vanished
- Ranking is `ts_rank_cd` then `written_on DESC`
- Pagination is hand-rolled offset/limit, 20 per page. `page` is **clamped** to the real page count

### Two things not to undo

**All SQL templates are load-time constants** (`MATCH_SQL`, `RANK_SQL`, `HEADLINE_SQL`), built once from `SEARCH_CONFIGS`, with every piece of user input passed as a `?` bind. Interpolating a sanitised fragment at the call site also works, but Brakeman flags it as SQL injection and it is a bad pattern to keep around.

**Highlighting escapes before it marks.** `ts_headline` runs **only over the current page** — the Postgres docs warn it re-parses the whole document and is slow — and is asked for private-use codepoint delimiters (`HIGHLIGHT_OPEN`/`CLOSE`), not `<mark>`. `SearchHelper#highlighted` HTML-escapes the snippet and *then* converts those markers to tags. Asking Postgres for literal `<mark>` would force sanitising instead, and Rails' `sanitize` strips a disallowed tag while keeping its text — so `<script>alert(1)</script>` in an entry would render as a bare `alert(1)`. (Postgres' parser happens to drop HTML tags from headlines anyway, so a full-stack test cannot prove the escaping; `SearchHelperTest` does it directly.)

## Suggestions ("did you mean?")

`Vocabulary.similar_to` trigram-matches a misspelled query against the words actually written, drawn from `ts_stat` over `word_vector` — unstemmed and accented, so a suggestion reads as `sueños`, not `sueñ` or `suenos`.

- **Computed on demand, not stored.** It is only reached when a search returns zero results, which is rare. A lexicon table would add staleness and a refresh step to forget; materialise it if the corpus ever grows enough to drag
- Only offered for a **single-word query**. Correcting one word of a phrase means guessing which word was wrong, and a wrong guess is worse than none
- Accent and stemming differences never get this far — search already handles them — so anything reaching here is a real misspelling
- Threshold is 0.35, a little above Postgres' 0.3 default, which keeps the suggestions from being noise

## Text analytics

`Analytics::WordFrequency` (`app/services/analytics/`) answers "how often does each word appear" over any set of entries. It is a plain service object, so it works from the console (`bin/d c`) exactly as it does from the UI.

```ruby
Analytics::WordFrequency.call                                # everything published
Analytics::WordFrequency.call(scope: Entry.where(id: ids))   # just these
Analytics::WordFrequency.call(stopwords: :none, limit: 200)
```

**One code path for both questions.** "These five entries" and "all of them" differ only by a `WHERE` clause, so the two can never disagree. Returns `occurrences` (ts_stat's `nentry`) and `entries` (`ndoc`).

- Runs over **`word_vector`**, not `search_vector` — unstemmed and accented, so results read as `montañas`, not `montan` or `montanas`
- `ts_stat` takes its inner query as a **string literal**: built with `connection.quote(scope.select(:word_vector).to_sql)`, never interpolation. User input only reaches it as a bound value inside the relation
- **Stopwords are applied in SQL, before `LIMIT`** — otherwise the top list would be padded with them. `:auto` uses the lists for the languages actually present; `:none` keeps everything; an explicit array overrides
- **Stopword lists are editable files**, `config/stopwords/<language>.txt` (currently `es` and `en`), read by `Analytics::Stopwords`. The import language detector reads the same files, so editing one affects both. Adding a language means adding a file
- Matching is accent-folded (`lower(unaccent(word))`) because the lists hold `mas` while the text says `más`. Inlined rather than wrapped in a function: nothing is indexed on it
- **An empty stopword list skips the clause entirely.** An empty Ruby array renders as `NULL`, and `= ANY (ARRAY[NULL])` is `NULL`, which would filter out every row rather than none
- A full-corpus scan, so results are **memoised against the data they came from**: the cache key includes `Entry.maximum(:updated_at)` and `Entry.count`, so any write changes the key. No explicit invalidation to forget

The UI is `/insights`, which **reuses `EntrySearch`** (via `scope_for_analytics`) — the same filters as the entry list, so there is no second filtering language. The entry list links through carrying its current filters, which is how "word counts for these five entries" is actually reached.

### The bars

Ranked magnitude, **one series, so one hue** from `--chart-fill`. Never a value-ramp colouring each bar darker-where-bigger: that double-encodes length as hue and spends the only free channel on what the bar already shows. No legend (one series). Values wear ink tokens, never the data colour.

Both fill values (`#5b57a8` light, `#8083da` dark) were checked with the dataviz validator for chroma, lightness band and ≥3:1 contrast against their own surface — the accent itself fails the chroma floor and reads too gray for a data mark. Marks are thin, with a rounded data-end, a 2px surface gap between neighbours, and a `forced-colors` fallback. The table is semantic and readable with the bars ignored.

## Design system

Reading-first, mobile-first. Everything lives in `app/assets/tailwind/application.css`; **never hard-code a colour in a view.**

- **Fonts are self-hosted variable woff2** in `app/assets/fonts/` (fontsource 5.3.0): Newsreader for entry text, Inter for UI. No Google CDN — privacy, and it works offline in the container. One file per family covers every weight, and `unicode-range` means the latin-ext files are only fetched if a character needs them. Propshaft fingerprints them and production serves them `immutable` for a year
- **Colours are plain custom properties on `:root`**, swapped in a `prefers-color-scheme: dark` block, then exposed to Tailwind through `@theme inline` (which emits `var()` rather than baking values in). Add a colour in one place: `:root`, the dark block, and the `@theme inline` map
- **Semantic names, not palette names**: `paper`, `surface`, `surface-sunk`, `ink`, `ink-muted`, `ink-faint`, `rule`, `accent`, `marker` (the `important` tag), `danger`
- **Component classes** in `@layer components` rather than repeating long utility chains: `.prose-entry`, `.btn`/`.btn-primary`/`.btn-quiet`/`.btn-danger`, `.field`, `.label`, `.tag`/`.tag-marker`, `.card`, `.link`
- `.prose-entry` is the reading surface: Newsreader at 1.1875rem/1.75, capped by `max-w-measure` (~34rem, about 65 characters)
- `.btn` and `.field` are `min-height: 2.75rem` — 44px touch targets, because Hotwire Native is coming. Nothing is hover-only
- Partials first. `layouts/_header`, `layouts/_flash`, `layouts/_auth_panel`, `entries/_entry`. No ViewComponent until one carries real logic
- Helpers: `nav_link_to` (marks the current section, sets `aria-current`), `entry_date`, `tag_pill`

**Flash messages render only in `layouts/_flash`.** Views must not render their own — that was a real bug (each message appeared twice on the auth pages). `test/controllers/flash_rendering_test.rb` counts `[role=status]` nodes so a reintroduction fails; a `assert_select "div", /text/` assertion would not catch it.

## Composer

`/entries/new` and `/entries/:id/edit` are the writing surface. **It is a plain form that works without JavaScript** — a real submit button, real validations — and autosave is layered on top. If the fetch fails the status line says so and the button still works.

- `autosave_controller.js` debounces on `input`/`change` (2s) and flushes on `visibilitychange`, so a pending save is not lost on navigation
- **Nothing is autosaved while the body is blank.** The body is required, so it would only ever produce a validation error — and it stops empty drafts accumulating
- The first save POSTs; the response carries `update_url`, `edit_url` and `publish_url`, after which the controller switches to PATCH, rewrites the publish form's action and `history.replaceState`s to the edit URL. Otherwise a second keystroke would create a second entry
- **The controller sits on a wrapper `div`, not the form.** Publish must be its own form (different action and verb) so it cannot nest inside the entry form, and Stimulus only sees targets inside its own element. With the controller on the form, autosave looks fine while Publish silently never activates — which is exactly what happened, and what `composer_test.rb` now guards
- Saving a draft returns to the composer; saving a published entry goes to the reading view. Publishing is its own request, so it can never be mistaken for a save
- Drafts are reachable from `/entries/drafts`, the home page's "Continue writing", and the hidden-drafts link on the entry list

### System tests

`bin/d sys` starts a `selenium` compose service (profile `test`, so `bin/d t` never touches it) and runs `test/system`. Nothing is installed on the host and nothing extra goes into the app image.

- They run **serially** (`parallelize(workers: 1)`): the browser reaches the app on a fixed port, and parallel workers would fight over it — the browser then talks to another worker's database and fails in ways that look like the feature is broken
- `Capybara.app_host` is this container's **own private IP**, not the service name: a `docker compose run` container gets a generated name that `selenium` cannot resolve
- **`click_on` does not wait for the navigation it triggers.** Follow it with an assertion on the resulting page (`assert_text "Sign out"`) before doing anything else, or the next step races the in-flight request. Two of the three failures while writing these were this, not the app

## Conventions

- Keep it boring: standard Rails, service objects only for the importer and analytics, a query object for search
- Server-rendered HTML first. Stimulus where needed. No SPA, no JSON API until the native app needs one
- Minitest + fixtures. The parser and the search/analytics SQL carry the risk and get thorough tests — test search against real Postgres, never stubbed
- All routes except login require authentication
- Reversible migrations. Review `db/structure.sql` diffs rather than skimming them — it is the schema of record
- `bin/d ci` before committing (it runs RuboCop, the security audits, tests and seeds)

## Git

- Default branch `main`; work on `epic/*` / `feat/*`. Currently on `feat/m8`
- Small, focused commits. Do not commit unless asked

## Milestones

Build **one milestone at a time**, then stop for review.

| # | Milestone | State |
|---|---|---|
| M0 | Bootstrap: Rails 8.1 in Docker, dev + prod images, `bin/d`, `structure.sql` | **done** |
| M1 | Auth: `generate authentication`, lock down, user rake task | **done** |
| M2 | `Entry` model + the Postgres search migration + plain CRUD | **done** |
| M3 | Importer: parser, committer, `Import` + undo, rake task + UI | **done** |
| M4 | Design system + reading UI | **done** |
| M5 | Search: query object, filters, `ts_headline`, results UI | **done** |
| M6 | Tags: browsing, filtering by tag, "did you mean?" | **done** |
| M7 | Insights: word frequency, stopwords | **done** |
| M8 | Composer: authoring, autosave, drafts | **done** |
| M9 | Deploy to Coolify (can be pulled forward any time) | next |
| M10 | Hotwire Native shell | |
