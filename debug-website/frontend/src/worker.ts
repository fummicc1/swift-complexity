/**
 * Cloudflare Worker entry point
 * Routes requests to either OpenNext (Next.js) or Container (Vapor backend)
 */

import { getRandom } from "@cloudflare/containers";
import { SwiftComplexityBackend } from "./container";

// OpenNextが生成するworkerをインポート
// @ts-expect-error - OpenNextビルド後に生成されるファイル
import openNextHandler from "../.open-next/worker.js";

export interface Env {
  // Durable Object binding for the container
  SWIFT_COMPLEXITY_BACKEND: DurableObjectNamespace<SwiftComplexityBackend>;
  // Assets binding for static files
  ASSETS: any;
}

export { SwiftComplexityBackend };

export default {
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    // すべてのリクエストをOpenNextに転送
    // Next.jsのAPI Routes内でContainerにアクセス
    return openNextHandler.default.fetch(request, env, ctx);
  },
};
