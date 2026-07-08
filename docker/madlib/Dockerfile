# Apache MADlib comparison environment (Tier 1).
#
# Base: madlib/postgres_11:jenkins — the MADlib project's own CI image
# (official postgres:11 + the exact toolchain MADlib 1.x is built with:
# cmake 3.7, g++, python 2.7). MADlib itself is NOT preinstalled in that
# image, so we build the 1.21.0 release from the Apache archive here.
#
# Note: this environment is for API-design comparison, not performance
# benchmarking, so an older PostgreSQL (11) is acceptable; what matters is
# the shape of the MADlib SQL API, which is the same across versions.
#
# madpack (schema installation into a running database) is executed at
# container runtime by scripts/20_madlib_smoke.sh, because it needs a live
# server connection.
FROM madlib/postgres_11:jenkins

ARG MADLIB_VERSION=1.21.0

RUN set -eux; \
    wget -qO /tmp/madlib.tar.gz \
        "https://archive.apache.org/dist/madlib/${MADLIB_VERSION}/apache-madlib-${MADLIB_VERSION}-src.tar.gz"; \
    mkdir -p /tmp/madlib-src; \
    tar -xzf /tmp/madlib.tar.gz -C /tmp/madlib-src --strip-components=1; \
    mkdir /tmp/madlib-src/build; \
    cd /tmp/madlib-src/build; \
    cmake ..; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/madlib.tar.gz /tmp/madlib-src
