FROM ghcr.io/jdx/mise:2026.10.4

WORKDIR /app

COPY mise.toml Gemfile Gemfile.lock ./
RUN mise trust && mise install && mise run deps

COPY . .

ENTRYPOINT ["mise", "exec", "--", "bundle", "exec", "ruby", "./bin/cli"]
