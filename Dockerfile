# syntax=docker/dockerfile:1
# Runtime image. Build context is the packaged release directory, which contains
# compiled modules and encrypted assets only. Do not add a stage that copies
# application source. Do not pass secrets with ARG or ENV.

FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Ho_Chi_Minh \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    TIKTOKEN_CACHE_DIR=/app/data/tiktoken \
    PYTHONPATH=/app:/app/doc-ocr

WORKDIR /app

COPY debian.sources /etc/apt/sources.list.d/debian.sources

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-venv \
        python3-pip \
        ca-certificates \
        curl \
        bash \
        procps \
        libstdc++6 \
        libpq5 \
        libpq-dev \
        build-essential \
        poppler-utils \
        tzdata \
        pandoc \
        ffmpeg \
        fonts-dejavu \
        fonts-liberation \
        fonts-noto-core \
        fonts-noto-cjk \
        libglib2.0-0 \
        libgomp1 \
        libgl1 \
        libsm6 \
        libxext6 \
        libxrender1 \
        libreoffice-core \
        libreoffice-writer \
        libreoffice-impress \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo "$TZ" > /etc/timezone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/*

RUN python3 -m venv /opt/venv
ENV PATH=/opt/venv/bin:/app/node_modules/.bin:$PATH
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --timeout=200000 -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

# Mermaid rendering is the only Node dependency used by the Python runtime.
# The Next.js UI is already exported under payload/frontend.
RUN npm install --no-audit --no-fund @mermaid-js/mermaid-cli@11.4.2 \
    && rm -rf \
        /app/node_modules/serialize-javascript \
        /app/node_modules/next/dist/compiled/@vercel/og \
        /app/node_modules/uri-js \
        /app/node_modules/source-map-js \
        /app/node_modules/source-map \
        /app/node_modules/braces \
    && rm -f \
        /usr/local/bin/npm \
        /usr/local/bin/npx \
        /usr/local/bin/corepack \
        /usr/local/bin/yarn \
        /usr/local/bin/yarnpkg \
    && rm -rf \
        /usr/local/lib/node_modules/npm \
        /usr/local/lib/node_modules/corepack \
        /opt/yarn* \
        /usr/local/lib/node_modules/yarn \
        /root/.npm \
        /root/.cache

COPY payload /opt/release-payload
COPY entrypoint.sh /app/entrypoint.sh

RUN mkdir -p /app/doc-ocr /app/data /app/logs \
    && cp -a /opt/release-payload/backend /app/backend \
    && cp -a /opt/release-payload/doc-ocr/doc_ocr /app/doc-ocr/doc_ocr \
    && cp -a /opt/release-payload/cronjob /app/cronjob \
    && cp -a /opt/release-payload/frontend /app/frontend \
    && cp -a /opt/release-payload/font /app/font \
    && cp -a /opt/release-payload/tiktoken /app/data/tiktoken \
    && for runtime in /opt/release-payload/pyarmor_runtime_*; do \
         if [ -d "$runtime" ]; then cp -a "$runtime" /app/; fi; \
       done \
    && rm -rf /opt/release-payload \
    && chmod 755 /app/entrypoint.sh /app/cronjob/run.sh \
    && test -z "$(find /app/backend /app/doc-ocr /app/cronjob -name '*.py' ! -name '__init__.py' ! -path '/app/cronjob/main.py')" \
    && python -c 'from pathlib import Path; roots=(Path("/app/backend"), Path("/app/doc-ocr"), Path("/app/cronjob"));\
bad=[str(p) for root in roots if root.exists() for p in root.rglob("__init__.py") if not p.read_text(encoding="utf-8").lstrip().startswith("# package marker")];\
exit(chr(10).join(bad)) if bad else None' \
    && test -f /app/cronjob/main.py \
    && test -f /app/backend/main*.so \
    && groupadd -g 10001 appuser \
    && useradd -u 10001 -g appuser -m -s /usr/sbin/nologin appuser \
    && chown -R appuser:appuser /app /opt/venv

USER 10001:10001

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/health || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
