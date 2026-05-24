import { useAzureMonitor } from "@azure/monitor-opentelemetry";
import { trace } from "@opentelemetry/api";
import { logger } from "./logger.js";

let initialized = false;

export const extensionTracer = trace.getTracer("basecoat-extension");

export function initializeObservability(): void {
  if (initialized) {
    return;
  }

  const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING?.trim();
  if (!connectionString) {
    logger.warn("observability_disabled", {
      reason: "APPLICATIONINSIGHTS_CONNECTION_STRING_not_set",
    });
    return;
  }

  useAzureMonitor({
    azureMonitorExporterOptions: {
      connectionString,
    },
  });

  initialized = true;
  logger.info("observability_enabled");
}

