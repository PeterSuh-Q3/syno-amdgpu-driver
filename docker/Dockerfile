FROM dante90/syno-compiler:7.4 AS synology-toolchain

FROM debian:12-slim

# The compiler image supplies the DSM ABI toolchain. Its Debian package manager
# cannot unpack current .deb archives, so native build tools are installed from
# a clean Debian layer instead of modifying the compiler image in place.
COPY --from=synology-toolchain /opt/epyc7002 /opt/epyc7002

USER 0

# Native tools execute while building; target artifacts are always linked with
# /opt/epyc7002/bin/x86_64-pc-linux-gnu-gcc by the build scripts.
RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      bison \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      flex \
      git \
      glslang-tools \
      meson \
      ninja-build \
      pkg-config \
      python3 \
      python3-mako \
      python3-pip \
      xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m pip install --no-cache-dir --break-system-packages meson==1.5.2 \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal \
    && /root/.cargo/bin/rustup target add x86_64-unknown-linux-gnu

ENV PATH=/root/.cargo/bin:${PATH}
