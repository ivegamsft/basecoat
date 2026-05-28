---
description: "Next.js and React 19 frontend instruction covering Server Components, App Router, streaming, form actions, and modern patterns"
applyTo: "**/*.tsx,**/*.ts,**/next.config.*"
---

# Next.js and React 19 Instruction

## Overview

Best practices for building Next.js applications with React 19. Server Components are the default paradigm; reach for Client Components only when interactivity is required.

## Key Concepts

**Server Components (default)** — async components that run on the server, never ship JS to the browser, and can directly access databases, APIs, and secrets. Mark with nothing — they are the default.

**Client Components** — components that need interactivity (`useState`, `useEffect`, event handlers). Add `"use client"` directive at the top of the file.

**Server Actions** — async server functions declared with `"use server"`. Use for mutations, form submissions, and operations requiring server-side validation. Call via `<form action={serverAction}>` or `useActionState()`.

**`use()` hook** — pass `Promise` from Server Component to Client Component; Client Component reads it with `use(promise)`.

**App Router** — file-system routing under `app/`. Use `layout.tsx` for shared UI, `page.tsx` for routes, `route.ts` for API endpoints.

## Reference Files

| File | Contents |
|---|---|
| [`references/nextjs/server-components.md`](references/nextjs/server-components.md) | Server Components, `use()` hook, RSC data fetching, cache & revalidation patterns |
| [`references/nextjs/app-router.md`](references/nextjs/app-router.md) | App Router structure, Route Handlers, Server Actions, Streaming/Suspense, React Compiler, Security Headers |

## Quick Rules

- Default to Server Components; add `"use client"` only when required.
- Fetch data in Server Components via `async/await` or ORM — avoid `useEffect` for server data.
- Use `revalidatePath()` / `revalidateTag()` after mutations, not full-page reloads.
- Enable `reactCompiler: true` in `next.config.ts`; drop manual `useMemo`/`useCallback`.
- Wrap slow data fetches in `<Suspense fallback={...}>` for streaming.
- Use `generateMetadata()` for dynamic SEO metadata; `metadata` export for static.
- Set security headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`) in `next.config.ts`.
- CSP must start restrictive (`default-src 'self'`) and widen only with documented justification.
