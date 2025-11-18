import type { NextRequest } from "next/server";
import type { DurableObjectNamespace } from "@cloudflare/workers-types";

// Edge Runtimeで実行（Cloudflare Workers環境でenvにアクセス可能）
export const runtime = "edge";

interface Env {
  SWIFT_COMPLEXITY_BACKEND?: DurableObjectNamespace;
}

export async function POST(request: NextRequest) {
  const env = process.env as unknown as Env;

  try {
    const body = await request.text();

    const backendRequest = new Request("http://localhost:8080/api/v1/analyze", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body,
    });

    // 本番環境: Containerに直接アクセス / 開発環境: localhostにフォールバック
    if (env.SWIFT_COMPLEXITY_BACKEND) {
      // Dynamic importでCloudflare Workers環境でのみロード
      const { getContainer } = await import("@cloudflare/containers");
      return getContainer(env.SWIFT_COMPLEXITY_BACKEND).fetch(backendRequest);
    }

    // 開発環境: localhostにフォールバック
    const response = await fetch(backendRequest);
    return response;
  } catch (error) {
    console.error("Backend fetch error:", error);
    return new Response(
      JSON.stringify({ error: "Backend service unavailable" }),
      {
        status: 503,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
}
