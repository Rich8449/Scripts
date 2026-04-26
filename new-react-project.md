# new-react-project.sh

**Scaffolds a modern, production-ready Next.js 15 project with TypeScript, Tailwind CSS, shadcn/ui, Zustand, TanStack Query, Auth.js, Vitest, and GitHub Actions.**

## Overview

This script automates the creation of a new Next.js application with a carefully curated, commercial-grade technology stack. It follows the same conventions as `new-python-project.sh`: a single shell script that orchestrates all setup, preceded by a `.md` specification (this file).

### Key Features

- **Next.js 15** with TypeScript and the App Router (file-based routing)
- **Tailwind CSS** + **shadcn/ui** for rapid, accessible component development
- **State Management**: Zustand (client state) + TanStack Query v5 (server/async state)
- **Authentication**: Auth.js (NextAuth) pre-configured with session support
- **Full Test Suite**: Vitest + React Testing Library with example tests and coverage
- **Code Quality**: ESLint + Prettier + Husky pre-commit hooks + lint-staged
- **CI/CD**: GitHub Actions workflow (lint, type-check, test, build)
- **Containerization**: Docker with multi-stage build for production deployments
- **Developer Experience**: Hot module reloading, strict TypeScript, ready for Vercel or self-hosted

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
| `--name <name>` | string | (required) | Project name; must be alphanumeric with hyphens/underscores, no leading digit |
| `--dir <dir>` | string | `.` | Parent directory where the project folder is created |
| `--force` | flag | false | Overwrite existing directory (dangerous) |
| `--no-auth` | flag | false | Skip Auth.js setup; useful if you'll implement auth separately |
| `--no-docker` | flag | false | Skip Docker files (Dockerfile, .dockerignore, docker-compose.yml) |
| `--no-ci` | flag | false | Skip GitHub Actions workflow |
| `--dry-run` | flag | false | Print all commands without executing; useful for preview |
| `--verbose` | flag | false | Extra logging (shows each command being run) |
| `--help` | flag | — | Show usage and examples |

### Examples

```bash
# Simplest: create in current directory
./new-react-project.sh --name my-blog

# Create in a subdirectory
./new-react-project.sh --name my-app --dir ~/projects

# Create without Auth.js (if you'll use external OAuth or sessions)
./new-react-project.sh my-auth-experiment --no-auth

# Dry-run to preview what would be created
./new-react-project.sh --name test --dry-run --verbose

# Skip Docker and CI (minimal setup)
./new-react-project.sh my-app --no-docker --no-ci
```

---

## Generated Project Structure

```
my-app/
├── app/                           # Next.js App Router
│   ├── layout.tsx                 # Root layout: providers, fonts, metadata
│   ├── page.tsx                   # Home page (GET /)
│   ├── error.tsx                  # Error boundary for route segment
│   ├── loading.tsx                # Suspense fallback
│   ├── not-found.tsx              # 404 handler
│   └── api/
│       └── auth/[...nextauth]/
│           └── route.ts           # Auth.js API routes (if auth enabled)
│
├── components/
│   └── ui/                        # shadcn/ui components (auto-added via CLI)
│
├── lib/
│   ├── utils.ts                   # cn() classname helper for Tailwind
│   ├── query.tsx                  # TanStack QueryClient provider + devtools
│   ├── store.ts                   # Zustand store example (counter slice)
│   └── auth.ts                    # Auth.js configuration (if auth enabled)
│
├── middleware.ts                  # Next.js middleware (auth guards, etc.)
│
├── tests/
│   ├── setup.ts                   # Vitest globals, RTL cleanup, mocks
│   └── app/
│       └── page.test.tsx          # Example: home page smoke test
│
├── public/                        # Static assets
│
├── .github/
│   └── workflows/
│       └── ci.yml                 # GitHub Actions: lint → type-check → test → build
│
├── .env.local                     # (gitignored) Private secrets; AUTH_SECRET auto-generated
├── .env.local.example             # (committed) Template for required env vars
│
├── .editorconfig                  # Editor formatting rules (2-space indent, LF line endings, etc.)
├── .gitattributes                 # Git line-ending normalization
├── .gitignore                     # Git ignore patterns (node_modules, .next, etc.)
├── .prettierrc                    # Prettier config: 100 char line length, Tailwind plugin
├── .prettierignore                # Prettier ignore patterns
│
├── Dockerfile                     # Multi-stage: deps → builder → runner
├── .dockerignore                  # Docker ignore patterns
├── docker-compose.yml             # Single-service compose for local development
│
├── eslint.config.mjs              # ESLint flat config; includes Prettier compatibility
├── next.config.ts                 # Next.js config: standalone output for Docker, strict ESLint dirs
├── tailwind.config.ts             # Tailwind with shadcn preset
├── tsconfig.json                  # TypeScript: strict mode, path alias @/*
├── vitest.config.ts               # Vitest: jsdom environment, coverage, setupFiles
│
├── package.json                   # Dependencies + custom scripts
├── package-lock.json              # Locked versions (npm ci for reproducible builds)
│
└── README.md                      # Project documentation with setup, stack details, examples
```

---

## Stack Rationale

### Framework: Next.js 15 + App Router

Next.js is the industry standard for production React applications. The App Router (file-based routing) is the modern approach:

- **Server Components by default** — reduce client-side JavaScript, better SEO, direct database access
- **API Routes** — backend endpoints colocated with frontend
- **Built-in optimization** — image optimization, font loading, code splitting
- **Deployment** — seamless integration with Vercel; self-hosting support via `output: 'standalone'`
- **Developer experience** — hot module reloading, TypeScript out of the box, zero-config

### Styling: Tailwind CSS + shadcn/ui

- **Tailwind CSS** — utility-first, atomic styling; scales to large projects without CSS bloat
- **shadcn/ui** — pre-built, accessible, unstyled React components; you own the code (not a package), customize freely
- **Tailwind Prettier plugin** — auto-sorts class names for consistency

### State Management: Zustand + TanStack Query

- **Zustand** — minimal, unopinionated client-state library; no Redux boilerplate, fast
- **TanStack Query (React Query)** — server/async state management; handles caching, refetching, mutations; reduces useEffect complexity
- **Separation of concerns** — Zustand for UI state (theme, modals, filters); TanStack for API data (todos, users, etc.)

### Authentication: Auth.js (NextAuth)

- **Auth.js** (formerly NextAuth.js) — production-grade authentication library
- Pre-configured session provider, middleware for protected routes, and placeholder providers
- Supports OAuth (Google, GitHub, etc.), email, credentials, and custom providers
- Secure by default: `AUTH_SECRET` auto-generated and stored in `.env.local`

### Testing: Vitest + React Testing Library

- **Vitest** — Vite-native test runner; faster than Jest, great for modern ESM codebases
- **React Testing Library** — query by user interactions, not implementation details; encourages testing best practices
- **Example test** included: smoke test for the home page

### Code Quality: ESLint + Prettier + Husky + lint-staged

- **ESLint** — static analysis; enforces consistency and catches common bugs
- **Prettier** — opinionated formatter; removes bikeshedding
- **Husky + lint-staged** — pre-commit hooks; lint and format only staged files before commit
- No manual formatting; tools run automatically

### CI/CD: GitHub Actions

- Triggers on push to `main`, `develop`, `feature/**`; on PRs to `main`
- Pipeline: `npm lint` → `npm run type-check` → `npm test -- --coverage` → `npm run build`
- Codecov integration for coverage tracking (optional)

### Docker: Multi-Stage Build

- **Stage 1: deps** — install production dependencies
- **Stage 2: builder** — full build (dev deps, Next.js compilation)
- **Stage 3: runner** — minimal production image; copies `.next/standalone` (output via `next.config.ts`)
- **Result** — small, fast, secure image; runs `node server.js` on port 3000

---

## Configuration Files Explained

### `lib/query.tsx` — TanStack Query Provider

```tsx
'use client'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,          // 1 min before refetch
      gcTime: 5 * 60_000,          // 5 min cache lifetime
      retry: 1,                    // retry once on error
      refetchOnWindowFocus: false, // don't refetch on tab focus
    },
  },
})

export function QueryProvider({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} /> {/* Devtools for debugging */}
    </QueryClientProvider>
  )
}
```

**Usage in components:**

```tsx
'use client'

export function TodoList() {
  const { data: todos, isLoading } = useQuery({
    queryKey: ['todos'],
    queryFn: async () => {
      const res = await fetch('/api/todos')
      if (!res.ok) throw new Error('Failed to fetch')
      return res.json()
    },
  })

  if (isLoading) return <div>Loading...</div>
  return <ul>{todos?.map(t => <li key={t.id}>{t.title}</li>)}</ul>
}
```

### `lib/store.ts` — Zustand Store

```ts
interface CounterState {
  count: number
  increment: () => void
  decrement: () => void
  reset: () => void
}

export const useCounterStore = create<CounterState>(set => ({
  count: 0,
  increment: () => set(state => ({ count: state.count + 1 })),
  decrement: () => set(state => ({ count: state.count - 1 })),
  reset: () => set({ count: 0 }),
}))
```

**Usage:**

```tsx
'use client'

export function Counter() {
  const { count, increment, reset } = useCounterStore()
  return (
    <div>
      <p>Count: {count}</p>
      <button onClick={increment}>+1</button>
      <button onClick={reset}>Reset</button>
    </div>
  )
}
```

**Multi-slice store (recommended pattern):**

```ts
// lib/store/counter.ts
export const useCounterSlice = (set: SetState) => ({ ... })

// lib/store/user.ts
export const useUserSlice = (set: SetState) => ({ ... })

// lib/store.ts
export const useStore = create((...args) => ({
  ...useCounterSlice(...args),
  ...useUserSlice(...args),
}))
```

### `lib/auth.ts` — Auth.js Configuration

```ts
import NextAuth from 'next-auth'
import GitHub from 'next-auth/providers/github'
import Google from 'next-auth/providers/google'

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    GitHub({ clientId: process.env.GITHUB_ID, clientSecret: process.env.GITHUB_SECRET }),
    Google({ clientId: process.env.GOOGLE_ID, clientSecret: process.env.GOOGLE_SECRET }),
  ],
  pages: {
    signIn: '/login',        // Custom login page (optional)
    signOut: '/logout',      // Custom logout page
    error: '/auth-error',    // Error page
  },
})
```

**Session usage in components:**

```tsx
import { auth } from '@/lib/auth'

export async function UserGreeting() {
  const session = await auth()
  if (!session) return <div>Please log in</div>
  return <div>Hello, {session.user?.name}</div>
}
```

**Client-side session (requires SessionProvider in layout):**

```tsx
'use client'

import { useSession } from 'next-auth/react'

export function ClientUserGreeting() {
  const { data: session } = useSession()
  return session ? <div>Hello, {session.user?.name}</div> : <LoginButton />
}
```

### `app/layout.tsx` — Root Layout with Providers

```tsx
import { SessionProvider } from 'next-auth/react'
import { QueryProvider } from '@/lib/query'

export const metadata: Metadata = {
  title: 'My App',
  description: 'Description here',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <SessionProvider>
          <QueryProvider>
            {children}
          </QueryProvider>
        </SessionProvider>
      </body>
    </html>
  )
}
```

**Provider order matters:** SessionProvider wraps QueryProvider (session is needed for auth-protected queries).

### `vitest.config.ts` — Test Configuration

```ts
import path from 'path'
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',      // Browser-like DOM for React
    globals: true,             // describe, it, expect without imports
    setupFiles: ['tests/setup.ts'],  // Run before each test file
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['app/**', 'components/**', 'lib/**'],
    },
  },
  resolve: {
    alias: { '@': path.resolve(__dirname, './') }, // Path alias @/ → root
  },
})
```

---

## Package Scripts

After creation, the following npm scripts are available:

### Development

```bash
npm run dev          # Start dev server (localhost:3000, HMR enabled)
npm run build        # Production build
npm start            # Start production server (requires npm run build first)
```

### Code Quality

```bash
npm run lint         # ESLint check
npm run format       # Auto-format with Prettier
npm run format:check # Check formatting without fixing
npm run type-check   # TypeScript type checking (tsc --noEmit)
```

### Testing

```bash
npm test                 # Run full test suite once
npm run test:watch      # Watch mode (re-run on file changes)
npm run test:coverage   # Run tests with coverage report
```

---

## Dependencies

### Core

- **next** — React framework
- **react**, **react-dom** — React library
- **typescript** — Static typing

### UI & Styling

- **tailwindcss** — Utility CSS
- **@radix-ui/\*** — Headless components (used by shadcn)
- **class-variance-authority** — Component variant styling
- **clsx**, **tailwind-merge** — Classname helpers

### State & Data

- **zustand** — Client state management
- **@tanstack/react-query** — Server state / API caching
- **@tanstack/react-query-devtools** — Query debugging

### Authentication (optional)

- **next-auth** — Session & OAuth

### Dev Dependencies

- **vitest** — Test runner
- **@vitest/coverage-v8** — Coverage reporting
- **@vitest/ui** — Test UI dashboard
- **@testing-library/react** — React component testing
- **@testing-library/jest-dom** — DOM matchers
- **msw** — Mock Service Worker (API mocking)
- **prettier** — Code formatter
- **prettier-plugin-tailwindcss** — Tailwind class sorting
- **eslint** — Linter (Next.js config)
- **husky** — Git hooks
- **lint-staged** — Pre-commit linting

---

## Development Workflow

### First Time Setup

```bash
cd my-app
npm install                # Already done by script, but run again if needed
cp .env.local.example .env.local  # Usually pre-created by script
npm run dev               # Start dev server
```

### Making Changes

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Write code** (TypeScript enforced):
   ```bash
   npm run type-check  # Check types
   npm test            # Run tests
   npm run lint        # Check code quality
   ```

3. **Commit** (pre-commit hooks auto-run):
   ```bash
   git add .
   git commit -m "feat: add my feature"  # Husky runs prettier + eslint --fix on staged files
   ```

4. **Push and PR:**
   ```bash
   git push -u origin feature/my-feature
   ```
   GitHub Actions CI will run automatically.

---

## Deployment

### Vercel (Recommended)

```bash
# Vercel auto-detects Next.js; just push to GitHub
git push origin main  # GitHub Actions runs; Vercel deploys on merge
```

### Docker / Self-Hosted

```bash
# Build image
docker build -t my-app .

# Run locally
docker run -p 3000:3000 -e AUTH_SECRET=my-secret my-app

# Or with compose
docker-compose up
```

The Dockerfile uses a multi-stage build with `output: 'standalone'` for minimal, production-ready images.

---

## Common Tasks

### Add a shadcn/ui Component

```bash
npx shadcn-ui@latest add button  # Adds Button to components/ui/button.tsx
```

Then use:

```tsx
import { Button } from '@/components/ui/button'

export function MyComponent() {
  return <Button variant="outline">Click me</Button>
}
```

### Add Authentication Providers

Edit `lib/auth.ts`:

```ts
import GitHub from 'next-auth/providers/github'
import Google from 'next-auth/providers/google'

export const { ... } = NextAuth({
  providers: [
    GitHub({ clientId: process.env.GITHUB_ID, clientSecret: process.env.GITHUB_SECRET }),
    Google({ clientId: process.env.GOOGLE_ID, clientSecret: process.env.GOOGLE_SECRET }),
  ],
  ...
})
```

Add env vars to `.env.local`:

```env
GITHUB_ID=...
GITHUB_SECRET=...
GOOGLE_ID=...
GOOGLE_SECRET=...
```

### Add a New API Route

Create `app/api/todos/route.ts`:

```ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(req: NextRequest) {
  const todos = await db.todos.findAll()
  return NextResponse.json(todos)
}

export async function POST(req: NextRequest) {
  const body = await req.json()
  const todo = await db.todos.create(body)
  return NextResponse.json(todo, { status: 201 })
}
```

### Write a Test

Create `tests/components/button.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect } from 'vitest'
import { Button } from '@/components/ui/button'

describe('Button', () => {
  it('renders and responds to clicks', async () => {
    const handleClick = vi.fn()
    render(<Button onClick={handleClick}>Click me</Button>)

    const button = screen.getByText('Click me')
    await userEvent.click(button)

    expect(handleClick).toHaveBeenCalledOnce()
  })
})
```

---

## Troubleshooting

### Port 3000 Already in Use

```bash
# macOS/Linux
lsof -i :3000  # Find process
kill -9 <PID>  # Kill it

# Or use different port
npm run dev -- -p 3001
```

### TypeScript Errors After Changes

```bash
npm run type-check  # Detailed error report
```

### Test Failures

```bash
npm run test:watch  # Interactive test runner
npm test -- --reporter=verbose  # Detailed output
```

### Docker Build Fails

```bash
docker build --progress=plain -t my-app .  # See full build log
```

---

## Next Steps After Project Creation

1. **Customize `lib/store.ts`** — Add your app's state slices
2. **Create API routes** in `app/api/` for backend logic
3. **Add shadcn/ui components** as needed
4. **Set up authentication** providers in `lib/auth.ts`
5. **Write tests** in `tests/` for core features
6. **Deploy** to Vercel or Docker
7. **Run `claude init`** to generate `CLAUDE.md` for AI pair programming

---

## References

- [Next.js Documentation](https://nextjs.org/docs)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [shadcn/ui Component Library](https://ui.shadcn.com/)
- [Zustand Documentation](https://github.com/pmndrs/zustand)
- [TanStack Query Documentation](https://tanstack.com/query/latest)
- [Auth.js Documentation](https://authjs.dev/)
- [Vitest Documentation](https://vitest.dev/)
- [React Testing Library Documentation](https://testing-library.com/react)
