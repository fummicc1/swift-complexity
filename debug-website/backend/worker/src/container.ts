/**
 * Container class for Swift Complexity API
 * This provides configuration and control over the container lifecycle
 */

import { Container } from "@cloudflare/containers";
import { env } from "cloudflare:workers";

export class SwiftComplexityContainer extends Container {
  // The port the Vapor application listens on inside the container
  defaultPort = 8080;

  // Auto-hibernate the container after 10 minutes of idle time to save resources
  sleepAfter = "10m";

  // CPU and memory limits
  cpu = 1;
  memory = "512Mi";

  // Health check configuration
  healthCheck = {
    port: 8080,
    path: "/health",
    interval: "30s",
    timeout: "10s",
  };

  envVars = {
    // Environment variables for the container
    // These can be set in wrangler.toml or overridden here
    LOG_LEVEL: (env as any).LOG_LEVEL || "info",
    ENVIRONMENT: (env as any).ENVIRONMENT || "develop",
  }
}
