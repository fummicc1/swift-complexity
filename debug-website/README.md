# Swift Complexity Debug Website

Web-based debugging interface for [swift-complexity](https://github.com/fummicc1/swift-complexity). Analyze Swift code complexity metrics interactively in your browser.

## 🎯 Features

- **Interactive Code Editor**: Monaco Editor with Swift syntax highlighting
- **Real-time Analysis**: Instant complexity calculation for Swift code
- **Multiple Metrics**: Both cyclomatic and cognitive complexity
- **Visual Results**: Color-coded complexity scores and summary statistics
- **Multiple Output Formats**: JSON, XML, Text, and Xcode formats
- **Responsive Design**: Works on desktop and mobile devices

## 🏗️ Architecture

### Frontend (Next.js)
- **Framework**: Next.js 15 with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Editor**: Monaco Editor (@monaco-editor/react)
- **Build Adapter**: OpenNext for Cloudflare
- **Deployment**: Cloudflare Workers

### Backend (Vapor)
- **Framework**: Vapor 4
- **Language**: Swift 6.1
- **Core Library**: SwiftComplexityCore
- **Deployment**: Cloudflare Containers

## 🚀 Getting Started

### Prerequisites

- Node.js 20+ (for frontend)
- Swift 6.1+ (for backend)
- Docker (for containerized deployment)

### Local Development

#### Backend

```bash
cd debug-website/backend

# Install dependencies
swift package resolve

# Run development server
swift run App serve --hostname 0.0.0.0 --port 8080
```

The backend API will be available at `http://localhost:8080`.

#### Frontend

```bash
cd debug-website/frontend

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env.local
# Edit .env.local to point to your backend

# Run development server (Next.js)
npm run dev

# Or run with Wrangler for local Workers environment
npx wrangler dev
```

The frontend will be available at `http://localhost:3000` (npm run dev) or `http://localhost:8788` (wrangler dev).

### Testing

#### Backend Tests

```bash
cd debug-website/backend
swift test
```

#### Frontend Type Check

```bash
cd debug-website/frontend
npm run type-check
```

## 📦 Deployment

### Cloudflare Workers (Frontend)

```bash
cd debug-website/frontend

# Build with OpenNext for Cloudflare Workers
npm run open-next:build

# Deploy to Cloudflare Workers
npx wrangler deploy --env production

# Or use the combined command
npm run deploy
```

The OpenNext build adapter converts Next.js into a format compatible with Cloudflare Workers.

### Cloudflare Containers (Backend)

```bash
cd debug-website/backend/app

# Build Docker image (from app directory)
docker build -t swift-complexity-api .

# Deploy to Cloudflare Containers
npx wrangler deploy
```

## 🔧 Configuration

### Environment Variables

#### Frontend (.env.local)

```bash
NEXT_PUBLIC_API_URL=http://localhost:8080
```

For production, configure environment variables in `wrangler.toml`:

```toml
[vars]
NEXT_PUBLIC_API_URL = "http://localhost:8787"

[env.production.vars]
NEXT_PUBLIC_API_URL = "https://api.swift-complexity.fummicc1.dev"
```

#### Backend (Production)

Set these in Cloudflare Workers dashboard or wrangler.toml:

```bash
LOG_LEVEL=info
```

## 📡 API Endpoints

### POST /api/v1/analyze
Analyzes Swift code and returns complexity metrics.

**Request:**
```json
{
  "code": "func example() { ... }",
  "fileName": "example.swift",
  "format": "json",  // Optional: "text" | "json" | "xml" | "xcode"
  "threshold": 10    // Optional: filter functions by complexity
}
```

**Response (without format):**
```json
{
  "filePath": "example.swift",
  "functions": [
    {
      "name": "example",
      "signature": "func example()",
      "cyclomaticComplexity": 2,
      "cognitiveComplexity": 1,
      "location": { "line": 1, "column": 1 }
    }
  ],
  "summary": {
    "totalFunctions": 1,
    "averageCyclomaticComplexity": 2.0,
    ...
  }
}
```

**Response (with format):**
```json
{
  "formatted": "... formatted output string ..."
}
```

### POST /api/v1/batch-analyze
Analyzes multiple Swift files.

### GET /health
Health check endpoint.

## 🎨 UI Components

### CodeEditor
Monaco Editor component with Swift language support.

### ComplexityResults
Displays analysis results with:
- Summary statistics
- Function-by-function breakdown
- Color-coded complexity scores (green/yellow/red)

## 🐳 Docker

The backend includes a multi-stage Dockerfile optimized for Cloudflare Containers:

1. **Build stage**: Compiles Swift code with release optimizations
2. **Run stage**: Minimal Ubuntu image with only runtime dependencies

## 📝 Development Notes

- Backend uses Swift 6.1 with strict concurrency checking
- Frontend uses React 19 with Next.js App Router
- OpenNext adapter (`@opennextjs/cloudflare`) enables Next.js on Cloudflare Workers
- Image optimization is disabled for Workers compatibility
- CORS configured to allow requests from `swift-complexity.fummicc1.dev`
- All API responses are JSON-encoded
- Static assets are served via Workers Assets binding

## 🤝 Contributing

This is part of the [swift-complexity](https://github.com/fummicc1/swift-complexity) project. Please refer to the main repository for contribution guidelines.

## 📄 License

Same as the parent swift-complexity project.

## 🔗 Links

- [swift-complexity (Main Repository)](https://github.com/fummicc1/swift-complexity)
- [SwiftSyntax](https://github.com/apple/swift-syntax)
- [Vapor](https://vapor.codes)
- [Next.js](https://nextjs.org)
- [Monaco Editor](https://microsoft.github.io/monaco-editor/)
