# @basecoat/portal-ui

A comprehensive, accessible React component library and design system for the Basecoat Portal governance platform.

## Features

- 🎨 **Complete Design System**: Colors, typography, spacing, shadows, and responsive breakpoints
- ♿ **WCAG 2.1 AA Compliant**: Accessibility built-in from the ground up
- 🌙 **Dark Mode Support**: Automatic system preference detection + manual override
- 📱 **Responsive Design**: Mobile-first approach with 4 breakpoints (375px, 768px, 1440px, 1920px+)
- ⌨️ **Keyboard Navigation**: Full keyboard support with focus management
- 🧪 **Well-Tested**: >80% test coverage with vitest and React Testing Library
- 📚 **Storybook Documentation**: Interactive component playground with addon-a11y
- 🎯 **TypeScript First**: Full type definitions for all components and tokens

## Installation

```bash
npm install @basecoat/portal-ui
```

## Quick Start

```tsx
import { ThemeProvider, Button, Input, Card } from '@basecoat/portal-ui';
import '@basecoat/portal-ui/dist/styles/global.css';

function App() {
  return (
    <ThemeProvider>
      <Card>
        <Card.Header>Welcome</Card.Header>
        <Card.Body>
          <Input label="Email" type="email" placeholder="user@example.com" />
          <Button variant="primary">Submit</Button>
        </Card.Body>
      </Card>
    </ThemeProvider>
  );
}

export default App;
```

## Components

### Core Components

#### Button
Flexible button component with multiple variants and sizes.

```tsx
<Button variant="primary" size="md">Click me</Button>
<Button variant="secondary" disabled>Disabled</Button>
<Button variant="danger" isLoading>Processing...</Button>
```

**Props:**
- `variant`: 'primary' | 'secondary' | 'danger'
- `size`: 'sm' | 'md' | 'lg'
- `isLoading`: boolean
- `isDisabled`: boolean
- `fullWidth`: boolean
- `icon`: ReactNode

#### Input
Accessible form input with validation states and helper text.

```tsx
<Input label="Username" placeholder="Enter username" />
<Input
  label="Email"
  type="email"
  isRequired
  helperText="We'll never share your email"
/>
<Input
  label="Password"
  type="password"
  isInvalid
  errorMessage="Password must be 8+ characters"
/>
```

**Props:**
- `type`: 'text' | 'email' | 'password' | 'number' | 'search'
- `label`: string
- `helperText`: string
- `errorMessage`: string
- `isRequired`: boolean
- `isInvalid`: boolean

#### Card
Flexible card container with optional header, body, and footer.

```tsx
<Card elevation="medium">
  <Card.Header>Title</Card.Header>
  <Card.Body>Content goes here</Card.Body>
  <Card.Footer>Footer info</Card.Footer>
</Card>
```

**Props:**
- `elevation`: 'none' | 'subtle' | 'medium' | 'large'
- `interactive`: boolean
- `header`: ReactNode
- `footer`: ReactNode

#### Navigation
Accessible navigation with keyboard support.

```tsx
<Navigation
  variant="header"
  links={[
    { label: 'Dashboard', href: '/dashboard', isActive: true },
    { label: 'Settings', href: '/settings' },
    { label: 'Logout', href: '/logout' },
  ]}
/>
```

**Props:**
- `links`: NavLink[]
- `variant`: 'header' | 'sidebar'
- `onLinkClick`: (link: NavLink) => void
- `isMobileMenuOpen`: boolean

#### Modal
Accessible modal dialog with focus management.

```tsx
<Modal
  isOpen={isOpen}
  onClose={() => setIsOpen(false)}
  title="Confirm Delete"
  size="md"
>
  Are you sure you want to delete this item?
  <Modal.Footer>
    <Button variant="secondary" onClick={() => setIsOpen(false)}>
      Cancel
    </Button>
    <Button variant="danger">Delete</Button>
  </Modal.Footer>
</Modal>
```

**Props:**
- `isOpen`: boolean
- `onClose`: () => void
- `title`: string
- `description`: string
- `size`: 'sm' | 'md' | 'lg'
- `isDismissible`: boolean

## Design Tokens

Access design tokens for consistent styling:

```tsx
import { tokens } from '@basecoat/portal-ui';

const {
  colors,
  colorsByTheme,
  typography,
  spacing,
  borderRadius,
  shadows,
  breakpoints,
  mediaQueries,
  transitions,
  zIndex,
} = tokens;
```

## Dark Mode

### Automatic Detection

Dark mode automatically detects system preference via `prefers-color-scheme`.

### Manual Override

```tsx
import { useTheme } from '@basecoat/portal-ui';

function ThemeToggle() {
  const { isDarkMode, setTheme } = useTheme();

  return (
    <button onClick={() => setTheme(isDarkMode ? 'light' : 'dark')}>
      {isDarkMode ? '☀️ Light' : '🌙 Dark'}
    </button>
  );
}
```

User preference is stored in localStorage and persists across sessions.

## Accessibility

All components are designed with accessibility as a first principle:

### Keyboard Navigation

- Tab/Shift+Tab: Navigate between focusable elements
- Enter/Space: Activate buttons, submit forms
- Arrow keys: Navigate menu items
- Escape: Close modals and dropdowns

### Screen Reader Support

- Semantic HTML structure
- Proper ARIA attributes and labels
- Form labels associated with inputs
- Error messages linked with aria-describedby
- Active states marked with aria-current

### Color & Contrast

- All colors meet WCAG AA contrast requirements (4.5:1 for normal text)
- No information conveyed by color alone
- Focus indicators clearly visible (2px outline)

### Motion & Animation

- Respects `prefers-reduced-motion` media query
- Disabled animations for users who prefer reduced motion
- Smooth transitions for visual feedback

## Responsive Design

The component library uses a mobile-first approach with 4 breakpoints:

```tsx
// CSS Variables
--mobile: 375px;
--tablet: 768px;
--desktop: 1440px;
--large: 1920px;
```

All components automatically adjust for different screen sizes.

## Testing

### Run Tests

```bash
npm run test
```

### Coverage Report

```bash
npm run test:coverage
```

### UI Mode

```bash
npm run test:ui
```

Test coverage targets:
- Lines: 80%
- Functions: 80%
- Branches: 75%
- Statements: 80%

## Storybook

Interactive component documentation:

```bash
npm run storybook
```

Storybook includes:
- Interactive component explorer
- Accessibility (a11y) addon
- Live prop controls (Knobs)
- Design token documentation

## Development

### Setup

```bash
npm install
```

### Build

```bash
npm run build
```

### Dev Server

```bash
npm run dev
```

### Linting

```bash
npm run lint
npm run format
npm run type-check
```

### Validation

```bash
npm run validate
```

## Project Structure

```
portal-ui/
├── src/
│   ├── components/        # Core components
│   │   ├── Button/
│   │   ├── Input/
│   │   ├── Card/
│   │   ├── Navigation/
│   │   ├── Modal/
│   │   └── index.ts
│   ├── theme/             # Design tokens & theming
│   │   ├── tokens.ts
│   │   ├── ThemeContext.tsx
│   │   └── index.ts
│   ├── styles/            # Global styles
│   │   └── global.css
│   ├── types/             # TypeScript definitions
│   ├── utils/             # Utility functions
│   ├── hooks/             # Custom hooks
│   ├── index.ts           # Library entry point
│   └── setupTests.ts      # Test configuration
├── stories/               # Storybook stories
├── tests/                 # Integration tests
├── .storybook/            # Storybook configuration
├── .eslintrc.json         # ESLint config
├── .prettierrc.json       # Prettier config
├── tsconfig.json          # TypeScript config
├── vite.config.ts         # Vite build config
├── vitest.config.ts       # Test config
└── package.json
```

## Browser Support

- Chrome/Edge: Latest 2 versions
- Firefox: Latest 2 versions
- Safari: Latest 2 versions
- Mobile browsers: iOS Safari 12+, Chrome for Android latest

## License

MIT

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Support

For issues and questions, visit: [GitHub Issues](https://github.com/ivegamsft/basecoat/issues)

---

**Built with ♿ accessibility first for the Basecoat governance platform**
