import { randomBytes, createHmac } from "crypto";
import { logger } from "./logger.js";

export type OAuthState = {
  state: string;
  expiresAt: number;
  userId?: string;
  token?: string;
};

export class GitHubOAuthManager {
  private states: Map<string, OAuthState> = new Map();
  private readonly stateTimeoutMs = 10 * 60 * 1000; // 10 minutes

  constructor() {
    this.startCleanupInterval();
  }

  /**
   * Generate an OAuth state parameter for CSRF protection.
   */
  generateState(): string {
    const state = randomBytes(32).toString("hex");
    const expiresAt = Date.now() + this.stateTimeoutMs;

    this.states.set(state, { state, expiresAt });
    logger.info("oauth_state_generated", {
      statePrefix: state.slice(0, 8),
      expiresAt,
    });

    return state;
  }

  /**
   * Validate an OAuth state parameter.
   */
  validateState(state: string): boolean {
    if (!state || typeof state !== "string") {
      logger.warn("oauth_state_invalid", { reason: "missing_or_invalid_type" });
      return false;
    }

    const entry = this.states.get(state);
    if (!entry) {
      logger.warn("oauth_state_invalid", { reason: "unknown_state" });
      return false;
    }

    if (Date.now() > entry.expiresAt) {
      logger.warn("oauth_state_invalid", { reason: "expired" });
      this.states.delete(state);
      return false;
    }

    this.states.delete(state);
    logger.info("oauth_state_valid", { statePrefix: state.slice(0, 8) });
    return true;
  }

  /**
   * Store OAuth token for user session.
   */
  storeUserToken(state: string, userId: string, token: string): void {
    const entry = this.states.get(state);
    if (entry) {
      entry.userId = userId;
      entry.token = token;
      logger.info("oauth_token_stored", { userId });
    }
  }

  /**
   * Retrieve user token by state.
   */
  getUserToken(state: string): { userId?: string; token?: string } | null {
    return this.states.get(state) ?? null;
  }

  /**
   * Validate GitHub webhook signature (sync version using built-in crypto).
   */
  validateWebhookSignature(
    payload: string,
    signature: string,
    secret: string
  ): boolean {
    // Signature format: sha256=<hex>
    if (!signature || !signature.startsWith("sha256=")) {
      logger.warn("webhook_signature_invalid", { reason: "invalid_format" });
      return false;
    }

    const expectedSignature =
      "sha256=" +
      createHmac("sha256", secret)
        .update(payload)
        .digest("hex");

    const isValid = expectedSignature === signature;
    if (!isValid) {
      logger.warn("webhook_signature_invalid", { reason: "mismatch" });
    }
    return isValid;
  }

  /**
   * Clean up expired state entries periodically.
   */
  private startCleanupInterval(): void {
    setInterval(() => {
      const now = Date.now();
      let cleaned = 0;
      for (const [state, entry] of this.states.entries()) {
        if (now > entry.expiresAt) {
          this.states.delete(state);
          cleaned++;
        }
      }
      if (cleaned > 0) {
        logger.info("oauth_state_cleanup", { cleaned });
      }
    }, 60000); // Run every 1 minute
  }
}

export const gitHubOAuthManager = new GitHubOAuthManager();
