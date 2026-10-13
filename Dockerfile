FROM ghcr.io/jdx/mise:2026.10.4-debian

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential libssl-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY mise.toml Gemfile Gemfile.lock ./
RUN mise trust && mise install && mise run deps

COPY . .

ENTRYPOINT ["mise", "exec", "--", "bundle", "exec", "ruby", "./bin/cli"]
