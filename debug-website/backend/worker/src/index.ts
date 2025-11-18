/**
 * Cloudflare Worker that proxies requests to the Container running the Swift/Vapor backend
 */

import { getRandom } from "@cloudflare/containers";
import { SwiftComplexityContainer } from "./container";

export interface Env {
  // Durable Object binding for the container
  SWIFT_COMPLEXITY_CONTAINER: DurableObjectNamespace<SwiftComplexityContainer>;
}

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Log incoming request
    console.log(`[Worker] ${request.method} ${url.pathname}`, {
      headers: Object.fromEntries(request.headers.entries()),
      cf: request.cf,
    });

    try {
      // Handle CORS preflight requests
      if (request.method === 'OPTIONS') {
        console.log('[Worker] Handling OPTIONS preflight request');
        return new Response(null, {
          status: 204,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
            'Access-Control-Max-Age': '86400',
          },
        });
      }

      // Create new headers for the container request
      const headers = new Headers(request.headers);

      // Remove Cloudflare-specific headers that might interfere
      headers.delete('cf-connecting-ip');
      headers.delete('cf-ray');
      headers.delete('cf-visitor');

      // Create a new request with modified headers
      const containerRequest = new Request(request.url, {
        method: request.method,
        headers: headers,
        body: request.body,
        redirect: 'manual',
      });

      console.log('[Worker] Getting container instance');
      const container = await getRandom(env.SWIFT_COMPLEXITY_CONTAINER, 1);

      console.log('[Worker] Forwarding request to container');
      // Forward the request to the container via Durable Object
      const response = await container.fetch(containerRequest);

      console.log(`[Worker] Container response: ${response.status} ${response.statusText}`);

      // Clone the response and add CORS headers
      const modifiedResponse = new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: new Headers(response.headers),
      });

      // Add CORS headers to the response
      const corsHeaders = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
        'Access-Control-Max-Age': '86400',
      };

      Object.entries(corsHeaders).forEach(([key, value]) => {
        modifiedResponse.headers.set(key, value);
      });

      return modifiedResponse;

    } catch (error) {
      // Log the error for debugging
      console.error('[Worker] Error:', error);

      // Return a proper error response
      return new Response(
        JSON.stringify({
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Unknown error occurred',
        }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      );
    }
  },
};

// Export the Container class for use in wrangler.toml
export { SwiftComplexityContainer };
