import { logger } from "./logger.js";

export type ExtensionConfig = {
  appId: string;
  clientId: string;
  clientSecret: string;
  webhookSecret: string;
  privateKeyPem: string;
  baseUrl: string;
  port: number;
};

const requiredEnvVars = [
  "BASECOAT_EXTENSION_APP_ID",
  "BASECOAT_EXTENSION_CLIENT_ID",
  "BASECOAT_EXTENSION_CLIENT_SECRET",
  "BASECOAT_EXTENSION_WEBHOOK_SECRET",
  "BASECOAT_EXTENSION_PRIVATE_KEY_PEM",
];

export function validateConfig(): ExtensionConfig {
  const missing: string[] = [];

  for (const envVar of requiredEnvVars) {
    if (!process.env[envVar]) {
      missing.push(envVar);
    }
  }

  if (missing.length > 0) {
    logger.error("config_validation_failed", {
      reason: "missing_env_vars",
      missingCount: missing.length,
    });
    console.error(
      `\n❌ Configuration Error: Missing required environment variables:\n${missing.map((v) => `   - ${v}`).join("\n")}\n`
    );
    process.exit(1);
  }

  const config: ExtensionConfig = {
    appId: process.env.BASECOAT_EXTENSION_APP_ID!,
    clientId: process.env.BASECOAT_EXTENSION_CLIENT_ID!,
    clientSecret: process.env.BASECOAT_EXTENSION_CLIENT_SECRET!,
    webhookSecret: process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET!,
    privateKeyPem: process.env.BASECOAT_EXTENSION_PRIVATE_KEY_PEM!,
    baseUrl:
      process.env.BASECOAT_EXTENSION_BASE_URL ||
      "http://localhost:3000",
    port: Number.parseInt(process.env.PORT ?? "3000", 10),
  };

  logger.info("config_validated", {
    baseUrl: config.baseUrl,
    port: config.port,
    appId: config.appId.slice(0, 8),
  });

  return config;
}
