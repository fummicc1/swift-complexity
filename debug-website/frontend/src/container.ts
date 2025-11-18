/**
 * Container class for SwiftComplexity backend
 * Defines configuration for the Vapor backend running in Cloudflare Containers
 */

import { Container } from "@cloudflare/containers";

export class SwiftComplexityBackend extends Container {
  // The port the Vapor application listens on inside the container
  defaultPort = 8080;

  // Auto-hibernate the container after 2 minutes of idle time to save resources
  sleepAfter = "2m";
}
