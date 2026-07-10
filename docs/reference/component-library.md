# Basecoat Portal Component Library

## Overview

This document specifies all reusable UI components for the Basecoat Portal. All components follow the design system and are accessible (WCAG 2.1 AA).

---

## Button Component

### Props
```typescript
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'danger' | 'ghost';
  size: 'small' | 'medium' | 'large';
  disabled?: boolean;
  onClick?: () => void;
  loading?: boolean;
  icon?: ReactNode;
  children: ReactNode;
}
```

### Variants

#### Primary Button
- **Use Case**: Main actions (Submit, Sign In, Save)
- **Background**: #0078D4
- **Text**: White, 14px semibold
- **Padding**: 12px 24px
- **Min Height**: 48px (touch target)
- **Hover**: #106EBE
- **Active**: #005A9E
- **Disabled**: #EBEBEB, text #999999

#### Secondary Button
- **Use Case**: Alternative actions (Cancel, Skip)
- **Background**: Transparent
- **Border**: 1px #0078D4
- **Text**: #0078D4, 14px semibold
- **Hover**: Background #F3F2F1

#### Danger Button
- **Use Case**: Destructive actions (Delete, Revoke)
- **Background**: #D13438
- **Text**: White
- **Hover**: #A51F23

#### Ghost Button
- **Use Case**: Low-priority actions
- **Background**: Transparent
- **Border**: None
- **Text**: #0078D4
- **Hover**: Background #F3F2F1

### Examples
```jsx
<Button variant="primary" size="large">Submit Audit</Button>
<Button variant="secondary">Cancel</Button>
<Button variant="danger" disabled>Delete (requires confirmation)</Button>
```

---

## Input Component

### Props
```typescript
interface InputProps {
  type: 'text' | 'email' | 'password' | 'number';
  placeholder?: string;
  value: string;
  onChange: (value: string) => void;
  error?: string;
  disabled?: boolean;
  label?: string;
  required?: boolean;
  maxLength?: number;
}
```

### Specification
- **Height**: 36px
- **Padding**: 8px 12px
- **Border**: 1px #EBEBEB
- **Border Radius**: 4px
- **Font**: 14px, Segoe UI
- **Focus**: Border #0078D4 (2px), Shadow 0 0 0 4px rgba(0, 120, 212, 0.1)
- **Error**: Border #D13438, helper text in red (12px)
- **Disabled**: Background #EBEBEB, cursor not-allowed

### Error Handling
```jsx
<Input 
  label="Email" 
  type="email" 
  error="Invalid email format"
  required 
/>
```

---

## Select Component

### Props
```typescript
interface SelectProps {
  options: Array<{ label: string; value: string }>;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
  label?: string;
  error?: string;
}
```

### Specification
- **Height**: 36px
- **Padding**: 8px 12px
- **Border**: 1px #EBEBEB
- **Arrow Icon**: Right-aligned, 16px
- **Option Hover**: Background #F3F2F1
- **Focus**: Border #0078D4

---

## Checkbox Component

### Props
```typescript
interface CheckboxProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: string;
  disabled?: boolean;
}
```

### Specification
- **Size**: 18px × 18px
- **Border Radius**: 2px
- **Border**: 1px #323232
- **Checked**: Background #0078D4, white checkmark (SVG)
- **Label**: 14px, left of checkbox
- **Min Tap Target**: 44px (including label)

---

## Radio Button Component

### Props
```typescript
interface RadioProps {
  checked: boolean;
  onChange: () => void;
  label: string;
  name: string;
  value: string;
}
```

### Specification
- **Size**: 18px diameter
- **Border**: 2px #323232
- **Checked**: Center dot (#0078D4, 6px diameter)
- **Label**: 14px

---

## Card Component

### Props
```typescript
interface CardProps {
  title?: string;
  children: ReactNode;
  footer?: ReactNode;
  hoverable?: boolean;
  onClick?: () => void;
}
```

### Specification
- **Background**: #FFFFFF
- **Border**: 1px #EBEBEB
- **Border Radius**: 8px
- **Padding**: 24px
- **Shadow**: 0px 1px 4px rgba(0, 0, 0, 0.08)
- **Hover** (if hoverable): Shadow 0px 4px 12px rgba(0, 0, 0, 0.12)
- **Cursor** (if clickable): pointer

---

## Modal Component

### Props
```typescript
interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  size?: 'small' | 'medium' | 'large';
}
```

### Specification
- **Width**: 90vw max (small: 400px, medium: 600px, large: 800px)
- **Mobile**: Full width, minus 16px padding
- **Padding**: 32px
- **Border Radius**: 8px
- **Overlay**: Black, 30% opacity
- **Close Button**: Top right, icon button
- **Keyboard**: Esc to close
- **Focus**: Trap focus inside modal

---

## Toast/Notification Component

### Props
```typescript
interface ToastProps {
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message?: string;
  autoClose?: number; // ms
  action?: { label: string; onClick: () => void };
}
```

### Position
- **Desktop**: Bottom right, 16px from edges
- **Mobile**: Bottom center, above any nav

### Specification

| Type | Background | Icon | Border Left |
|------|-----------|------|------------|
| Success | #DFF6DD | ✓ | 4px #107C10 |
| Error | #FDE7E9 | ✗ | 4px #D13438 |
| Warning | #FFF4CE | ⚠ | 4px #F7630C |
| Info | #CFE4FA | ℹ | 4px #0078D4 |

### Timing
- **Auto-dismiss**: 5 seconds (customizable)
- **Manual close**: X button

---

## Data Table Component

### Props
```typescript
interface TableProps {
  columns: Array<{
    key: string;
    label: string;
    sortable?: boolean;
    width?: string;
  }>;
  data: Array<Record<string, any>>;
  onRowClick?: (row: any) => void;
  selectable?: boolean;
  pagination?: { pageSize: number; totalCount: number };
}
```

### Specification

#### Header
- **Background**: #F3F2F1
- **Text**: 14px semibold (#323232)
- **Padding**: 16px
- **Sortable**: Chevron icon on hover

#### Rows
- **Height**: 56px
- **Padding**: 12px 16px
- **Border Bottom**: 1px #EBEBEB
- **Hover**: Background #F3F2F1
- **Alternate**: Optional striped layout

#### Pagination
- **Items per page**: Dropdown (default 25)
- **Page input**: Inline edit
- **Controls**: Previous, Next, First, Last

---

## Navigation Components

### Sidebar Navigation
- **Width**: 280px (desktop), 64px (collapsed)
- **Background**: #FFFFFF
- **Border Right**: 1px #EBEBEB
- **Item Height**: 44px
- **Padding**: 16px (left)
- **Active**: Left border #0078D4 (4px), background #F3F2F1
- **Icon**: 20px, left-aligned

### Top Navigation
- **Height**: 64px
- **Background**: #FFFFFF
- **Border Bottom**: 1px #EBEBEB
- **Padding**: 16px 24px
- **Items**: Logo (left), Search (center), User menu (right)

### Breadcrumb
- **Font**: 12px gray
- **Separator**: /
- **Active**: Bold blue
- **Clickable**: Underline on hover

---

## Badge Component

### Props
```typescript
interface BadgeProps {
  variant: 'default' | 'success' | 'warning' | 'error' | 'pending';
  children: ReactNode;
}
```

### Specification
- **Padding**: 4px 8px
- **Font**: 12px bold
- **Border Radius**: 12px

### Variants
- **Default**: Gray (#EBEBEB) background, #323232 text
- **Success**: Green background (#DFF6DD), green text (#107C10)
- **Warning**: Orange background (#FFF4CE), orange text (#F7630C)
- **Error**: Red background (#FDE7E9), red text (#D13438)
- **Pending**: Gray background (#DEE2E6), gray text (#666666)

---

## Status Indicator Component

### Props
```typescript
interface StatusProps {
  status: 'compliant' | 'at-risk' | 'non-compliant' | 'pending' | 'scanning';
  showLabel?: boolean;
}
```

### Display
```
✓ Compliant → Green (#107C10)
⚠ At-Risk → Orange (#F7630C)
✗ Non-Compliant → Red (#D13438)
⏳ Pending → Gray (#665E00)
🔄 Scanning → Spinner blue (#0078D4)
```

---

## Metric Card Component

### Props
```typescript
interface MetricCardProps {
  title: string;
  value: string | number;
  unit?: string;
  icon?: ReactNode;
  trend?: { direction: 'up' | 'down'; value: number };
  color?: 'green' | 'orange' | 'red' | 'blue';
}
```

### Specification
- **Title**: h4, 16px
- **Value**: 32px bold, color-coded
- **Unit**: 12px secondary text
- **Icon**: Top right, 24px
- **Trend**: Small text, up/down arrow

---

## Form Group Component

### Props
```typescript
interface FormGroupProps {
  label: string;
  required?: boolean;
  error?: string;
  children: ReactNode;
  helperText?: string;
}
```

### Specification
- **Label**: 14px semibold (#000000)
- **Required**: Asterisk (*) in red
- **Error**: 12px red text, icon
- **Helper Text**: 12px gray, italic
- **Spacing**: 8px between label and input

---

## Responsive Behavior

All components adapt to three breakpoints:

### Mobile (375px)
- Full-width buttons
- Single-column layouts
- Bottom sheet modals
- Touch targets: min 48px × 48px
- Font sizes: +2px for readability

### Tablet (768px)
- Two-column grids
- Drawer sidebars
- Horizontal scroll tables
- Optimized padding

### Desktop (1440px)
- Three-column layouts
- Fixed sidebars
- Full-width tables with pagination
- Normal spacing

---

## Accessibility Features

All components include:

1. **Semantic HTML**: Proper `<button>`, `<input>`, `<label>` tags
2. **ARIA Labels**: `aria-label`, `aria-labelledby`, `aria-describedby`
3. **Keyboard Support**: Tab, Enter, Space, Arrow keys
4. **Focus Management**: Visible focus indicators (2px outline)
5. **Color Contrast**: 4.5:1 for text on backgrounds
6. **Screen Readers**: Proper roles and announcements
7. **Error Handling**: Clear, actionable error messages

---

## Usage Examples

### Form with Validation
```jsx
<FormGroup label="Email" required error="Invalid email format">
  <Input 
    type="email" 
    placeholder="your@company.com"
    value={email}
    onChange={setEmail}
  />
</FormGroup>
```

### Data Table with Pagination
```jsx
<Table
  columns={[
    { key: 'repo', label: 'Repository', sortable: true },
    { key: 'status', label: 'Status' },
    { key: 'lastScan', label: 'Last Scanned' }
  ]}
  data={repositories}
  pagination={{ pageSize: 25, totalCount: 150 }}
/>
```

### Status Card
```jsx
<Card>
  <MetricCard
    title="Compliant Repos"
    value="24"
    color="green"
    trend={{ direction: 'up', value: 2 }}
  />
</Card>
```

---

## Component File Structure

```
src/components/
├── Button/
│   ├── Button.tsx
│   ├── Button.stories.tsx
│   └── Button.test.tsx
├── Input/
│   ├── Input.tsx
│   ├── Input.stories.tsx
│   └── Input.test.tsx
├── Card/
├── Modal/
├── Table/
├── Navigation/
└── Notifications/
```

---

## Testing Requirements

Each component includes:
- Unit tests (Jest)
- Accessibility tests (axe, jest-axe)
- Visual regression tests (Storybook)
- Integration tests (React Testing Library)

---

## Version

**Component Library v1.0**  
**Last Updated**: May 2024  
**Status**: Ready for Implementation

