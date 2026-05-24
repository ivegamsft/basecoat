import { randomBytes } from "crypto";
import { logger } from "./logger.js";

export type UserSession = {
  sessionId: string;
  state: string;
  expiresAt: number;
  userId?: string;
  token?: string;
  createdAt: number;
};

export type SessionOptions = {
  ttlMs?: number;
  cleanupIntervalMs?: number;
};

export class SessionStore {
  private sessions: Map<string, UserSession> = new Map();
  private stateToSessionId: Map<string, string> = new Map();
  private readonly ttlMs: number;
  private readonly cleanupIntervalMs: number;
  private cleanupTimer: NodeJS.Timeout | null = null;

  constructor(options: SessionOptions = {}) {
    this.ttlMs = options.ttlMs ?? 10 * 60 * 1000; // 10 minutes default
    this.cleanupIntervalMs = options.cleanupIntervalMs ?? 60 * 1000; // 1 minute default
    this.startCleanupInterval();
  }

  /**
   * Generate a new OAuth state parameter and create a session for CSRF protection.
   */
  generateStateParam(): string {
    const state = randomBytes(32).toString("hex");
    const sessionId = randomBytes(16).toString("hex");
    const expiresAt = Date.now() + this.ttlMs;
    const createdAt = Date.now();

    const session: UserSession = {
      sessionId,
      state,
      expiresAt,
      createdAt,
    };

    this.sessions.set(sessionId, session);
    this.stateToSessionId.set(state, sessionId);

    logger.info("session_created", {
      sessionId: sessionId.slice(0, 8),
      statePrefix: state.slice(0, 8),
      expiresAt,
    });

    return state;
  }

  /**
   * Validate a state parameter and return the associated session if valid.
   * Consumes the state/session to prevent replay attacks.
   */
  validateState(state: string): UserSession | null {
    if (!state || typeof state !== "string") {
      logger.warn("state_validation_failed", { reason: "missing_or_invalid_type" });
      return null;
    }

    const sessionId = this.stateToSessionId.get(state);
    if (!sessionId) {
      logger.warn("state_validation_failed", {
        reason: "unknown_state",
        statePrefix: state.slice(0, 8),
      });
      return null;
    }

    const session = this.sessions.get(sessionId);
    if (!session) {
      logger.warn("state_validation_failed", {
        reason: "session_not_found",
        sessionId: sessionId.slice(0, 8),
      });
      this.stateToSessionId.delete(state);
      return null;
    }

    if (Date.now() > session.expiresAt) {
      logger.warn("state_validation_failed", {
        reason: "expired",
        sessionId: sessionId.slice(0, 8),
      });
      this.stateToSessionId.delete(state);
      this.sessions.delete(sessionId);
      return null;
    }

    // Consume/delete the session to prevent replay attacks
    this.stateToSessionId.delete(state);
    this.sessions.delete(sessionId);

    logger.info("state_validated", {
      sessionId: sessionId.slice(0, 8),
      statePrefix: state.slice(0, 8),
    });

    return session;
  }

  /**
   * Store user information and token in a session.
   */
  storeUserSession(
    state: string,
    userId: string,
    token: string
  ): UserSession | null {
    const sessionId = this.stateToSessionId.get(state);
    if (!sessionId) {
      logger.warn("session_store_failed", {
        reason: "state_not_found",
        statePrefix: state.slice(0, 8),
      });
      return null;
    }

    const session = this.sessions.get(sessionId);
    if (!session) {
      logger.warn("session_store_failed", {
        reason: "session_not_found",
        sessionId: sessionId.slice(0, 8),
      });
      return null;
    }

    if (Date.now() > session.expiresAt) {
      logger.warn("session_store_failed", {
        reason: "session_expired",
        sessionId: sessionId.slice(0, 8),
      });
      this.stateToSessionId.delete(state);
      this.sessions.delete(sessionId);
      return null;
    }

    session.userId = userId;
    session.token = token;

    logger.info("session_user_stored", {
      sessionId: sessionId.slice(0, 8),
      userId,
    });

    return session;
  }

  /**
   * Retrieve a session by state parameter.
   */
  getSession(state: string): UserSession | null {
    const sessionId = this.stateToSessionId.get(state);
    if (!sessionId) {
      return null;
    }

    const session = this.sessions.get(sessionId);
    if (!session) {
      this.stateToSessionId.delete(state);
      return null;
    }

    if (Date.now() > session.expiresAt) {
      this.stateToSessionId.delete(state);
      this.sessions.delete(sessionId);
      return null;
    }

    return session;
  }

  /**
   * Retrieve a session by session ID.
   */
  getSessionById(sessionId: string): UserSession | null {
    const session = this.sessions.get(sessionId);
    if (!session) {
      return null;
    }

    if (Date.now() > session.expiresAt) {
      this.stateToSessionId.delete(session.state);
      this.sessions.delete(sessionId);
      return null;
    }

    return session;
  }

  /**
   * Delete a session (invalidate it).
   */
  deleteSession(state: string): boolean {
    const sessionId = this.stateToSessionId.get(state);
    if (!sessionId) {
      return false;
    }

    this.stateToSessionId.delete(state);
    const deleted = this.sessions.delete(sessionId);

    if (deleted) {
      logger.info("session_deleted", {
        sessionId: sessionId.slice(0, 8),
      });
    }

    return deleted;
  }

  /**
   * Clean up expired sessions.
   */
  private cleanup(): void {
    const now = Date.now();
    let cleaned = 0;

    for (const [sessionId, session] of this.sessions.entries()) {
      if (now > session.expiresAt) {
        this.stateToSessionId.delete(session.state);
        this.sessions.delete(sessionId);
        cleaned++;
      }
    }

    if (cleaned > 0) {
      logger.info("sessions_cleanup", { cleaned, remaining: this.sessions.size });
    }
  }

  /**
   * Start the periodic cleanup interval.
   */
  private startCleanupInterval(): void {
    if (this.cleanupTimer !== null) {
      return;
    }

    this.cleanupTimer = setInterval(() => {
      this.cleanup();
    }, this.cleanupIntervalMs);

    logger.info("session_cleanup_started", {
      intervalMs: this.cleanupIntervalMs,
    });
  }

  /**
   * Stop the cleanup interval (useful for testing).
   */
  stopCleanupInterval(): void {
    if (this.cleanupTimer !== null) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = null;
      logger.info("session_cleanup_stopped");
    }
  }

  /**
   * Get current session count (for monitoring/debugging).
   */
  getSessionCount(): number {
    return this.sessions.size;
  }
}
