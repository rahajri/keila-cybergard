# ============================================================================
# Keila Cybergard — dérivé de ops/Dockerfile de pentacent/keila v0.30.3
# ============================================================================
# Différences avec l'upstream (volontairement minimales) :
#   - image Elixir/OTP épinglée par digest (ELIXIR_IMAGE) pour le build ET le
#     runtime → build reproductible, OTP identique entre les deux étapes
#   - labels OCI (source, version, commit upstream)
# Le contexte de build est le source Keila récupéré par fetch-source.sh puis
# brandé par apply-branding.sh (voir build.sh). Aucun autre changement de code.
# ============================================================================
ARG ELIXIR_IMAGE

FROM ${ELIXIR_IMAGE} AS build

ARG WITH_EXTRA=0
ARG KEILA_CLOUD=0
ARG KEILA_CLOUD_LICENSE

ENV MIX_ENV=prod
# Robustesse réseau du téléchargement Hex (n'affecte pas l'image produite)
ENV HEX_HTTP_TIMEOUT=120 HEX_HTTP_CONCURRENCY=4

RUN apk add --no-cache git npm build-base openssl cmake

COPY mix.exs mix.lock ./
COPY config .
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
RUN npm ci --prefix ./assets

COPY . .
RUN mix deps.clean mime --build && \
    mix assets.deploy && \
    mix release

FROM ${ELIXIR_IMAGE}

ARG ELIXIR_IMAGE
ARG KEILA_VERSION
ARG KEILA_COMMIT
ARG CYBERGARD_REVISION
LABEL org.opencontainers.image.title="keila-cybergard" \
      org.opencontainers.image.description="Keila (pentacent/keila) avec branding Cybergard AI" \
      org.opencontainers.image.licenses="AGPL-3.0-only" \
      org.opencontainers.image.version="${KEILA_VERSION}-cybergard.${CYBERGARD_REVISION}" \
      org.opencontainers.image.base.name="${ELIXIR_IMAGE}" \
      fr.cybergard.keila.upstream.repo="https://github.com/pentacent/keila" \
      fr.cybergard.keila.upstream.commit="${KEILA_COMMIT}"

ENV HOME=/opt/app
WORKDIR ${HOME}
COPY --from=build _build/prod/rel/keila ${HOME}
RUN apk add --no-cache openssl
RUN mkdir -p ${HOME} && \
    adduser -s /bin/sh -u 1001 -G root -h ${HOME} -S -D default && \
    chown -R 1001:0 ${HOME}
ENTRYPOINT ["/opt/app/bin/keila"]
CMD ["start"]

ARG PORT=4000
ENV PORT=${PORT}
EXPOSE ${PORT}/tcp
