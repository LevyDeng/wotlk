# Stage 1: Pre-built image with protoc and protoc-gen-go (no go get/go install needed)
FROM rvolosatovs/protoc AS protoc-tools

# Stage 2: Main build
FROM golang:1.23

# Proxy for Go/git (pass via build: HTTP_PROXY=http://192.168.1.3:7897)
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG http_proxy
ARG https_proxy
ENV HTTP_PROXY=${HTTP_PROXY}
ENV HTTPS_PROXY=${HTTPS_PROXY}
ENV http_proxy=${http_proxy}
ENV https_proxy=${https_proxy}

# Go modules: China mirror (works without proxy). Go also respects HTTP_PROXY if set.
ENV GOPROXY=https://goproxy.cn,direct

# Copy protoc and protoc-gen-go from pre-built image (avoids go get/go install and apt)
# Try common paths (rvolosatovs/protoc may use /usr/bin or /out/usr/bin in final image)
COPY --from=protoc-tools /usr/bin/protoc /usr/local/bin/protoc
COPY --from=protoc-tools /usr/bin/protoc-gen-go /usr/local/bin/protoc-gen-go
# Ensure /usr/local/bin is in PATH so make can find protoc
ENV PATH="/usr/local/bin:${PATH}"

WORKDIR /wotlk
COPY . .
COPY gitconfig /etc/gitconfig

RUN apt-get update && apt-get install -y make protobuf-compiler && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/protoc /usr/local/bin/protoc

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash

ENV NODE_VERSION=19.8.0
ENV NVM_DIR="/root/.nvm"
# Verbose nvm install: capture full output to log and always print it (so we see the real error)
RUN bash -c 'set -x; \
    source "$NVM_DIR/nvm.sh"; \
    echo "NVM_DIR=$NVM_DIR NODE_VERSION=$NODE_VERSION"; \
    NVM_DEBUG=1 nvm install "$NODE_VERSION" 2>&1 | tee /tmp/nvm-install.log; \
    EXIT=${PIPESTATUS[0]}; \
    echo "=== Full nvm install output (exit=$EXIT) ==="; \
    cat /tmp/nvm-install.log; \
    exit $EXIT'
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="/usr/local/bin:/root/.nvm/versions/node/v${NODE_VERSION}/bin:${PATH}"

# Build everything at image build time (not container startup)
RUN npm install && make binary_dist && make devserver

# Run server on :3333
EXPOSE 3333/tcp
CMD ["./wowsimwotlk", "--usefs=true", "--launch=false", "--host=:3333"]
