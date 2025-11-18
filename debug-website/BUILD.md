# Build & Deploy Guide

## 統合アーキテクチャ

```
Cloudflare Worker (OpenNext)
├── Frontend (Next.js static & server components)
└── API Routes → Cloudflare Containers (Vapor Backend)
```

### リクエストフロー

**本番環境:**
1. Browser → `https://swift-complexity.fummicc1.dev`
2. OpenNext Worker → Next.js App Router
3. API Route (`/api/analyze`) → Container (Vapor) via `getContainer()`
4. Container → レスポンス

**開発環境:**
1. Browser → `http://localhost:3000`
2. Next.js dev server → API Route (`/api/analyze`)
3. API Route → `http://localhost:8080` (local Vapor)
4. Vapor → レスポンス

## セットアップ

```bash
cd debug-website
npm install  # 依存関係とworkspaceをインストール
```

## ローカル開発

### 初回セットアップ
```bash
cd debug-website
npm install  # ルートとfrontend workspaceの両方をインストール
```

### Frontend開発サーバー
```bash
cd debug-website
npm run dev:frontend
```
`http://localhost:3000`で起動

### Backend開発サーバー
```bash
cd debug-website
npm run dev:backend
```
`http://localhost:8080`で起動

## ビルド

### 1. Backend Docker Image

```bash
cd debug-website
npm run build:backend
```

または直接実行：
```bash
docker build -f debug-website/backend/Dockerfile -t swift-complexity-backend .

# ローカルテスト
docker run -p 8080:8080 swift-complexity-backend
```

### 2. Frontend (OpenNext)

```bash
cd debug-website
npm run build:worker
```

これにより `frontend/.open-next/` ディレクトリにCloudflare Workers用のビルドが生成されます。

## デプロイ

### 前提条件
```bash
cd debug-website
npm install  # Wranglerと依存関係をインストール
```

- Cloudflare account
- Docker installed

### Cloudflare Workers + Containersへのデプロイ

```bash
cd debug-website

# ログイン（初回のみ）
npx wrangler login

# 本番環境へデプロイ
npm run deploy:production
```

このコマンドで以下が自動的に実行されます：
1. Backend Docker imageのビルドとContainer化
2. Frontend OpenNextビルド
3. Worker + Containerの統合デプロイ

### 開発環境へのデプロイ

```bash
cd debug-website
npm run deploy
```

## 環境変数

### Frontend (.env.local for local development)
```bash
NEXT_PUBLIC_API_URL=http://localhost:8080
```

### Wrangler Production Variables
```bash
# wrangler.tomlで設定済み
BACKEND_API_URL=https://your-backend-url.fly.dev
```

### Backend Environment
```bash
# Fly.io
fly secrets set LOG_LEVEL=info

# Railway
railway variables set LOG_LEVEL=info
```

## Container設定

### Next.js API RoutesからContainerへのアクセス

Next.js App RouterのRoute Handlers (`app/api/*/route.ts`) がEdge Runtimeで実行され、`env`経由でContainerに直接アクセスします。

**wrangler.jsonc設定:**

```jsonc
{
  "name": "swift-complexity",
  "main": "frontend/.open-next/worker.js",

  // Container configuration
  "durable_objects": {
    "bindings": [
      {
        "name": "SWIFT_COMPLEXITY_BACKEND",
        "class_name": "SwiftComplexityBackend",
        "script_name": "swift-complexity"
      }
    ]
  },

  "env": {
    "production": {
      "containers": [
        {
          "class_name": "SwiftComplexityBackend",
          "image": "./backend/Dockerfile",
          "max_instances": 2
        }
      ]
    }
  }
}
```

**Container Class定義 (open-next.config.ts):**

```typescript
import { Container } from "@cloudflare/containers";

export class SwiftComplexityBackend extends Container {
  defaultPort = 8080;
  sleepAfter = "2m";
}
```

**API Route実装 (app/api/analyze/route.ts):**

```typescript
import { getContainer } from "@cloudflare/containers";

export const runtime = "edge";

export async function POST(request: NextRequest) {
  const env = process.env as unknown as Env;

  // 本番環境: Containerに直接アクセス
  if (env.SWIFT_COMPLEXITY_BACKEND) {
    return getContainer(env.SWIFT_COMPLEXITY_BACKEND).fetch(request);
  }

  // 開発環境: localhost:8080にフォールバック
  return fetch("http://localhost:8080/api/v1/analyze", { ... });
}
```

**重要なポイント:**

1. **OpenNext統合**: カスタムworker-wrapperは不要。OpenNextが生成する`.open-next/worker.js`を直接使用
2. **Edge Runtime**: API Routesが`runtime = "edge"`で実行されるため、`env`にアクセス可能
3. **Container Class**: `open-next.config.ts`でContainer classを定義し、wrangler.jsonc で参照
4. **環境自動検出**: API Route内で`env.SWIFT_COMPLEXITY_BACKEND`の有無を確認して本番/開発を判定

## トラブルシューティング

### OpenNext Build Errors

```bash
# キャッシュクリア
rm -rf frontend/.next frontend/.open-next
npm run build:worker
```

### Service Binding Not Working

1. バックエンドが正常に動作しているか確認
```bash
curl https://your-backend-url/health
```

2. wrangler.tomlのservice名が正しいか確認

3. Cloudflare Dashboardでbindingを確認

### CORS Issues

開発環境では自動的にCORSが有効（`AppConfiguration`）。
本番環境ではService Bindingを使うため、CORSは不要です。

## コスト見積もり

### Cloudflare Workers
- **無料枠**: 100,000 requests/day
- **有料**: $5/month for 10M requests

### Backend Hosting (Fly.io)
- **無料枠**: 3 shared VMs with 256MB
- **推奨**: $2-5/month for 512MB-1GB RAM

### 合計
**開発**: $0/month（無料枠内）
**本番**: $2-10/month（トラフィック次第）

## 監視

### Cloudflare Dashboard
- Workers → Metrics
- Real-time logs
- Analytics

### Backend (Fly.io)
```bash
fly logs
fly status
fly metrics
```

## スケーリング

### Cloudflare Workers
自動スケーリング（設定不要）

### Backend
```bash
# Fly.io
fly scale count 2  # 2インスタンスに増やす
fly scale vm shared-cpu-2x  # より大きいVMに
```
