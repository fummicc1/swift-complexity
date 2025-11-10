# ================================
# Build stage
# ================================
FROM swift:6.1-jammy as build

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
      ca-certificates \
      tzdata \
    && rm -rf /var/lib/apt/lists/*

# Set up a build area
WORKDIR /build

# Copy entire swift-complexity project (backend needs SwiftComplexityCore)
COPY . .

# Change to backend directory
WORKDIR /build/debug-website/backend

# Build with optimizations
RUN swift build -c release \
    --static-swift-stdlib \
    -Xlinker -s

# ================================
# Run stage
# ================================
FROM ubuntu:jammy

# Install runtime dependencies
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q install -y \
      ca-certificates \
      tzdata \
      libcurl4 \
      libxml2 \
    && rm -rf /var/lib/apt/lists/*

# Create a vapor user and group with /app as home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Switch to the new home directory
WORKDIR /app

# Copy built executable from build stage
COPY --from=build --chown=vapor:vapor /build/debug-website/backend/.build/release/App /app/

# Ensure executable has correct permissions
RUN chmod +x /app/App

# Switch to vapor user
USER vapor:vapor

# Expose port 8080
EXPOSE 8080

# Start the Vapor application
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
