FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG FLUTTER_VERSION=3.47.5

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates \
       clang \
       cmake \
       curl \
       git \
       libgtk-3-dev \
       liblzma-dev \
       libglu1-mesa \
       ninja-build \
       pkg-config \
       unzip \
       xz-utils \
       zip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter.tar.xz \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && chown -R vscode:vscode /opt/flutter
