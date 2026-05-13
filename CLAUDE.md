# olubalance — Agent Guide

> This file is the source of truth for AI coding agents working in this repo. `AGENTS.md` is a symlink to this file, so Claude Code, Cursor, Codex, and other agents all read the same content.

## Project overview

olubalance is a personal-finance app — an online checkbook register. Users manually enter transactions to keep a precise running balance per account, attach receipts, set savings goals via "stashes", track recurring bills, and categorize spending. The core domain is **accounts → transactions**, with supporting models for stashes (internal savings), bills (recurring transactions), categories (with fuzzy-match suggestions), and documents (file storage scoped to a user or account).

## Tech stack

- **Ruby** 3.4.8 / **Rails** 8.1
- **PostgreSQL** 17 (uses `db/structure.sql`, not `schema.rb`, because of `pg_trgm` and a SQL view)
- **Frontend**: Bulma 1.0, Stimulus 3, Turbo (Hotwire) 8 — bundled by **esbuild** (JS) and **Dart Sass** (CSS) via `jsbundling-rails` / `cssbundling-rails`
- **Auth**: Devise 5 (database_authenticatable, recoverable, rememberable, trackable, validatable, confirmable)
- **Storage**: ActiveStorage with `local` (dev), `linode` (S3-compatible, prod), or `amazon` (S3) services
- **Decorators**: Draper
- **Pagination**: Pagy
- **Testing**: RSpec 8, FactoryBot, Capybara/Selenium, shoulda-matchers, SimpleCov
- **Lint/Security**: rubocop-rails-omakase, Brakeman
- **Config**: Figaro (`config/application.yml`)
- **AI**: ruby-openai (used for category suggestion / receipt OCR)
- **Deploy**: Dokku via GitHub Actions

There are **no background jobs**. `ApplicationJob` is an empty stub; no Sidekiq/SolidQueue/Resque is configured. If you think a job is genuinely needed, raise it before introducing a queue.

## Repo layout

| Path | Purpose |
| --- | --- |
| `app/models/` | 13 ActiveRecord models. Money columns are `decimal`. |
| `app/controllers/` | Resource controllers; all scoped by `current_user`. |
| `app/views/<resource>/components/` | Resource-specific partials (camelCase filenames, e.g. `_transactionLineDesktop.html.erb`). |
| `app/views/shared/` | Reusable partials (`_navbar`, `_modal`, `_formPage`, `_error_messages`). |
| `app/javascript/controllers/` | 26 Stimulus controllers, registered in `index.js`. |
| `app/assets/stylesheets/` | Sass entry `application.bulma.scss`; theme vars in `_obtheme.scss`. |
| `app/decorators/` | Draper decorators. |
| `spec/` | RSpec specs: `models`, `requests`, `services`, `decorators`, `features`, `helpers`, `mailers`, `tasks`, `factories`, `support`. |
| `db/structure.sql` | Schema source of truth (includes `transaction_balances` view). |
| `db/migrate/` | Migrations. |
| `config/routes.rb` | Route surface — nested resources under `accounts`. |
| `config/storage.yml` | ActiveStorage services. |
| `config/application.yml.sample` | Template for Figaro secrets. |
| `bin/` | Dev scripts (`setup`, `dev`, `ci`, `rubocop`, `brakeman`). |

## Dev commands

```
bin/setup                                   # first-time / idempotent setup (bundle, db:prepare, etc.)
bin/dev                                     # foreman: web on :3000 + JS watch + CSS watch (Procfile.dev)
bundle exec rspec                           # full test suite
bundle exec rspec spec/models/foo_spec.rb   # one file
bundle exec rspec spec/models/foo_spec.rb:42  # one example
bin/rubocop                                 # lint
bin/brakeman                                # security scan
bin/ci                                      # everything CI runs, locally
yarn build                                  # one-shot JS build
yarn build:css                              # one-shot CSS build
bundle exec rails db:reset                  # drop + create + migrate + seed
```

There is **no `bin/rspec`** — use `bundle exec rspec`.

## Workflow rules

- **Run RSpec before declaring work done.** At minimum run the affected spec files; for cross-cutting changes (models, controllers touched by many flows, schema), run the full suite. State explicitly in your summary whether you ran tests and what passed.
- **Never commit without an explicit ask.** Don't run `git commit` / `git push` unless the user has clearly asked for it in this session. A previous "go ahead and commit" doesn't authorize future commits.
- **Prefer Turbo Streams over full page reloads.** PATCH/POST/DELETE actions in this app generally respond with `.turbo_stream.erb` partials that replace specific DOM regions (see `app/views/transactions/mark_pending.turbo_stream.erb`, `mark_reviewed.turbo_stream.erb`, `edit.turbo_stream.erb`, the `categories/create.turbo_stream.erb`, and the `matching_rules/` streams). Follow this pattern when adding new mutating actions — don't `redirect_to` if a stream update is the natural fit.

## Architecture

**Authentication.** Devise. A custom `Users::SessionsController` extends `remember_me` to 2 weeks specifically for iOS Shortcut users (mobile quick-entry). Don't break this when changing session handling.

**Authorization.** *None* — there is no Pundit, CanCanCan, or ActionPolicy. **Every controller MUST scope through the current user**: `current_user.accounts`, `current_user.bills`, `current_user.documents`, etc. This is the IDOR boundary. When writing a new controller, copy the lookup pattern from `app/controllers/transactions_controller.rb` or another existing controller — never `Account.find(params[:id])` directly.

**ActiveStorage.**
- `Transaction has_many_attached :attachments` (multiple receipt files per transaction).
- `Document has_one_attached :attachment` (single file per document).
- Storage service is env-driven: `ACTIVE_STORAGE_SERVICE=local|linode|amazon|amazondev`. Defined in `config/storage.yml`.

**Decorators.** Draper. `ApplicationController` wraps current resources in decorators for mobile views; check the base controller before adding presenter logic in models.

**Mobile.** The app detects mobile devices and routes some flows (`/quick_transactions`, `/quick_receipts`, `/mobile_home`) to mobile-optimized variants. Don't assume desktop-only when changing transaction-creation paths.

## Domain invariants (financial correctness)

These rules protect data integrity. Violating them produces wrong balances, which is the worst kind of bug in this app.

1. **Running balance integrity.** `TransactionBalance` is a read-only PostgreSQL VIEW defined in `db/structure.sql`. It computes `running_balance` as `SUM(amount) OVER (PARTITION BY account_id ORDER BY pending, trx_date, id)`. Never write to it. Any change to `transactions.amount`, `trx_date`, `pending`, the column ordering, or indexes used by that window must preserve the view's semantics. **If you're touching those columns, read the view definition first.**

2. **Counterpart transactions are atomic.** Account-to-account transfers create two `Transaction` rows linked via `counterpart_transaction_id` (see `app/controllers/transfers_controller.rb` and `Transaction#counterpart_transaction`). **Create, update, and destroy both sides together** — wrap multi-row changes in a transaction. Never leave a half-pair.

3. **Money math uses `BigDecimal`, never `Float`.** Money columns (`amount`, `balance`, `current_balance`, `starting_balance`, `goal`, `credit_limit`, `interest_rate`) are PG `decimal`. In Ruby, construct literals with `BigDecimal("12.34")` — not `12.34`, which is a Float and accumulates rounding error. If a method takes user input, coerce explicitly.

4. **Scope everything by `current_user`.** Repeated from above because it's both an architecture rule and a security invariant.

## View / frontend conventions

- **Forms**: `form_with` only (Rails 8 default). No `form_for`.
- **Stimulus**: 26 controllers in `app/javascript/controllers/`, registered via `index.js`. **Search for an existing controller before writing a new one** — there's likely something close (`shared`, `dropdown`, `inline_edit`, `typeahead`, `attachment_upload`, `transaction_list`, `trxform`, etc.). Use the `data-controller` / `data-action` / `data-<controller>-<value>-value` patterns already in use.
- **Partials**: resource-specific partials live under `app/views/<resource>/components/` with camelCase filenames. Truly shared partials live in `app/views/shared/`.
- **CSS**: Bulma 1.x classes only. Theme variables in `app/assets/stylesheets/_obtheme.scss`, overrides in `_bulmaoverrides.scss`. Don't introduce Tailwind, Bootstrap, or other frameworks.
- **Flash**: set the Rails flash; rendering is handled by `shared_controller.js` via `bulma-toast`. Don't roll your own.
- **Charts**: Chart.js via `reports_chart_controller.js`.

## Testing conventions

- **Factories, not fixtures.** Use FactoryBot factories in `spec/factories/`. Existing traits include `:income`, `:annual`, `:bi_weekly`, `:confirmed`, `:unconfirmed`. Add new traits rather than duplicating factories.
- **shoulda-matchers** is loaded — prefer `should validate_presence_of(:x)` over hand-rolled validation specs.
- **Devise integration helpers** are wired up — use `sign_in user` in request specs.
- **Capybara + Selenium** for system/feature specs (`spec/features/`). Browser tests are slow; only add them for genuinely user-facing flows.
- **`spec/support/request_spec_helper.rb`** has helpers for sign-in/sign-out via Warden.
- Transactional fixtures are enabled; don't disable them unless you have a specific reason.

## CI & deploy

CI is GitHub Actions (`.github/workflows/test-and-deploy.yml`): on push to `develop`, it boots Postgres 17, builds assets, runs `bundle exec rails db:reset` in test, then `bundle exec rspec`. On success it pushes to a Dokku remote for staging deploy. The main test command in CI is `bundle exec rspec` — match that locally.

## Configuration

Secrets live in `config/application.yml` (Figaro), gitignored. The template `config/application.yml.sample` covers the keys you need: DB credentials (`OLUBALANCE_DATABASE_USERNAME` / `OLUBALANCE_DATABASE_PASSWORD`), S3/Linode storage keys, mailer creds, reCAPTCHA keys, OpenAI key.

## Working effectively in this repo

- **Broad codebase searches** ("where is X used?", "what controllers touch Y?", "show me all uses of `has_many_attached`") — delegate to the Explore sub-agent rather than running many sequential greps. With 13 models, 18 controllers, and 26 Stimulus controllers, cross-cutting questions are faster in parallel.
- **Schema questions**: read `db/structure.sql`, not `db/schema.rb` (which doesn't exist in this repo). The structure file is the ground truth for PG-specific features like `pg_trgm` and the `transaction_balances` view.
- **Before writing a new resource controller**, re-read `app/controllers/application_controller.rb` and a similar existing controller (e.g. `TransactionsController`, `BillsController`) so the new code matches the `current_user`-scoping, Turbo-stream, and decorator patterns already in use.
- **Before adding a new JS dependency**, check whether an existing Stimulus controller or Bulma component already covers the need.
