# new-react-project.sh (v2.0.0)

**Production-ready Next.js 15 project scaffolder with feature-based architecture, professional test setup, and commercial-grade tooling.**

## Overview

This script generates a fully-configured Next.js 15 application designed to scale from startup to enterprise. Projects are ready for immediate development with best practices baked in: feature-based architecture, organized utilities, comprehensive testing, type safety, and professional code quality.

Unlike minimal scaffolders, this generates:
- **Structured `lib/`** with separated concerns: API client, auth config, constants, custom hooks, providers, state stores, types
- **Feature modules** under `features/` for self-contained, scalable code organization
- **Component organization** with separate directories for layout, common reusables, and shadcn/ui
- **Professional tests** with fixtures, unit tests, and integration tests (plus MSW mocking)
- **Production-grade tooling**: ESLint, Prettier, Husky, GitHub Actions CI, Docker multi-stage

---

## Installation & Usage

```bash
./new-react-project.sh --name my-app [OPTIONS]
```

Or with positional argument:

```bash
./new-react-project.sh my-app
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--name <name>` | string | (required) | Project name; alphanumeric + hyphens/underscores, no leading digit |
| `--dir <dir>` | string | `.` | Parent directory where project folder is created |
| `--force` | flag | false | Overwrite existing directory |
| `--no-auth` | flag | false | Skip Auth.js + features/auth/ setup |
| `--no-docker` | flag | false | Skip Docker files |
| `--no-ci` | flag | false | Skip GitHub Actions workflow |
| `--dry-run` | flag | false | Print commands without executing |
| `--verbose` | flag | false | Show all executed commands |
| `--help` | flag | — | Show help message |

### Examples

```bash
# Create in current directory
./new-react-project.sh --name my-blog

# Create in subdirectory with custom settings
./new-react-project.sh --name my-app --dir ~/projects

# Skip auth for API-only frontend
./new-react-project.sh api-client --no-auth

# Minimal setup (no Docker, no CI)
./new-react-project.sh minimal --no-docker --no-ci

# Preview what would be created
./new-react-project.sh --name test --dry-run --verbose
```

---

## Generated Project Structure

```
my-app/
├── app/                                    ← Next.js routing (NO business logic)
│   ├── (auth)/                             ← Route group for auth pages
│   │   ├── login/
│   │   │   └── page.tsx
│   │   └── layout.tsx
│   ├── api/
│   │   └── auth/[...nextauth]/
│   │       └── route.ts
│   ├── layout.tsx                          ← Root layout (uses <Providers>)
│   ├── page.tsx                            ← Home page (with Header/Footer)
│   ├── error.tsx                           ← Error boundary
│   ├── loading.tsx                         ← Suspense fallback
│   └── not-found.tsx                       ← 404 handler
│
├── components/                             ← Shared React components
│   ├── ui/                                 ← shadcn/ui (auto-populated)
│   ├── layout/
│   │   ├── Header.tsx
│   │   ├── Footer.tsx
│   │   └── index.ts
│   └── common/
│       ├── LoadingSpinner.tsx
│       ├── ErrorBoundary.tsx
│       ├── EmptyState.tsx
│       └── index.ts
│
├── features/                               ← Self-contained feature modules
│   └── auth/                               ← (only if --no-auth not set)
│       ├── components/
│       │   └── LoginForm.tsx
│       ├── hooks/
│       │   └── use-auth.ts
│       ├── types/
│       │   └── auth.types.ts
│       └── index.ts                        ← Public barrel export
│
├── lib/                                    ← Utilities, config, providers
│   ├── api/
│   │   └── client.ts                      ← Type-safe fetch client with error handling
│   ├── auth/
│   │   └── config.ts                      ← Auth.js config (if auth)
│   ├── constants/
│   │   └── index.ts                       ← APP_NAME, APP_URL
│   ├── hooks/
│   │   └── use-media-query.ts             ← Custom shared hooks
│   ├── providers/
│   │   ├── index.tsx                      ← Combined provider wrapper
│   │   └── query-provider.tsx             ← TanStack QueryClientProvider
│   ├── store/
│   │   └── ui.store.ts                    ← Global UI state (sidebar, theme)
│   ├── types/
│   │   ├── api.types.ts                   ← ApiResponse<T>, PaginatedResponse<T>
│   │   └── index.ts
│   ├── format.ts                          ← Date, currency, string formatting
│   └── utils.ts                           ← shadcn cn() helper (auto-created by shadcn)
│
├── middleware.ts                           ← Route protection via auth (if auth)
│
├── tests/
│   ├── fixtures/
│   │   ├── handlers.ts                    ← MSW API mock handlers
│   │   └── factories.ts                   ← Test data factories
│   ├── unit/
│   │   └── lib/
│   │       └── format.test.ts             ← Pure function unit tests
│   ├── integration/
│   │   └── components/
│   │       └── common/
│   │           └── LoadingSpinner.test.tsx
│   └── setup.ts                           ← Vitest + RTL + MSW setup
│
├── public/
│
├── .github/
│   └── workflows/
│       └── ci.yml                         ← GitHub Actions (lint, type-check, test, build)
│
├── .env.local                             ← (gitignored) Secrets + AUTH_SECRET
├── .env.local.example                     ← (committed) Template
│
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .prettierrc
├── .prettierignore
│
├── Dockerfile                             ← Multi-stage (if not --no-docker)
├── .dockerignore
├── docker-compose.yml
│
├── eslint.config.mjs                      ← ESLint flat config + prettier
├── next.config.ts                         ← Standalone output for Docker
├── tailwind.config.ts                     ← Tailwind config
├── tsconfig.json                          ← TypeScript (strict mode, @/* alias)
├── vitest.config.ts                       ← Vitest + jsdom + coverage
│
├── package.json
├── package-lock.json
│
└── README.md                              ← Comprehensive project docs
```

---

## Stack Details

### Framework: Next.js 15 + App Router

- File-based routing via `app/` directory
- Server Components by default (reduce bundle, direct DB access)
- Dynamic rendering, streaming, and ISR support
- API routes colocated with app code
- Automatic optimizations (images, fonts, code splitting)

### Language: TypeScript (Strict Mode)

```ts
// Enforced type safety across the entire codebase
interface Props { name: string }
const Component: React.FC<Props> = ({ name }) => <div>{name}</div>
```

### Styling: Tailwind CSS + shadcn/ui

- **Tailwind**: utility-first, atomic styling; scales to any size
- **shadcn/ui**: pre-built, accessible, unstyled components you own

```tsx
import { Button } from '@/components/ui/button'

<Button variant="outline" size="sm">Click me</Button>
```

### State Management: Zustand + TanStack Query

**Client state** (Zustand):
```ts
import { useUiStore } from '@/lib/store/ui.store'
const { sidebarOpen, toggleSidebar } = useUiStore()
```

**Server/API state** (TanStack Query):
```tsx
const { data: todos } = useQuery({
  queryKey: ['todos'],
  queryFn: () => apiClient.get<Todo[]>('/api/todos'),
})
```

### Authentication: Auth.js (NextAuth v5)

```ts
// lib/auth/config.ts
export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [GitHub(), Google()],  // Add your providers
})
```

- Session management (client + server)
- OAuth provider support (GitHub, Google, etc.)
- Email/credentials authentication
- Protected routes via middleware
- Type-safe session in components

### Testing: Vitest + React Testing Library + MSW

```tsx
// tests/unit/lib/format.test.ts (pure function)
describe('formatDate', () => {
  it('formats dates', () => {
    expect(formatDate('2024-01-15')).toMatch(/Jan/)
  })
})

// tests/integration/components/common/LoadingSpinner.test.tsx
describe('LoadingSpinner', () => {
  it('renders with status', () => {
    render(<LoadingSpinner />)
    expect(screen.getByRole('status')).toBeDefined()
  })
})

// tests/fixtures/handlers.ts (MSW mocks)
export const handlers = [
  http.get('/api/todos', () => HttpResponse.json([{ id: 1, title: 'Test' }])),
]
```

### Code Quality: ESLint + Prettier + Husky

- ESLint: static analysis (finds bugs, enforces patterns)
- Prettier: opinionated formatter (removes bikeshedding)
- Husky + lint-staged: auto-run on pre-commit

```bash
git add .
git commit -m "feat: add feature"
# Pre-commit hook runs: prettier --write, eslint --fix
# Test, build, lint in CI via GitHub Actions
```

### CI/CD: GitHub Actions

```yaml
# Triggers on push to main, feature branches, PRs
# Runs: lint → type-check → test (with coverage) → build
```

### Deployment: Docker Multi-Stage

```dockerfile
# Stage 1: Install deps
# Stage 2: Build Next.js app
# Stage 3: Minimal runtime (copies .next/standalone)
```

```bash
docker build -t myapp .
docker run -p 3000:3000 -e AUTH_SECRET=secret myapp
```

Or: `docker-compose up`

---

## Key Files Explained

### `lib/api/client.ts` — Type-Safe API Client

```ts
import { apiClient } from '@/lib/api/client'

// Typed request/response
const todos = await apiClient.get<Todo[]>('/api/todos')
const newTodo = await apiClient.post<Todo>('/api/todos', { title: 'Todo' })

// Error handling
try {
  await apiClient.delete('/api/todos/1')
} catch (error) {
  if (error instanceof ApiClientError) {
    console.log(`Error ${error.statusCode}: ${error.message}`)
  }
}
```

### `lib/providers/index.tsx` — Combined Providers

```tsx
// app/layout.tsx
import { Providers } from '@/lib/providers'

export default function RootLayout({ children }) {
  return <Providers>{children}</Providers>
}

// Providers wraps: SessionProvider → QueryProvider → children
```

### `lib/store/ui.store.ts` — Persistent Global State

```ts
const { sidebarOpen, toggleSidebar, theme, setTheme } = useUiStore()

// Automatically saved to localStorage as 'ui-store'
// Survives page refreshes
```

### `lib/format.ts` — Formatting Utilities

```ts
import { formatDate, formatCurrency, truncate } from '@/lib/format'

formatDate('2024-01-15')           // → 'Jan 15, 2024'
formatCurrency(1234.56, 'USD')     // → '$1,234.56'
truncate('Hello World', 5)         // → 'Hello...'
```

### `features/auth/` — Self-Contained Feature Module

```tsx
// features/auth/hooks/use-auth.ts
export function useAuth() {
  const { user, isAuthenticated, signIn, signOut } = useAuth()
  // Custom logic here
}

// features/auth/components/LoginForm.tsx
export function LoginForm() { /* component */ }

// features/auth/index.ts (public API)
export { useAuth } from './hooks/use-auth'
export { LoginForm } from './components/LoginForm'
export type { User, Session } from './types/auth.types'

// Usage in other features:
import { useAuth, LoginForm } from '@/features/auth'
```

### `tests/fixtures/handlers.ts` — MSW API Mocking

```ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/todos', () => HttpResponse.json([...])),
  http.post('/api/todos', ({ request }) => {
    const body = await request.json()
    return HttpResponse.json({ id: 1, ...body }, { status: 201 })
  }),
]

// Automatically used in tests/setup.ts
// No real API calls in tests, full control over responses
```

### `tests/fixtures/factories.ts` — Test Data

```ts
export function createUser(overrides = {}) {
  return {
    id: 'user-1',
    name: 'Test User',
    email: 'test@example.com',
    ...overrides,
  }
}

// Usage in tests:
const user = createUser({ email: 'custom@example.com' })
```

---

## Development Workflow

### First-Time Setup

```bash
cd my-app
npm install                        # (already done by script)
cp .env.local.example .env.local   # Already created, just review
npm run dev                        # Start dev server on :3000
```

### Writing Code

**Create a component:**

```tsx
// components/common/Card.tsx
import { cn } from '@/lib/utils'

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {}

export function Card({ className, ...props }: CardProps) {
  return <div className={cn('border rounded-lg p-4', className)} {...props} />
}
```

**Add an API endpoint:**

```ts
// app/api/todos/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/lib/auth/config'

export async function GET(req: NextRequest) {
  const session = await auth()
  if (!session) return new NextResponse('Unauthorized', { status: 401 })

  const todos = await db.todo.findMany()
  return NextResponse.json(todos)
}
```

**Create a feature:**

```
features/dashboard/
├── components/
│   ├── DashboardHeader.tsx
│   └── StatsCard.tsx
├── hooks/
│   └── use-dashboard.ts
├── types/
│   └── dashboard.types.ts
└── index.ts
```

**Write tests:**

```tsx
// tests/unit/lib/format.test.ts
describe('formatDate', () => {
  it('handles date strings', () => {
    expect(formatDate('2024-01-15')).toBe('Jan 15, 2024')
  })
})

// tests/integration/features/auth/LoginForm.test.tsx
it('renders login buttons', () => {
  render(<LoginForm />)
  expect(screen.getByText(/github/i)).toBeDefined()
})
```

### Git Workflow

```bash
git checkout -b feature/my-feature
# Make changes, add tests
git add .
git commit -m "feat: description"
# Pre-commit hook runs:
#   - prettier --write (auto-format)
#   - eslint --fix (auto-fix linting)
# Push and open PR
git push -u origin feature/my-feature
# GitHub Actions CI runs: lint → type-check → test → build
```

---

## Available npm Scripts

### Development

```bash
npm run dev             # Start dev server (hot reload on :3000)
npm run build           # Production build
npm start               # Run production server (requires npm run build)
```

### Code Quality

```bash
npm run lint            # ESLint + Prettier check
npm run format          # Auto-format with Prettier
npm run type-check      # TypeScript type validation
```

### Testing

```bash
npm test                # Run all tests (vitest run)
npm run test:watch      # Watch mode (re-run on file change)
npm run test:coverage   # Run with coverage report
```

---

## Deployment

### Vercel (Recommended)

```bash
git push origin main
# GitHub Actions runs tests
# Vercel auto-deploys on successful merge
```

### Self-Hosted / Docker

```bash
# Build image
docker build -t myapp .

# Run with environment
docker run -p 3000:3000 \
  -e NODE_ENV=production \
  -e AUTH_SECRET=my-secret \
  myapp

# Or with docker-compose
docker-compose up
```

### Environment Variables

```bash
# .env.local (NEVER commit this)
AUTH_SECRET=generated-automatically
GITHUB_ID=your-github-oauth-id
GITHUB_SECRET=your-github-oauth-secret
NEXT_PUBLIC_API_URL=https://api.example.com
```

---

## Architecture Principles (SOLID)

### S — Single Responsibility

Each file/component does one thing:
- `components/Header.tsx` → renders header
- `lib/api/client.ts` → handles HTTP requests
- `features/auth/hooks/use-auth.ts` → auth logic

### O — Open/Closed

Extend components via props/variants, don't modify:
```tsx
<Button variant="outline" size="sm">  // Extend via props
<LoadingSpinner size="lg" />            // Compose, don't modify
```

### L — Liskov Substitution

Props match expected interfaces:
```ts
interface Props { title: string; onClick?: () => void }
// Any component accepting Props can substitute another
```

### I — Interface Segregation

Separate interfaces for different concerns:
```ts
interface User { id: string; name: string; email: string }
interface ApiResponse<T> { data: T; success: boolean }
// Components depend on what they need, not everything
```

### D — Dependency Inversion

Depend on abstractions (hooks, APIs), not implementations:
```ts
// Good: depends on hook abstraction
const { todos } = useTodos()

// Bad: directly calls fetch
const todos = await fetch('/api/todos').then(r => r.json())
```

---

## Common Tasks

### Add a shadcn/ui Component

```bash
npx shadcn@latest add button
# Creates: components/ui/button.tsx
```

### Add an Auth Provider

```ts
// lib/auth/config.ts
import GitHub from 'next-auth/providers/github'
import Google from 'next-auth/providers/google'

export const { ... } = NextAuth({
  providers: [
    GitHub({
      clientId: process.env.GITHUB_ID!,
      clientSecret: process.env.GITHUB_SECRET!,
    }),
    Google({...}),
  ],
})
```

### Create a Feature Module

1. Create `features/my-feature/` directory
2. Add subdirs: `components/`, `hooks/`, `types/`
3. Create `index.ts` barrel export
4. Add corresponding tests in `tests/integration/features/my-feature/`

### Add a Custom Hook

```ts
// lib/hooks/use-fetch.ts
export function useFetch<T>(url: string) {
  const [data, setData] = useState<T | null>(null)
  useEffect(() => {
    fetch(url).then(r => r.json()).then(setData)
  }, [url])
  return data
}

// Usage:
const data = useFetch<Todo[]>('/api/todos')
```

### Write an Integration Test

```tsx
// tests/integration/components/common/Button.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Button } from '@/components/ui/button'

describe('Button', () => {
  it('calls onClick when clicked', async () => {
    const handleClick = vi.fn()
    render(<Button onClick={handleClick}>Click me</Button>)

    await userEvent.click(screen.getByText('Click me'))
    expect(handleClick).toHaveBeenCalledOnce()
  })
})
```

---

## Troubleshooting

### Port 3000 Already in Use

```bash
lsof -i :3000          # Find process
kill -9 <PID>          # Kill it
# Or use a different port:
npm run dev -- -p 3001
```

### TypeScript Errors

```bash
npm run type-check
# Shows detailed type errors; fix issues one by one
```

### Tests Failing

```bash
npm run test:watch
# Re-run in watch mode, easier to debug
# Check MSW handlers in tests/fixtures/handlers.ts
```

### Docker Build Fails

```bash
docker build --progress=plain -t myapp .
# See full build output, easier to diagnose
```

---

## Resources

- **[Next.js 15 Docs](https://nextjs.org/docs)**
- **[TanStack Query](https://tanstack.com/query/latest/docs)**
- **[Zustand](https://github.com/pmndrs/zustand)**
- **[shadcn/ui](https://ui.shadcn.com)**
- **[Auth.js](https://authjs.dev)**
- **[Vitest](https://vitest.dev)**
- **[Tailwind CSS](https://tailwindcss.com)**
- **[React Testing Library](https://testing-library.com/react)**
- **[Mock Service Worker](https://mswjs.io)**

