# Deployment Guide

## Architecture

```
User
  ↓
Cloudflare Pages/Workers (Frontend - Next.js)
  ↓ HTTPS
Backend API (Vapor)
```

## Frontend Deployment (Cloudflare Pages)

### Prerequisites
- Cloudflare account
- GitHub repository connected to Cloudflare Pages

### Steps

1. **Build Configuration**
```bash
cd debug-website/frontend
npm install
npm run build
```

2. **Deploy to Cloudflare Pages**
```bash
npm install -g wrangler
wrangler pages deploy .next
```

Or use Cloudflare Dashboard:
- Connect GitHub repository
- Build command: `cd debug-website/frontend && npm install && npm run build`
- Build output directory: `debug-website/frontend/.next`
- Environment variables:
  - `NEXT_PUBLIC_API_URL`: Your backend API URL

## Backend Deployment

### Option 1: Fly.io (Recommended)

Fly.io has excellent support for Docker and provides free tier.

1. **Install Fly CLI**
```bash
curl -L https://fly.io/install.sh | sh
```

2. **Initialize and Deploy**
```bash
cd debug-website/backend
fly launch --dockerfile ../../Dockerfile --region nrt --name swift-complexity-api
fly deploy
```

3. **Set Environment Variables**
```bash
fly secrets set LOG_LEVEL=info
```

4. **Custom Domain (Optional)**
```bash
fly certs add api.swift-complexity.fummicc1.dev
```

### Option 2: Railway

1. **Install Railway CLI**
```bash
npm install -g railway
```

2. **Initialize and Deploy**
```bash
cd debug-website/backend
railway init
railway up
```

3. **Add Custom Domain**
- Go to Railway dashboard
- Add domain: `api.swift-complexity.fummicc1.dev`

### Option 3: Render

1. **Create Account** at render.com

2. **New Web Service**
- Connect GitHub repository
- Root Directory: `debug-website/backend`
- Environment: Docker
- Dockerfile Path: `../../Dockerfile`
- Build Context: Repository root

3. **Environment Variables**
- `LOG_LEVEL`: info

4. **Custom Domain**
- Add: `api.swift-complexity.fummicc1.dev`

### Option 4: Cloudflare Containers (Future)

⚠️ Cloudflare Containers is currently in limited beta. When generally available:

```bash
cd debug-website/backend
wrangler deploy
```

## Testing Deployment

### Health Check
```bash
curl https://api.swift-complexity.fummicc1.dev/health
```

### Analyze Endpoint
```bash
curl -X POST https://api.swift-complexity.fummicc1.dev/api/v1/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "code": "func test() -> Int { return 1 }",
    "fileName": "test.swift"
  }'
```

## CORS Configuration

The backend automatically configures CORS based on environment:

- **Development**: All origins allowed
- **Production**: Only `https://swift-complexity.fummicc1.dev`

To modify allowed origins, edit `debug-website/backend/Sources/App/Configuration/AppConfiguration.swift`.

## Monitoring

### Fly.io
```bash
fly logs
fly status
```

### Railway
```bash
railway logs
```

### Render
- View logs in Render dashboard

## Troubleshooting

### CORS Errors
- Verify backend is running: `curl https://api.swift-complexity.fummicc1.dev/health`
- Check environment variable: `NEXT_PUBLIC_API_URL` in frontend
- Verify CORS configuration in backend

### Build Errors
- Ensure Docker context is set to repository root
- Dockerfile must have access to both `debug-website/backend` and `Sources/SwiftComplexityCore`

### Performance
- Enable HTTP/2 on hosting platform
- Consider adding Redis cache for repeated analyses
- Monitor memory usage (Vapor can be memory-intensive)

## Costs

### Cloudflare Pages
- **Free tier**: 500 builds/month, unlimited requests

### Fly.io
- **Free tier**: 3 shared VMs with 256MB RAM each
- **Recommended**: Upgrade to 512MB RAM (~$2/month)

### Railway
- **Free tier**: $5 credit/month
- **Estimated cost**: ~$5-10/month for light usage

### Render
- **Free tier**: Available with limitations (spins down after inactivity)
- **Starter**: $7/month for always-on instance
