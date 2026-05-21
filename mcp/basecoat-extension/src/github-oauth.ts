import { createHmac } from "crypto";
import { logger } from "./logger.js";
import { SessionStore, UserSession } from "./session.js";

export class GitHubOAuthManager {
  private sessionStore: SessionStore;

  constructor(sessionStore?: SessionStore) {
    this.sessionStore = sessionStore ?? new SessionStore();
  }

  /**
   * Generate an OAuth state parameter for CSRF protection.
   */
  generateState(): string {
    return this.sessionStore.generateStateParam();
  }

  /**
   * Validate an OAuth state parameter.
   */
  validateState(state: string): boolean {
    if (!state || typeof state !== "string") {
      logger.warn("oauth_state_invalid", { reason: "missing_or_invalid_type" });
      return false;
    }

    const session = this.sessionStore.validateState(state);
    if (!session) {
      logger.warn("oauth_state_invalid", { reason: "state_validation_failed" });
      return false;
    }

    logger.info("oauth_state_valid", { statePrefix: state.slice(0, 8) });
    return true;
  }

  /**
   * Validate and retrieve user session by state (consumes the state).
   */
  validateAndGetUserSession(state: string): UserSession | null {
    if (!state || typeof state !== "string") {
      logger.warn("oauth_state_invalid", { reason: "missing_or_invalid_type" });
      return null;
    }

    const session = this.sessionStore.validateState(state);
    if (!session) {
      logger.warn("oauth_state_invalid", { reason: "state_validation_failed" });
      return null;
    }

    logger.info("oauth_state_valid", { statePrefix: state.slice(0, 8) });
    return session;
  }

  /**
   * Store OAuth token for user session.
   */
  storeUserToken(state: string, userId: string, token: string): void {
    const session = this.sessionStore.storeUserSession(state, userId, token);
    if (session) {
      logger.info("oauth_token_stored", {
        userId,
        sessionId: session.sessionId.slice(0, 8),
      });
    }
  }

  /**
   * Retrieve user session by state.
   */
  getUserSession(state: string): UserSession | null {
    return this.sessionStore.getSession(state);
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
   * Stop the session cleanup interval (useful for testing).
   */
  stopCleanupInterval(): void {
    this.sessionStore.stopCleanupInterval();
  }
}

export const gitHubOAuthManager = new GitHubOAuthManager();
