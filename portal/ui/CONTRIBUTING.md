# Contributing to Basecoat Portal UI

Thank you for contributing to the Basecoat Portal UI component library! This document provides guidelines for adding new components and maintaining quality standards.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Report issues respectfully

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/ivegamsft/basecoat.git`
3. Create a feature branch: `git checkout -b feat/component-name`
4. Install dependencies: `npm install`
5. Make your changes
6. Commit with conventional commits: `git commit -m "feat: add new component"`
7. Push and create a pull request

## Component Development Checklist

When creating a new component, ensure:

### Structure

- [ ] Component file: `src/components/ComponentName/ComponentName.tsx`
- [ ] Styles file: `src/components/ComponentName/ComponentName.module.css`
- [ ] Story file: `src/components/ComponentName/ComponentName.stories.tsx`
- [ ] Test file: `src/components/ComponentName/ComponentName.test.tsx`
- [ ] Index export: Added to `src/components/index.ts`

### TypeScript

- [ ] Interfaces defined for all props
- [ ] Props properly documented with JSDoc comments
- [ ] Return types specified
- [ ] No `any` types (use `unknown` if necessary)

### Accessibility (WCAG 2.1 AA)

- [ ] Semantic HTML elements used
- [ ] ARIA attributes applied correctly
- [ ] Keyboard navigation supported
- [ ] Focus indicators visible
- [ ] Color contrast verified (4.5:1)
- [ ] Screen reader tested
- [ ] No keyboard traps

### Styling

- [ ] Uses CSS modules
- [ ] Uses CSS variables from design tokens
- [ ] Supports dark mode
- [ ] Responsive design implemented
- [ ] Focus styles defined
- [ ] Hover/active states implemented
- [ ] Respects `prefers-reduced-motion`

### Testing

- [ ] >80% code coverage
- [ ] Unit tests for all props
- [ ] Integration tests for interactions
- [ ] Accessibility tests with jest-axe
- [ ] Tests pass: `npm run test`

### Documentation

- [ ] Story file with multiple variants
- [ ] JSDoc comments on component
- [ ] Props documented with examples
- [ ] Accessibility features documented
- [ ] Usage examples in README

### Code Quality

- [ ] Lint passes: `npm run lint`
- [ ] Types check: `npm run type-check`
- [ ] Prettier formatted: `npm run format`
- [ ] No console warnings/errors

## Component Template

Use this template when creating a new component:

```tsx
import React from 'react';
import styles from './ComponentName.module.css';

export interface ComponentNameProps
  extends React.HTMLAttributes<HTMLDivElement> {
  /** Primary prop description */
  variant?: 'primary' | 'secondary';
  /** Loading state */
  isLoading?: boolean;
  /** Component content */
  children: React.ReactNode;
}

/**
 * ComponentName Component
 *
 * Brief description of component purpose.
 *
 * Features:
 * - Feature 1
 * - Feature 2
 * - Feature 3
 *
 * @example
 * <ComponentName variant="primary">
 *   Content
 * </ComponentName>
 *
 * @accessibility
 * - Keyboard navigation support
 * - Screen reader compatible
 * - WCAG 2.1 AA compliant
 */
export const ComponentName = React.forwardRef<
  HTMLDivElement,
  ComponentNameProps
>(({ variant = 'primary', isLoading = false, children, ...props }, ref) => {
  return (
    <div
      ref={ref}
      className={`${styles.container} ${styles[variant]}`}
      role="presentation"
      {...props}
    >
      {children}
    </div>
  );
});

ComponentName.displayName = 'ComponentName';

export default ComponentName;
```

## Styling Guidelines

```css
/* Use CSS module pattern */
.component {
  display: flex;
  align-items: center;
  padding: var(--spacing-4);
  background-color: var(--bg-primary);
  color: var(--text-primary);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  transition: all var(--transition-normal);

  /* Focus state */
  &:focus-visible {
    outline: 2px solid var(--color-primary);
    outline-offset: 2px;
  }

  /* Hover state */
  &:hover:not(:disabled) {
    background-color: var(--bg-secondary);
    border-color: var(--border-color-strong);
  }

  /* High contrast mode */
  @media (prefers-contrast: more) {
    border-width: 2px;
  }

  /* Reduced motion */
  @media (prefers-reduced-motion: reduce) {
    transition: none;
  }

  /* Responsive design */
  @media (max-width: 768px) {
    padding: var(--spacing-3);
  }
}

/* Variants */
.primary {
  background-color: var(--color-primary);
  color: white;
}

.secondary {
  background-color: var(--bg-secondary);
  color: var(--text-primary);
}
```

## Testing Template

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ComponentName } from './ComponentName';

describe('ComponentName', () => {
  it('renders component with content', () => {
    render(<ComponentName>Test content</ComponentName>);
    expect(screen.getByText('Test content')).toBeInTheDocument();
  });

  it('renders variant prop', () => {
    render(<ComponentName variant="secondary">Test</ComponentName>);
    const component = screen.getByText('Test').closest('div');
    expect(component).toHaveClass('secondary');
  });

  it('handles loading state', () => {
    render(<ComponentName isLoading>Test</ComponentName>);
    const component = screen.getByText('Test').closest('div');
    expect(component).toHaveAttribute('aria-busy', 'true');
  });

  it('supports keyboard interaction', async () => {
    const handleClick = vi.fn();
    render(
      <button onClick={handleClick}>
        <ComponentName>Click</ComponentName>
      </button>
    );
    const button = screen.getByRole('button');

    button.focus();
    expect(button).toHaveFocus();

    await userEvent.keyboard('{Enter}');
    expect(handleClick).toHaveBeenCalled();
  });

  it('has accessible ARIA attributes', () => {
    render(<ComponentName>Test</ComponentName>);
    const component = screen.getByText('Test').closest('div');
    expect(component).toHaveAttribute('role', 'presentation');
  });
});
```

## Storybook Story Template

```tsx
import type { Meta, StoryObj } from '@storybook/react';
import { ComponentName } from './ComponentName';

const meta = {
  title: 'Components/ComponentName',
  component: ComponentName,
  parameters: {
    layout: 'centered',
  },
  tags: ['autodocs'],
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary'],
    },
    isLoading: {
      control: 'boolean',
    },
  },
} satisfies Meta<typeof ComponentName>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Primary: Story = {
  args: {
    variant: 'primary',
    children: 'Component content',
  },
};

export const Secondary: Story = {
  args: {
    variant: 'secondary',
    children: 'Component content',
  },
};

export const Loading: Story = {
  args: {
    isLoading: true,
    children: 'Loading...',
  },
};
```

## PR Guidelines

### PR Title Format

Use conventional commits:
- `feat: add new component`
- `fix: resolve accessibility issue`
- `docs: update component documentation`
- `test: add component tests`
- `refactor: improve component structure`
- `chore: update dependencies`

### PR Description

Include:
- What changes were made
- Why changes were needed
- How to test the changes
- Related issues (e.g., "Closes #123")
- Accessibility impact
- Breaking changes (if any)

### Merging Requirements

All PRs must have:
- [ ] All checks passing
- [ ] Tests updated/added
- [ ] Documentation updated
- [ ] Accessibility verified
- [ ] At least one approval

## Development Commands

```bash
# Development server
npm run dev

# Build library
npm run build

# Run tests
npm run test
npm run test:coverage
npm run test:ui

# Linting & formatting
npm run lint
npm run format
npm run type-check
npm run validate

# Storybook
npm run storybook
npm run storybook:build
```

## Resources

- [Component Library README](./README.md)
- [Design System Documentation](./DESIGN_SYSTEM.md)
- [Accessibility Guidelines](./ACCESSIBILITY.md)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [React Documentation](https://react.dev/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)

## Questions?

- Open an issue with the `question` label
- Check existing issues for similar questions
- Comment on relevant PRs/issues

## Recognition

Contributors will be recognized in:
- Git commit history
- CHANGELOG.md
- GitHub contributors list

---

Thank you for making Basecoat Portal UI more accessible and useful for everyone! 🙏
