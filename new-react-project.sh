#!/bin/bash

set -euo pipefail

# new-react-project.sh
# Scaffolds a new Next.js project with TypeScript, Tailwind, shadcn/ui, Zustand, TanStack Query, Auth.js, and full tooling.

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_AUTHOR="Rich Taft"

# Color codes for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'

# Global options
project_name=""
project_dir="."
force_create=false
skip_auth=false
skip_docker=false
skip_ci=false
dry_run=false
verbose=false

# Output helpers
print_info() {
  echo -e "${COLOR_BLUE}ℹ${COLOR_RESET} $*"
}

print_success() {
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} $*"
}

print_warning() {
  echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $*"
}

print_error() {
  echo -e "${COLOR_RED}✗${COLOR_RESET} $*" >&2
}

# Run a command, respecting dry-run mode
run_cmd() {
  if [[ "$dry_run" == true ]]; then
    print_info "[DRY RUN] $*"
  else
    if [[ "$verbose" == true ]]; then
      print_info "Running: $*"
    fi
    "$@"
  fi
}

show_help() {
  cat <<EOF
new-react-project.sh v${SCRIPT_VERSION}

USAGE:
  new-react-project.sh --name <project-name> [OPTIONS]

DESCRIPTION:
  Scaffolds a new Next.js 15 project with TypeScript, Tailwind CSS, shadcn/ui,
  Zustand, TanStack Query, Auth.js, Vitest, ESLint, Prettier, Docker, and GitHub Actions CI.

OPTIONS:
  --name <name>       Project name (required; or use positional argument)
  --dir <dir>         Parent directory (default: .)
  --force             Overwrite existing directory
  --no-auth           Skip Auth.js setup
  --no-docker         Skip Docker configuration
  --no-ci             Skip GitHub Actions workflow
  --dry-run           Print commands without executing
  --verbose           Extra logging
  --help              Show this help message

EXAMPLES:
  new-react-project.sh --name my-app
  new-react-project.sh --name my-app --dir ~/projects --no-auth
  new-react-project.sh my-app --no-docker

EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name)
        project_name="$2"
        shift 2
        ;;
      --dir)
        project_dir="$2"
        shift 2
        ;;
      --force)
        force_create=true
        shift
        ;;
      --no-auth)
        skip_auth=true
        shift
        ;;
      --no-docker)
        skip_docker=true
        shift
        ;;
      --no-ci)
        skip_ci=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --verbose)
        verbose=true
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      -*)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
      *)
        # Positional argument: project name
        if [[ -z "$project_name" ]]; then
          project_name="$1"
        else
          print_error "Unexpected positional argument: $1"
          exit 1
        fi
        shift
        ;;
    esac
  done
}

validate_project_name() {
  if [[ -z "$project_name" ]]; then
    print_error "Project name is required"
    show_help
    exit 1
  fi

  # Validate: alphanumeric + hyphens + underscores, no leading digit
  if ! [[ "$project_name" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
    print_error "Project name must start with a letter or underscore, and contain only alphanumeric characters, hyphens, and underscores"
    exit 1
  fi
}

check_dependencies() {
  local missing=()

  for cmd in node npm npx git; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    print_error "Missing required dependencies: ${missing[*]}"
    echo "Please install Node.js (which includes npm and npx) and Git." >&2
    exit 1
  fi

  # Check optional tools
  if ! command -v gh &>/dev/null; then
    print_warning "GitHub CLI (gh) not found. You can still create the repo manually."
  fi

  if ! command -v claude &>/dev/null; then
    print_warning "Claude CLI not found. You will need to run 'claude init' manually after setup."
  fi
}

check_node_version() {
  local node_version
  node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)

  if [[ $node_version -lt 20 ]]; then
    print_error "Node.js 20+ is required (you have v$(node -v | cut -d'v' -f2))"
    exit 1
  fi
}

check_directory() {
  local full_path="$project_dir/$project_name"

  if [[ -e "$full_path" ]]; then
    if [[ "$force_create" == false ]]; then
      print_error "Directory already exists: $full_path"
      echo "Use --force to overwrite." >&2
      exit 1
    else
      print_warning "Overwriting existing directory: $full_path"
      run_cmd rm -rf "$full_path"
    fi
  fi
}

create_next_app() {
  print_info "Creating Next.js app..."
  run_cmd npx create-next-app@latest "$project_name" \
    --typescript \
    --tailwind \
    --eslint \
    --app \
    --no-src-dir \
    --import-alias "@/*" \
    --no-git \
    --no-git-init \
    --skip-install \
    --use-npm \
    --yes \
    --cwd "$project_dir"
  print_success "Next.js app created"
}

install_dependencies() {
  print_info "Installing dependencies..."
  local full_path="$project_dir/$project_name"

  # Core dependencies
  local deps=(
    "zustand"
    "@tanstack/react-query@5"
    "@tanstack/react-query-devtools@5"
    "next-auth@beta"
    "react-icons"
  )

  # Development dependencies
  local dev_deps=(
    "vitest"
    "@vitest/coverage-v8"
    "@vitest/ui"
    "@vitejs/plugin-react"
    "@testing-library/react"
    "@testing-library/jest-dom"
    "@testing-library/user-event"
    "msw"
    "husky"
    "lint-staged"
    "prettier"
    "prettier-plugin-tailwindcss"
  )

  run_cmd npm install --prefix "$full_path" "${deps[@]}"
  print_success "Core dependencies installed"

  run_cmd npm install --save-dev --prefix "$full_path" "${dev_deps[@]}"
  print_success "Dev dependencies installed"
}

init_shadcn() {
  print_info "Initializing shadcn/ui..."
  local full_path="$project_dir/$project_name"
  run_cmd npx shadcn-ui@latest init --cwd "$full_path" --yes
  print_success "shadcn/ui initialized"
}

patch_next_config() {
  print_info "Configuring Next.js..."
  local full_path="$project_dir/$project_name"
  local next_config_file="$full_path/next.config.ts"

  # Overwrite next.config.ts with standalone output + typed config
  cat >"$next_config_file" <<'NEXT_CONFIG'
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  eslint: {
    dirs: ['app', 'components', 'lib', 'tests'],
  },
}

export default nextConfig
NEXT_CONFIG

  print_success "next.config.ts configured"
}

create_lib_files() {
  print_info "Creating library files..."
  local full_path="$project_dir/$project_name"

  # lib/utils.ts (cn helper from shadcn)
  cat >"$full_path/lib/utils.ts" <<'LIB_UTILS'
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
LIB_UTILS

  # lib/query.tsx (TanStack Query provider)
  cat >"$full_path/lib/query.tsx" <<'LIB_QUERY'
'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { ReactNode } from 'react'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,
      gcTime: 5 * 60_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
})

export function QueryProvider({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  )
}
LIB_QUERY

  # lib/store.ts (Zustand store)
  cat >"$full_path/lib/store.ts" <<'LIB_STORE'
import { create } from 'zustand'

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
LIB_STORE

  # lib/auth.ts (Auth.js config)
  if [[ "$skip_auth" == false ]]; then
    cat >"$full_path/lib/auth.ts" <<'LIB_AUTH'
import NextAuth from 'next-auth'

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [],
  pages: {
    signIn: '/login',
  },
})
LIB_AUTH
  fi

  print_success "Library files created"
}

create_app_files() {
  print_info "Creating app structure..."
  local full_path="$project_dir/$project_name"

  # app/layout.tsx
  if [[ "$skip_auth" == false ]]; then
    cat >"$full_path/app/layout.tsx" <<'APP_LAYOUT_AUTH'
import type { Metadata } from 'next'
import { SessionProvider } from 'next-auth/react'
import { QueryProvider } from '@/lib/query'
import './globals.css'

export const metadata: Metadata = {
  title: 'Create Next App',
  description: 'Generated by create next app',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <SessionProvider>
          <QueryProvider>{children}</QueryProvider>
        </SessionProvider>
      </body>
    </html>
  )
}
APP_LAYOUT_AUTH
  else
    cat >"$full_path/app/layout.tsx" <<'APP_LAYOUT_NO_AUTH'
import type { Metadata } from 'next'
import { QueryProvider } from '@/lib/query'
import './globals.css'

export const metadata: Metadata = {
  title: 'Create Next App',
  description: 'Generated by create next app',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        <QueryProvider>{children}</QueryProvider>
      </body>
    </html>
  )
}
APP_LAYOUT_NO_AUTH
  fi

  # app/page.tsx
  cat >"$full_path/app/page.tsx" <<'APP_PAGE'
export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <h1 className="text-4xl font-bold">Hello World</h1>
      <p className="text-lg text-gray-600">Welcome to your Next.js app</p>
    </main>
  )
}
APP_PAGE

  # app/error.tsx
  cat >"$full_path/app/error.tsx" <<'APP_ERROR'
'use client'

import { useEffect } from 'react'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-24">
      <h2 className="text-2xl font-bold">Something went wrong!</h2>
      <button
        onClick={() => reset()}
        className="rounded bg-blue-500 px-4 py-2 text-white hover:bg-blue-600"
      >
        Try again
      </button>
    </div>
  )
}
APP_ERROR

  # app/loading.tsx
  cat >"$full_path/app/loading.tsx" <<'APP_LOADING'
export default function Loading() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <div className="animate-spin">
        <div className="h-12 w-12 rounded-full border-4 border-gray-200 border-t-blue-500" />
      </div>
    </div>
  )
}
APP_LOADING

  # app/not-found.tsx
  cat >"$full_path/app/not-found.tsx" <<'APP_NOT_FOUND'
import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 p-24">
      <h2 className="text-2xl font-bold">Not Found</h2>
      <p className="text-gray-600">Could not find the requested resource</p>
      <Link href="/" className="text-blue-500 hover:underline">
        Return Home
      </Link>
    </div>
  )
}
APP_NOT_FOUND

  # Auth.js API route (if auth enabled)
  if [[ "$skip_auth" == false ]]; then
    mkdir -p "$full_path/app/api/auth"
    cat >"$full_path/app/api/auth/[...nextauth]/route.ts" <<'AUTH_ROUTE'
import { handlers } from '@/lib/auth'

export const GET = handlers.GET
export const POST = handlers.POST
AUTH_ROUTE
  fi

  print_success "App files created"
}

create_middleware() {
  if [[ "$skip_auth" == false ]]; then
    print_info "Creating middleware..."
    local full_path="$project_dir/$project_name"

    cat >"$full_path/middleware.ts" <<'MIDDLEWARE'
import { auth } from '@/lib/auth'

export default auth(req => {
  // Middleware runs for all routes; add protected route logic here if needed
})

export const config = {
  matcher: [
    // Exclude static files and internal routes
    '/((?!api|_next/static|_next/image|favicon.ico).*)',
  ],
}
MIDDLEWARE

    print_success "Middleware created"
  fi
}

create_test_files() {
  print_info "Creating test setup..."
  local full_path="$project_dir/$project_name"

  mkdir -p "$full_path/tests"

  # vitest.config.ts
  cat >"$full_path/vitest.config.ts" <<'VITEST_CONFIG'
import react from '@vitejs/plugin-react'
import path from 'path'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['tests/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['app/**', 'components/**', 'lib/**'],
      exclude: ['**/*.test.ts', '**/*.test.tsx', '**/node_modules/**'],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './'),
    },
  },
})
VITEST_CONFIG

  # tests/setup.ts
  cat >"$full_path/tests/setup.ts" <<'TEST_SETUP'
import '@testing-library/jest-dom'
import { expect, afterEach, vi } from 'vitest'
import { cleanup } from '@testing-library/react'

afterEach(() => {
  cleanup()
})

// Mock Next.js router
vi.mock('next/navigation', () => ({
  useRouter() {
    return {
      push: vi.fn(),
      replace: vi.fn(),
      prefetch: vi.fn(),
    }
  },
  useSearchParams() {
    return new URLSearchParams()
  },
  usePathname() {
    return ''
  },
}))
TEST_SETUP

  # tests/app/page.test.tsx
  mkdir -p "$full_path/tests/app"
  cat >"$full_path/tests/app/page.test.tsx" <<'PAGE_TEST'
import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import Home from '@/app/page'

describe('Home Page', () => {
  it('renders the heading', () => {
    render(<Home />)
    expect(screen.getByText('Hello World')).toBeDefined()
  })

  it('renders the welcome message', () => {
    render(<Home />)
    expect(screen.getByText('Welcome to your Next.js app')).toBeDefined()
  })
})
PAGE_TEST

  print_success "Test files created"
}

add_package_scripts() {
  print_info "Configuring package.json scripts..."
  local full_path="$project_dir/$project_name"

  # Read current package.json
  local pkg_file="$full_path/package.json"
  local temp_pkg="/tmp/package.json.tmp"

  # Use jq or npm to add scripts
  run_cmd npm pkg --prefix "$full_path" set scripts.type-check="tsc --noEmit"
  run_cmd npm pkg --prefix "$full_path" set scripts.test="vitest run"
  run_cmd npm pkg --prefix "$full_path" set scripts.test:watch="vitest"
  run_cmd npm pkg --prefix "$full_path" set scripts.test:coverage="vitest run --coverage"
  run_cmd npm pkg --prefix "$full_path" set scripts.format="prettier --write ."
  run_cmd npm pkg --prefix "$full_path" set scripts.format:check="prettier --check ."

  print_success "Package scripts added"
}

configure_code_quality() {
  print_info "Configuring code quality tools..."
  local full_path="$project_dir/$project_name"

  # .prettierrc
  cat >"$full_path/.prettierrc" <<'PRETTIER_CONFIG'
{
  "semi": false,
  "singleQuote": true,
  "trailingComma": "es5",
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false,
  "arrowParens": "avoid",
  "plugins": ["prettier-plugin-tailwindcss"]
}
PRETTIER_CONFIG

  # .prettierignore
  cat >"$full_path/.prettierignore" <<'PRETTIER_IGNORE'
node_modules
.next
dist
coverage
.env.local
.env.local.example
PRETTIER_IGNORE

  # .editorconfig
  cat >"$full_path/.editorconfig" <<'EDITOR_CONFIG'
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.md]
trim_trailing_whitespace = false
EDITOR_CONFIG

  # .gitattributes
  cat >"$full_path/.gitattributes" <<'GIT_ATTRIBUTES'
* text=auto
*.ts text eol=lf
*.tsx text eol=lf
*.js text eol=lf
*.jsx text eol=lf
*.json text eol=lf
*.md text eol=lf
GIT_ATTRIBUTES

  # Patch eslint.config.mjs to add prettier compatibility
  if [[ -f "$full_path/eslint.config.mjs" ]]; then
    # Add prettier to eslint config (simple append for compatibility)
    cat >>"$full_path/eslint.config.mjs" <<'ESLINT_PRETTIER'

// Prettier compatibility
import prettier from 'eslint-config-prettier'

export default [
  ...eslintConfig,
  prettier,
]
ESLINT_PRETTIER
  fi

  print_success "Code quality tools configured"
}

create_env_files() {
  print_info "Creating environment files..."
  local full_path="$project_dir/$project_name"

  # Generate AUTH_SECRET
  local auth_secret=""
  if command -v openssl &>/dev/null; then
    auth_secret=$(openssl rand -base64 32)
  else
    # Fallback if openssl not available
    auth_secret=$(head -c 32 /dev/urandom | base64)
  fi

  # .env.local (gitignored, with actual secret)
  cat >"$full_path/.env.local" <<ENV_LOCAL
AUTH_SECRET="${auth_secret}"
ENV_LOCAL

  # .env.local.example (committed, template only)
  cat >"$full_path/.env.local.example" <<'ENV_EXAMPLE'
# Authentication
AUTH_SECRET=your-secret-here

# API endpoints
# NEXT_PUBLIC_API_URL=http://localhost:3000/api
ENV_EXAMPLE

  print_success "Environment files created"
}

create_docker_files() {
  if [[ "$skip_docker" == false ]]; then
    print_info "Creating Docker configuration..."
    local full_path="$project_dir/$project_name"

    # Dockerfile
    cat >"$full_path/Dockerfile" <<'DOCKERFILE'
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production

FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV production
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nextjs -u 1001

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs
EXPOSE 3000
ENV PORT 3000
CMD ["node", "server.js"]
DOCKERFILE

    # .dockerignore
    cat >"$full_path/.dockerignore" <<'DOCKERIGNORE'
.git
.gitignore
node_modules
npm-debug.log
.next
coverage
.env
.env.local
README.md
DOCKERIGNORE

    # docker-compose.yml
    cat >"$full_path/docker-compose.yml" <<'DOCKER_COMPOSE'
version: '3.8'

services:
  app:
    build: .
    ports:
      - '3000:3000'
    environment:
      - NODE_ENV=production
      - AUTH_SECRET=${AUTH_SECRET}
    volumes:
      - .env.local:/app/.env.local:ro
    restart: unless-stopped
DOCKER_COMPOSE

    print_success "Docker files created"
  fi
}

create_ci() {
  if [[ "$skip_ci" == false ]]; then
    print_info "Creating GitHub Actions workflow..."
    local full_path="$project_dir/$project_name"

    mkdir -p "$full_path/.github/workflows"
    cat >"$full_path/.github/workflows/ci.yml" <<'CI_WORKFLOW'
name: CI

on:
  push:
    branches: [main, develop, 'feature/**']
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint

  type-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run type-check

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test -- --coverage
      - uses: codecov/codecov-action@v4
        with:
          files: ./coverage/coverage-final.json
          fail_ci_if_error: false

  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run build
CI_WORKFLOW

    print_success "GitHub Actions workflow created"
  fi
}

create_readme() {
  print_info "Creating README..."
  local full_path="$project_dir/$project_name"

  cat >"$full_path/README.md" <<'README_TEMPLATE'
# PROJECT_NAME

A modern full-stack Next.js 15 application with TypeScript, Tailwind CSS, shadcn/ui, Zustand, TanStack Query, and Auth.js.

## Stack

- **Framework**: Next.js 15 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS + shadcn/ui
- **State Management**: Zustand (client) + TanStack Query (server)
- **Authentication**: Auth.js (NextAuth)
- **Testing**: Vitest + React Testing Library
- **Code Quality**: ESLint + Prettier + Husky + lint-staged
- **Containerization**: Docker (multi-stage)
- **CI/CD**: GitHub Actions

## Setup

```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.local.example .env.local
# Edit .env.local with your values

# Run dev server
npm run dev

# Open browser
open http://localhost:3000
```

## Available Commands

```bash
# Development
npm run dev         # Start dev server
npm run build       # Build for production
npm start           # Start production server

# Code Quality
npm run lint        # Run ESLint
npm run format      # Format with Prettier
npm run type-check  # Run TypeScript type check

# Testing
npm test            # Run tests once
npm run test:watch  # Watch mode
npm test:coverage   # With coverage report
```

## Project Structure

```
src/
├── app/                 # Next.js App Router pages
├── components/          # React components
│   └── ui/             # shadcn/ui components
├── lib/                 # Utilities and configuration
│   ├── query.tsx       # TanStack Query provider
│   ├── store.ts        # Zustand stores
│   ├── auth.ts         # Auth.js config
│   └── utils.ts        # Helper functions
├── middleware.ts        # Next.js middleware
└── tests/              # Test files
```

## Docker

```bash
# Build image
docker build -t myapp .

# Run container
docker run -p 3000:3000 -e AUTH_SECRET=your-secret myapp

# Or use docker-compose
docker-compose up
```

## Authentication

Auth.js is pre-configured. To add providers:

1. Edit `lib/auth.ts` and add your provider(s)
2. Set required environment variables in `.env.local`
3. Add login/logout UI components as needed

See [Auth.js docs](https://authjs.dev/) for details.

## State Management

### Client State (Zustand)

```tsx
import { useCounterStore } from '@/lib/store'

export function Counter() {
  const { count, increment } = useCounterStore()
  return <button onClick={increment}>{count}</button>
}
```

### Server State (TanStack Query)

```tsx
'use client'

import { useQuery } from '@tanstack/react-query'

export function TodoList() {
  const { data, isLoading } = useQuery({
    queryKey: ['todos'],
    queryFn: async () => {
      const res = await fetch('/api/todos')
      return res.json()
    },
  })

  if (isLoading) return <div>Loading...</div>
  return <ul>{data?.map(todo => <li key={todo.id}>{todo.title}</li>)}</ul>
}
```

## Testing

Tests run with Vitest and React Testing Library. Example:

```tsx
import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import Home from '@/app/page'

describe('Home', () => {
  it('renders heading', () => {
    render(<Home />)
    expect(screen.getByText('Hello World')).toBeDefined()
  })
})
```

Run tests:

```bash
npm test           # Once
npm run test:watch # Watch mode
npm run test:coverage  # With coverage
```

## Styling

Use Tailwind CSS classes directly or import shadcn/ui components:

```tsx
import { Button } from '@/components/ui/button'

export function MyComponent() {
  return (
    <div className="flex gap-4 p-6">
      <Button>Click me</Button>
    </div>
  )
}
```

Add new shadcn/ui components:

```bash
npx shadcn-ui@latest add <component-name>
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Run `npm run format` to auto-fix formatting
4. Ensure `npm test` and `npm run type-check` pass
5. Commit (pre-commit hooks will lint staged files)
6. Push and open a PR

## License

MIT
README_TEMPLATE

  # Replace placeholder with actual project name
  sed -i "s/PROJECT_NAME/$project_name/g" "$full_path/README.md"

  print_success "README created"
}

initialize_git() {
  print_info "Initializing git repository..."
  local full_path="$project_dir/$project_name"

  run_cmd git -C "$full_path" init
  run_cmd git -C "$full_path" config user.name "$(git config user.name || echo 'Rich Taft')"
  run_cmd git -C "$full_path" config user.email "$(git config user.email || echo 'rt2726@gmail.com')"

  # Create .gitignore if not present
  if [[ ! -f "$full_path/.gitignore" ]]; then
    cat >"$full_path/.gitignore" <<'GITIGNORE'
node_modules/
.next/
.env.local
.env.local.backup
dist/
build/
coverage/
*.log
.DS_Store
GITIGNORE
  fi

  run_cmd git -C "$full_path" add .
  run_cmd git -C "$full_path" commit -m "Initial commit: Next.js 15 project scaffold

- Next.js 15 with TypeScript and App Router
- Tailwind CSS + shadcn/ui component library
- Zustand for client state, TanStack Query for server state
- Auth.js pre-configured (NextAuth)
- Vitest + React Testing Library
- ESLint + Prettier + Husky pre-commit hooks
- GitHub Actions CI/CD workflow
- Docker multi-stage build
- Full type-safety and test infrastructure"

  print_success "Git repository initialized"
}

setup_husky() {
  print_info "Setting up Husky pre-commit hooks..."
  local full_path="$project_dir/$project_name"

  run_cmd npm --prefix "$full_path" exec husky install
  run_cmd npm --prefix "$full_path" exec husky add .husky/pre-commit "npx lint-staged"

  print_success "Husky configured"
}

run_claude_init() {
  local full_path="$project_dir/$project_name"

  if command -v claude &>/dev/null; then
    print_info "Running 'claude init'..."
    run_cmd claude init --cwd "$full_path"
    print_success "claude init completed"
  else
    print_warning "Claude CLI not found. Run the following manually:"
    echo "  cd $full_path && claude init"
  fi
}

main() {
  print_info "new-react-project.sh v${SCRIPT_VERSION}"
  echo

  parse_args "$@"
  validate_project_name
  check_dependencies
  check_node_version
  check_directory

  print_info "Creating Next.js project: $project_name"
  [[ "$skip_auth" == true ]] && print_info "Auth.js will be skipped"
  [[ "$skip_docker" == true ]] && print_info "Docker support will be skipped"
  [[ "$skip_ci" == true ]] && print_info "GitHub Actions CI will be skipped"
  [[ "$dry_run" == true ]] && print_warning "Running in DRY RUN mode"
  echo

  create_next_app
  install_dependencies
  init_shadcn
  patch_next_config
  create_lib_files
  create_app_files
  create_middleware
  create_test_files
  add_package_scripts
  configure_code_quality
  create_env_files
  create_docker_files
  create_ci
  create_readme
  initialize_git
  setup_husky
  run_claude_init

  echo
  print_success "Project created successfully!"
  echo
  print_info "Next steps:"
  echo "  1. cd $project_dir/$project_name"
  echo "  2. npm run dev"
  echo "  3. Open http://localhost:3000 in your browser"
  echo
  print_info "Available commands:"
  echo "  npm run dev         - Start development server"
  echo "  npm test            - Run tests"
  echo "  npm run lint        - Check code quality"
  echo "  npm run format      - Auto-format code"
  echo "  npm run type-check  - Check TypeScript"
  echo "  npm run build       - Build for production"
  echo
}

# Guard: only run if sourced from command line (not sourced as a library)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
