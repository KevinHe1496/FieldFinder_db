# ================================
# Build image
# ================================
FROM swift:6.0-noble AS build

# Install OS updates and required dev libraries
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y \
        libjemalloc-dev \
        libssl-dev \
        libpq-dev \
        pkg-config \
        curl \
        git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
    
# Set up a build area
WORKDIR /build

# First just resolve dependencies.
COPY ./Package.* ./
RUN swift package resolve \
        $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Copy entire repo into container
COPY . .

# Build the application, with optimizations, with static linking, and using jemalloc
RUN swift build -c release \
        --product FieldFinder_db \
        --static-swift-stdlib \
        -Xlinker -ljemalloc

# Switch to the staging area
WORKDIR /staging

# Copy main executable to staging area
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/FieldFinder_db" /staging/

# Copy static swift backtracer binary to staging area
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" /staging/

# Copy resources bundled by SPM to staging area
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" -regex '.*\.resources$' -exec cp -Ra {} /staging/ \;

# Copy Public and Resources directories if they exist
RUN [ -d /build/Public ] && { cp -r /build/Public /staging/Public && chmod -R a-w /staging/Public; } || true
RUN [ -d /build/Resources ] && { cp -r /build/Resources /staging/Resources && chmod -R a-w /staging/Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Install only required runtime packages
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
        libjemalloc2 \
        libssl-dev \
        libpq-dev \
        libcurl4 \
        libxml2 \
        ca-certificates \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

# Create a vapor user and group
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app

# Copy build artifacts
COPY --from=build --chown=vapor:vapor /staging /app

# Configure crash reporting and sensible defaults
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

# Use non-root user
USER vapor:vapor

EXPOSE 8080

ENTRYPOINT ["./FieldFinder_db"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
