import { NextFunction, Request, RequestHandler, Response } from "express";

type Bucket = {
  count: number;
  windowStartMs: number;
};

export type RateLimitOptions = {
  maxRequests: number;
  windowMs: number;
};

const DEFAULT_MAX_REQUESTS = 10;
const DEFAULT_WINDOW_MS = 60_000;

function getRequestKey(request: Request): string {
  const userId = request.header("x-github-user-id");
  if (userId) {
    return `gh-user:${userId}`;
  }

  const forwardedFor = request.header("x-forwarded-for")?.split(",")[0]?.trim();
  if (forwardedFor) {
    return `ip:${forwardedFor}`;
  }

  return `ip:${request.ip ?? "unknown"}`;
}

export function resolveRateLimitOptionsFromEnv(): RateLimitOptions {
  const parsedMaxRequests = Number.parseInt(
    process.env.RATE_LIMIT_MAX_REQUESTS ?? `${DEFAULT_MAX_REQUESTS}`,
    10,
  );
  const parsedWindowMs = Number.parseInt(
    process.env.RATE_LIMIT_WINDOW_MS ?? `${DEFAULT_WINDOW_MS}`,
    10,
  );

  return {
    maxRequests:
      Number.isFinite(parsedMaxRequests) && parsedMaxRequests > 0
        ? parsedMaxRequests
        : DEFAULT_MAX_REQUESTS,
    windowMs:
      Number.isFinite(parsedWindowMs) && parsedWindowMs > 0 ? parsedWindowMs : DEFAULT_WINDOW_MS,
  };
}

export function createRateLimiter(options: RateLimitOptions): RequestHandler {
  const buckets = new Map<string, Bucket>();

  return (request: Request, response: Response, next: NextFunction) => {
    const key = getRequestKey(request);
    const now = Date.now();
    const existing = buckets.get(key);

    if (!existing || now - existing.windowStartMs >= options.windowMs) {
      buckets.set(key, {
        count: 1,
        windowStartMs: now,
      });
      response.setHeader("x-ratelimit-limit", `${options.maxRequests}`);
      response.setHeader("x-ratelimit-remaining", `${options.maxRequests - 1}`);
      response.setHeader("x-ratelimit-reset", `${now + options.windowMs}`);
      next();
      return;
    }

    existing.count += 1;
    const remaining = Math.max(0, options.maxRequests - existing.count);
    response.setHeader("x-ratelimit-limit", `${options.maxRequests}`);
    response.setHeader("x-ratelimit-remaining", `${remaining}`);
    response.setHeader("x-ratelimit-reset", `${existing.windowStartMs + options.windowMs}`);

    if (existing.count > options.maxRequests) {
      response.status(429).json({
        error: "Too Many Requests",
        detail: "Rate limit exceeded for this user.",
        limit: options.maxRequests,
        windowMs: options.windowMs,
      });
      return;
    }

    next();
  };
}

