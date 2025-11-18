# Swift Complexity Backend

This directory contains the backend infrastructure for the Swift Complexity API, consisting of two main components:

## Architecture

```
backend/
├── app/              # Swift/Vapor application (Container)
│   ├── Sources/      # Swift source code
│   ├── Tests/        # Swift tests
│   ├── Package.swift # Swift package definition
│   └── Dockerfile    # Container image
└── worker/           # Cloudflare Worker (Proxy)
    ├── src/          # TypeScript source code
    ├── wrangler.toml # Cloudflare configuration
    └── package.json  # Node dependencies
```

## Components

### App (Swift/Vapor Container)

The backend application is built with Swift and Vapor framework, running inside a Cloudflare Container.

**Directory**: `app/`

**Key Files**:
- `Package.swift`: Swift package dependencies and target configuration
- `Dockerfile`: Container image definition
- `Sources/App/`: Main application code

**Development**:
```bash
cd app
swift build
swift run
swift test
```

### Worker (Cloudflare Worker)

The Worker acts as a proxy that forwards requests to the Container, handling CORS and providing a global edge network.

**Directory**: `worker/`

**Key Files**:
- `wrangler.toml`: Cloudflare Worker configuration
- `src/index.ts`: Main Worker entry point
- `src/container.ts`: Container configuration

**Development**:
```bash
cd worker
npm install
npm run dev          # Local development
npm run type-check   # TypeScript validation
```

## Deployment

### Default Deployment

```bash
cd worker
npm run deploy
```

### Production Environment

```bash
cd worker
npm run deploy:prod
```

## Configuration

### Container Settings

Edit `worker/wrangler.toml` to configure:
- Container resources (CPU, memory)
- Max instances
- Health check settings
- Environment variables

### Environment Variables

**Default (Local Development)**:
- `PORT`: Container port (default: 8080)
- `LOG_LEVEL`: Logging level (default: debug)
- `ENVIRONMENT`: Environment name (default: develop)

**Production**:
- `PORT`: Container port (default: 8080)
- `LOG_LEVEL`: Logging level (default: info)
- `ENVIRONMENT`: Environment name (default: production)

## Local Development

1. **Start the Container (Swift/Vapor app)**:
   ```bash
   cd app
   swift run
   ```

2. **Start the Worker**:
   ```bash
   cd worker
   npm run dev
   ```

## API Endpoints

The Worker proxies all requests to the Container. Available endpoints depend on the Vapor application implementation.

Example:
- `GET /health` - Health check endpoint
- `POST /api/analyze` - Analyze Swift code complexity

## CORS Configuration

The Worker automatically adds CORS headers to all responses:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS`
- `Access-Control-Allow-Headers: Origin, Content-Type, Accept, Authorization`

## Monitoring

Observability is enabled for both development and production environments. View logs and metrics in the Cloudflare dashboard.
