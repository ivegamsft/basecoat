# Basecoat Portal Frontend Implementation Guide

## Executive Summary

This document provides a complete roadmap for implementing the Basecoat Portal frontend UI/UX. It includes technology recommendations, project structure, development workflows, quality assurance procedures, and deployment strategies. The design is ready for full-stack implementation targeting May 5 delivery.

---

## Technology Stack

### Frontend Framework
- **React 18+** with TypeScript
  - Hooks for state management
  - Context API for theme/auth state
  - React Router v6+ for navigation
  - Components: Functional components with React.memo for optimization

### Styling
- **Tailwind CSS 3+** with custom configuration
  - FluentUI color palette exported as Tailwind config
  - Responsive utilities (mobile-first: sm, md, lg, xl breakpoints)
  - Custom plugins for accessibility (focus rings, reduced motion)

### Component Library
- **Headless UI** + custom accessible components
  - Form controls: Input, Select, Checkbox, Radio, Textarea
  - Modals, Dropdowns, Popovers
  - Data: Tables with sorting/pagination
  - Notifications: Toast system with auto-dismiss

### State Management
- **React Query** (TanStack Query) for server state
  - API endpoint synchronization
  - Automatic caching, refetching, invalidation
  - Error handling and retry logic

- **Zustand** for client state
  - Auth state (user, token, MFA status)
  - UI state (sidebar collapsed, theme)
  - Lightweight alternative to Redux

### HTTP Client
- **Axios** with interceptors
  - JWT token injection via Authorization header
  - Request/response logging
  - Automatic retry on 5xx (except 501/503)
  - Timeout handling (30s default)

### Build & Bundling
- **Vite 4+** for development/production builds
  - Hot Module Replacement (HMR) for fast iteration
  - Tree-shaking for bundle optimization
  - Environment variable management (.env, .env.production)

### Testing
- **Vitest** + **React Testing Library**
  - Unit tests for components
  - Integration tests for user flows
  - Snapshot testing for accessibility
  - Mocking: MSW (Mock Service Worker) for API mocks

- **Storybook 7+** for component documentation
  - Accessibility checks (axe, color contrast)
  - Visual regression (Chromatic)
  - Component showcase and prop documentation

### Accessibility
- **axe-core** for automated accessibility testing
- **jest-axe** for unit test integration
- **WAVE** browser extension for manual audits
- **NVDA/JAWS** screen reader testing (manual)

### Monitoring & Analytics
- **Sentry** for error tracking
- **LogRocket** for session replay and debugging
- **PostHog** for feature usage analytics

---

## Project Structure

```
basecoat-portal/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # Lint, test, build
│   │   ├── accessibility-audit.yml   # Weekly a11y checks
│   │   └── deploy.yml                # Production deployment
│   └── PULL_REQUEST_TEMPLATE.md
├── public/
│   ├── favicon.ico
│   ├── logo.png
│   └── manifest.json
├── src/
│   ├── components/
│   │   ├── common/                   # Reusable UI components
│   │   │   ├── Button/
│   │   │   ├── Input/
│   │   │   ├── Card/
│   │   │   ├── Modal/
│   │   │   ├── Toast/
│   │   │   ├── Badge/
│   │   │   ├── Table/
│   │   │   └── Navigation/
│   │   ├── auth/                     # Auth-specific components
│   │   │   ├── LoginForm/
│   │   │   ├── MFASetup/
│   │   │   ├── PasswordReset/
│   │   │   └── ProtectedRoute/
│   │   ├── dashboard/                # Dashboard screens
│   │   │   ├── DashboardLayout/
│   │   │   ├── MetricCard/
│   │   │   ├── RecentAuditsTable/
│   │   │   └── QuickActionsPanel/
│   │   ├── audit/                    # Audit screens
│   │   │   ├── AuditSubmitForm/
│   │   │   ├── AuditDetails/
│   │   │   ├── AuditList/
│   │   │   └── FindingsList/
│   │   ├── compliance/               # Compliance screens
│   │   │   ├── ComplianceStatus/
│   │   │   ├── FrameworkCard/
│   │   │   └── ComplianceTrend/
│   │   ├── repository/               # Repository management
│   │   │   ├── RepositoryList/
│   │   │   ├── RepositoryDetails/
│   │   │   ├── RepositoryForm/
│   │   │   └── SyncStatus/
│   │   ├── reports/                  # Reporting screens
│   │   │   ├── ReportBuilder/
│   │   │   ├── ReportPreview/
│   │   │   └── ExportOptions/
│   │   └── shared/                   # Layout shells
│   │       ├── MainLayout/
│   │       ├── SidebarNav/
│   │       ├── TopNavBar/
│   │       └── FooterBar/
│   ├── pages/                        # Page-level route components
│   │   ├── LoginPage.tsx
│   │   ├── DashboardPage.tsx
│   │   ├── AuditPage.tsx
│   │   ├── CompliancePage.tsx
│   │   ├── RepositoryPage.tsx
│   │   ├── ReportsPage.tsx
│   │   ├── SettingsPage.tsx
│   │   └── NotFoundPage.tsx
│   ├── hooks/                        # Custom React hooks
│   │   ├── useAuth.ts
│   │   ├── useAudits.ts
│   │   ├── useRepositories.ts
│   │   ├── useMFA.ts
│   │   ├── useNotification.ts
│   │   └── useWindowSize.ts
│   ├── services/                     # API service layer
│   │   ├── authService.ts
│   │   ├── auditService.ts
│   │   ├── complianceService.ts
│   │   ├── repositoryService.ts
│   │   ├── reportService.ts
│   │   ├── axios.ts                  # Axios instance + interceptors
│   │   └── types.ts                  # Shared API response types
│   ├── store/                        # Zustand state stores
│   │   ├── authStore.ts
│   │   ├── uiStore.ts
│   │   └── notificationStore.ts
│   ├── utils/                        # Helper functions
│   │   ├── validation.ts             # Form validation rules
│   │   ├── formatting.ts             # Date, number formatting
│   │   ├── errorHandler.ts           # Error mapping
│   │   ├── constants.ts              # App-wide constants
│   │   ├── localStorage.ts           # Persistent storage helpers
│   │   └── a11y.ts                   # Accessibility utilities
│   ├── styles/                       # Global styles
│   │   ├── globals.css               # Tailwind imports + overrides
│   │   ├── animations.css            # Custom animations
│   │   └── colors.css                # CSS custom properties (FluentUI)
│   ├── mocks/                        # Test utilities
│   │   ├── handlers.ts               # MSW request handlers
│   │   ├── db.ts                     # Mock database
│   │   └── fixtures.ts               # Test data
│   ├── App.tsx                       # Root component
│   ├── App.test.tsx
│   ├── main.tsx                      # Entry point
│   └── env.d.ts                      # Type definitions
├── tests/
│   ├── e2e/                          # End-to-end tests (Playwright)
│   │   ├── auth.spec.ts
│   │   ├── dashboard.spec.ts
│   │   ├── audit-submission.spec.ts
│   │   └── compliance.spec.ts
│   └── accessibility/
│       ├── color-contrast.test.ts
│       ├── keyboard-navigation.test.ts
│       └── screen-reader.test.ts
├── .storybook/
│   ├── main.ts
│   ├── preview.ts
│   └── preview-head.html
├── stories/
│   ├── Button.stories.tsx
│   ├── Form.stories.tsx
│   ├── Table.stories.tsx
│   ├── Modal.stories.tsx
│   └── Dashboard.stories.tsx
├── .env.example                      # Template for environment variables
├── .env.local                        # Local dev overrides (gitignored)
├── .env.production                   # Production environment
├── tailwind.config.js                # Tailwind config with FluentUI colors
├── vite.config.ts
├── vitest.config.ts
├── tsconfig.json
├── package.json
├── pnpm-lock.yaml
└── README.md
```

---

## Development Workflow

### Initial Setup
```bash
# Clone repository
git clone https://github.com/IBuySpy-Shared/basecoat-portal.git
cd basecoat-portal

# Install dependencies
pnpm install

# Create local environment file
cp .env.example .env.local

# Start development server
pnpm dev
# Available at http://localhost:5173

# In another terminal, start Storybook
pnpm storybook
# Available at http://localhost:6006
```

### Component Development

1. **Create Component Structure**
   ```
   src/components/common/Button/
   ├── Button.tsx           # Component implementation
   ├── Button.test.tsx      # Unit tests
   ├── Button.stories.tsx   # Storybook documentation
   ├── Button.types.ts      # TypeScript interfaces
   └── index.ts             # Barrel export
   ```

2. **Implement Accessibility**
   ```tsx
   export const Button = React.forwardRef<
     HTMLButtonElement,
     ButtonProps & AriaAttributes
   >(({ variant, disabled, children, ...props }, ref) => (
     <button
       ref={ref}
       disabled={disabled}
       aria-busy={props.loading}
       aria-label={props['aria-label']}
       className={classNames(buttonClasses[variant])}
       {...props}
     >
       {children}
     </button>
   ));
   ```

3. **Test Coverage**
   - Unit tests: Props, state changes, event handlers
   - Accessibility: axe-core checks, keyboard navigation
   - Visual: Storybook snapshots

4. **Storybook Documentation**
   ```tsx
   export default {
     title: 'Components/Button',
     component: Button,
     argTypes: {
       variant: { control: 'select', options: ['primary', 'secondary', ...] },
     },
   };
   
   export const Primary = {
     args: { variant: 'primary', children: 'Click me' },
   };
   ```

### API Integration Pattern

1. **Define Service**
   ```typescript
   // services/auditService.ts
   export const getAudits = async (filters?: AuditFilter) => {
     const response = await axios.get('/api/audits', { params: filters });
     return response.data;
   };
   ```

2. **Create Hook**
   ```typescript
   // hooks/useAudits.ts
   export const useAudits = (filters?: AuditFilter) => {
     return useQuery({
       queryKey: ['audits', filters],
       queryFn: () => getAudits(filters),
       staleTime: 5 * 60 * 1000, // 5 minutes
     });
   };
   ```

3. **Use in Component**
   ```tsx
   const AuditList = () => {
     const { data: audits, isLoading, error } = useAudits();
     
     if (isLoading) return <Skeleton />;
     if (error) return <ErrorBoundary error={error} />;
     
     return <Table data={audits} />;
   };
   ```

### Branch Strategy
```bash
# Feature branch naming
git checkout -b feature/dashboard-widgets
git checkout -b fix/login-button-alignment
git checkout -b docs/component-library

# Push and create PR
git push origin feature/dashboard-widgets
```

### PR Checklist
- [ ] Tests written and passing
- [ ] Accessibility audit passed (axe-core)
- [ ] Storybook stories created
- [ ] TypeScript strict mode (no `any`)
- [ ] Code formatted (Prettier)
- [ ] CHANGELOG.md updated
- [ ] Screenshots/GIFs for UI changes

---

## Quality Assurance

### Automated Testing

#### Unit & Integration Tests
```bash
pnpm test                    # Run all tests
pnpm test:watch             # Watch mode
pnpm test:coverage          # Coverage report
```

Requirements:
- Minimum 80% line coverage
- 100% coverage for critical paths (auth, compliance)
- All components tested for accessibility

#### Accessibility Audit
```bash
pnpm test:a11y              # Run axe-core checks
pnpm test:contrast          # Color contrast verification
```

Checks:
- WCAG 2.1 AA compliance
- Keyboard navigation (Tab, Enter, Esc, Arrow keys)
- Screen reader compatibility
- Color contrast ratios (4.5:1 for text)

#### E2E Testing
```bash
pnpm test:e2e               # Playwright tests
```

Coverage:
- Happy path: Login → Dashboard → Submit Audit → View Results
- Error scenarios: Invalid login, network timeout, form validation
- Responsive: Mobile, tablet, desktop viewports

### Manual Testing Checklist

#### Cross-Browser
- Chrome/Edge (latest)
- Firefox (latest)
- Safari 14+
- Mobile: iOS Safari, Chrome Android

#### Screen Readers
- Windows: NVDA (free), JAWS (enterprise)
- macOS: VoiceOver
- Testing path: Tab through all interactive elements, verify announcements

#### Keyboard Navigation
```
Tab          → Next interactive element
Shift+Tab    → Previous element
Enter        → Activate button/link
Space        → Toggle checkbox/switch
Esc          → Close modal
Arrow keys   → Navigate within menus/tables
```

#### Breakpoint Testing
```
Mobile:  375px width, touch input
Tablet:  768px width, mixed touch/pointer
Desktop: 1440px width, pointer input
```

### Performance Metrics

#### Target Performance
- Largest Contentful Paint (LCP): < 2.5s
- First Input Delay (FID): < 100ms
- Cumulative Layout Shift (CLS): < 0.1
- Time to Interactive (TTI): < 3.5s

#### Monitoring
```bash
pnpm build                   # Production build analysis
# Check bundle size: dist/ folder

# Lighthouse audit
pnpm lighthouse:mobile
pnpm lighthouse:desktop
```

---

## Deployment Strategy

### Environments

#### Development
- **URL**: http://localhost:5173
- **API Backend**: http://localhost:3000
- **Database**: Local/Docker
- **Auth**: GitHub OAuth (dev app)

#### Staging
- **URL**: https://staging.basecoat-portal.dev
- **API Backend**: https://staging-api.basecoat-portal.dev
- **Database**: Staging DB (read-only copy)
- **Auth**: GitHub OAuth (staging app)

#### Production
- **URL**: https://portal.basecoat.dev
- **API Backend**: https://api.basecoat.dev
- **Database**: Production DB (backups, encryption)
- **Auth**: GitHub OAuth (production app, enterprise SSO fallback)

### CI/CD Pipeline

#### GitHub Actions Workflow: `.github/workflows/ci.yml`
```yaml
name: CI

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v3
        with: { node-version: '18', cache: 'pnpm' }
      - run: pnpm lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v3
        with: { node-version: '18', cache: 'pnpm' }
      - run: pnpm test:unit
      - run: pnpm test:a11y
      - uses: codecov/codecov-action@v3
        with: { files: ./coverage/coverage-final.json }

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v3
        with: { node-version: '18', cache: 'pnpm' }
      - run: pnpm build
      - uses: actions/upload-artifact@v3
        with:
          name: dist
          path: dist/
```

#### Deploy to Staging (on PR merge to `develop`)
```bash
pnpm build
# Push dist/ to staging hosting (Vercel, Azure Static Web Apps, etc.)
```

#### Deploy to Production (on release tag)
```bash
# Tag: v1.0.0
pnpm build
# Push dist/ to production hosting
# Verify Sentry/monitoring connected
# Post-deploy smoke tests
```

### Hosting Recommendations

#### Static Hosting (Recommended)
- **Vercel** (seamless GitHub integration, analytics, edge functions)
- **Netlify** (similar, with form functions)
- **Azure Static Web Apps** (enterprise, Microsoft integration)
- **AWS S3 + CloudFront** (enterprise, complex setup)

#### Configuration
- Redirect `/` to `/index.html` (SPA)
- Set cache headers: 1 hour for HTML, 1 year for /dist/assets
- Compress assets (gzip, brotli)
- Enable HSTS, CSP headers

---

## Environment Configuration

### `.env.example`
```env
# API
VITE_API_BASE_URL=http://localhost:3000/api
VITE_API_TIMEOUT_MS=30000

# Auth
VITE_GITHUB_CLIENT_ID=your_client_id_here
VITE_GITHUB_REDIRECT_URI=http://localhost:5173/auth/callback

# Monitoring
VITE_SENTRY_DSN=https://...@sentry.io/...
VITE_SENTRY_ENVIRONMENT=development

# Feature Flags
VITE_ENABLE_DARK_MODE=false
VITE_ENABLE_BETA_FEATURES=false
```

### Production Secrets (GitHub Actions)
```yaml
env:
  VITE_API_BASE_URL: ${{ secrets.PROD_API_BASE_URL }}
  VITE_SENTRY_DSN: ${{ secrets.PROD_SENTRY_DSN }}
```

---

## Key Implementation Priorities

### Phase 1: MVP (Week 1-2)
- [x] Design system complete (colors, typography, spacing)
- [x] Component library documented
- [ ] Auth screens (login, MFA, password reset)
- [ ] Dashboard layout and navigation
- [ ] API integration setup (Axios, React Query)

### Phase 2: Core Features (Week 3-4)
- [ ] Dashboard complete (metrics, recent audits)
- [ ] Audit submission form (multi-step)
- [ ] Repository management (list, details)
- [ ] Compliance status screen

### Phase 3: Polish (Week 5)
- [ ] Responsive variants (mobile, tablet tested)
- [ ] Error states and empty states
- [ ] Dark mode (optional)
- [ ] Performance optimization
- [ ] E2E tests, accessibility audit

### Phase 4: Launch (May 5)
- [ ] Production deployment
- [ ] Documentation handoff
- [ ] User training materials
- [ ] Monitoring/alerting setup

---

## Handoff Checklist

### To Backend Team
- [ ] API contract documentation (OpenAPI/Swagger)
- [ ] Request/response examples for each endpoint
- [ ] Error code mapping
- [ ] Rate limiting and quota documentation

### To DevOps Team
- [ ] Deployment playbook (staging/production)
- [ ] Environment configuration
- [ ] DNS and SSL setup
- [ ] Monitoring and alerting rules

### To Product Team
- [ ] Feature flag documentation
- [ ] Analytics events tracked
- [ ] User journey tracking (Amplitude, PostHog)
- [ ] Release notes template

### To QA Team
- [ ] Test case matrix (features × browsers × devices)
- [ ] Performance benchmarks
- [ ] Accessibility test plan (WCAG 2.1 AA)
- [ ] Regression test automation scripts

---

## References

- [React 18 Docs](https://react.dev)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [React Query](https://tanstack.com/query)
- [Storybook](https://storybook.js.org/docs)
- [Playwright Testing](https://playwright.dev/docs/intro)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Web Vitals](https://web.dev/vitals/)

---

## Document Version

**Frontend Implementation Guide v1.0**  
**Last Updated**: May 2024  
**Status**: Ready for Development  
**Owner**: Frontend-Dev Agent, Basecoat Team

