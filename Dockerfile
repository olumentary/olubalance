# syntax=docker/dockerfile:1
# Self-hosting image for olubalance (Rails 8.1, esbuild + Dart Sass asset pipeline).
# Multi-stage: build compiles gems + assets, runtime carries only what's needed to boot.
# Build:  docker build -t olubalance .
# Pinned Ruby matches Gemfile / .ruby-version (3.4.8).

ARG RUBY_VERSION=3.4.8
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

# Rails app lives here
WORKDIR /rails

# Production defaults baked into the image (overridable at runtime via compose env).
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# ---------------------------------------------------------------------------
# Build stage: compile gems with native extensions and build JS/CSS + assets
# ---------------------------------------------------------------------------
FROM base AS build

# Packages needed to build gems (pg, image_processing) and run the asset toolchain.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git libpq-dev libyaml-dev pkg-config curl && \
    rm -rf /var/lib/apt/lists/*

# Node 24 + Yarn 1.22 (esbuild/sass build tooling) — copied from the official image.
COPY --from=docker.io/library/node:24-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=docker.io/library/node:24-slim /usr/local/include/node /usr/local/include/node
COPY --from=docker.io/library/node:24-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -sf /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack && \
    corepack enable && corepack prepare yarn@1.22.22 --activate

# Install gems (matching the lockfile's bundler version) with a layer cache.
RUN gem install bundler:4.0.3
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install JS deps (yarn only — never npm; see CLAUDE.md).
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code and build assets.
COPY . .

# Precompile bootsnap for the app code.
RUN bundle exec bootsnap precompile app/ lib/

# Build JS (esbuild) + CSS (Dart Sass), then precompile Rails assets.
# Booting the production env for precompile requires SECRET_KEY_BASE and the
# ActiveRecord encryption keys to be present. Assets don't read encrypted data,
# so throwaway dummy values are fine here — real keys are supplied at runtime.
RUN yarn build && yarn build:css && \
    SECRET_KEY_BASE_DUMMY=1 \
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="dummy_build_primary_key_not_used_at_runtime______" \
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="dummy_build_deterministic_key_not_used_at_runtime" \
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="dummy_build_salt_not_used_at_runtime______________" \
    ./bin/rails assets:precompile

# Drop node_modules from the final copy — assets are already compiled into builds/.
RUN rm -rf node_modules

# ---------------------------------------------------------------------------
# Runtime stage: minimal image to run the app (web + worker share this)
# ---------------------------------------------------------------------------
FROM base

# Runtime libs only: pg client, ImageMagick (image_processing/mini_magick), curl (healthcheck).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      libpq5 postgresql-client imagemagick libmagickwand-dev libyaml-0-2 curl && \
    rm -rf /var/lib/apt/lists/*

# Copy compiled gems and the built application from the build stage.
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run as a non-root user; own the dirs the app writes to at runtime.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p /rails/storage /rails/tmp /rails/log && \
    chown -R rails:rails /rails/storage /rails/tmp /rails/log
USER 1000:1000

# Entrypoint runs db:prepare + admin bootstrap (guarded by RUN_DB_PREPARE) then execs CMD.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
