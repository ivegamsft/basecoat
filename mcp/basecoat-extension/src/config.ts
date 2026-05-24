import { logger } from "./logger.js";

export type AuthMode = "github-app" | "app-token" | "oidc";

export type ExtensionConfig = {
  authMode: AuthMode;
  baseUrl: string;
  port: number;
  // GitHub App (user-delegated OAuth) — default
  appId?: string;
  clientId?: string;
  clientSecret?: string;
  webhookSecret?: string;
  privateKeyPem?: string;
  // App Token (service account) — alternative
  githubToken?: string;
  // OIDC (Azure managed identity) — alternative
  oidcIssuer?: string;
  oidcSubject?: string;
};

function detectAuthMode(): AuthMode {
  // Priority order: explicit > app-token > oidc > github-app (default)
  if (process.env.BASECOAT_EXTENSION_AUTH_MODE) {
    const mode = process.env.BASECOAT_EXTENSION_AUTH_MODE.toLowerCase();
    if (mode === "github-app" || mode === "app-token" || mode === "oidc") {
      return mode as AuthMode;
    }
  }

  // Auto-detect based on available credentials
  if (process.env.BASECOAT_EXTENSION_GITHUB_TOKEN) {
    return "app-token";
  }
  if (process.env.BASECOAT_EXTENSION_OIDC_ENABLED === "true") {
    return "oidc";
  }

  return "github-app"; // default
}

function validateGitHubAppConfig(): Partial<ExtensionConfig> | null {
  const required = [
    "BASECOAT_EXTENSION_APP_ID",
    "BASECOAT_EXTENSION_CLIENT_ID",
    "BASECOAT_EXTENSION_CLIENT_SECRET",
    "BASECOAT_EXTENSION_WEBHOOK_SECRET",
    "BASECOAT_EXTENSION_PRIVATE_KEY_PEM",
  ];

  const missing = required.filter((v) => !process.env[v]);

  if (missing.length > 0) {
    return null;
  }

  return {
    appId: process.env.BASECOAT_EXTENSION_APP_ID!,
    clientId: process.env.BASECOAT_EXTENSION_CLIENT_ID!,
    clientSecret: process.env.BASECOAT_EXTENSION_CLIENT_SECRET!,
    webhookSecret: process.env.BASECOAT_EXTENSION_WEBHOOK_SECRET!,
    privateKeyPem: process.env.BASECOAT_EXTENSION_PRIVATE_KEY_PEM!,
  };
}

export function validateConfig(): ExtensionConfig {
  const authMode = detectAuthMode();

  let authConfig: Partial<ExtensionConfig> = {};

  if (authMode === "github-app") {
    authConfig = validateGitHubAppConfig() || {};
    if (!authConfig.appId) {
      logger.error("config_validation_failed", {
        reason: "github_app_credentials_missing",
        authMode,
      });
      console.error(
        `\n❌ GitHub App Authentication Error:
   Set one of:
   1. GitHub App mode: BASECOAT_EXTENSION_APP_ID, BASECOAT_EXTENSION_CLIENT_ID, etc.
   2. App Token mode: BASECOAT_EXTENSION_GITHUB_TOKEN
   3. OIDC mode: BASECOAT_EXTENSION_OIDC_ENABLED=true

   Bootstrap guide: ./scripts/bootstrap-credentials.ps1\n`
      );
      process.exit(1);
    }
  } else if (authMode === "app-token") {
    if (!process.env.BASECOAT_EXTENSION_GITHUB_TOKEN) {
      logger.error("config_validation_failed", {
        reason: "github_token_missing",
        authMode,
      });
      console.error(
        `\n❌ App Token Authentication Error:
   Set: BASECOAT_EXTENSION_GITHUB_TOKEN=<personal-access-token-or-workflow-token>\n`
      );
      process.exit(1);
    }
    authConfig = {
      githubToken: process.env.BASECOAT_EXTENSION_GITHUB_TOKEN,
    };
  } else if (authMode === "oidc") {
    if (!process.env.AZURE_TENANT_ID || !process.env.AZURE_CLIENT_ID) {
      logger.error("config_validation_failed", {
        reason: "oidc_credentials_missing",
        authMode,
      });
      console.error(
        `\n❌ OIDC Authentication Error:
   Set Azure credentials:
   - AZURE_TENANT_ID
   - AZURE_CLIENT_ID
   - AZURE_FEDERATED_TOKEN_FILE\n`
      );
      process.exit(1);
    }
    authConfig = {
      oidcIssuer: process.env.AZURE_TENANT_ID,
      oidcSubject: process.env.AZURE_CLIENT_ID,
    };
  }

  const config: ExtensionConfig = {
    authMode,
    ...authConfig,
    baseUrl:
      process.env.BASECOAT_EXTENSION_BASE_URL || "http://localhost:3000",
    port: Number.parseInt(process.env.PORT ?? "3000", 10),
  };

  logger.info("config_validated", {
    authMode: config.authMode,
    baseUrl: config.baseUrl,
    port: config.port,
  });

  return config;
}
