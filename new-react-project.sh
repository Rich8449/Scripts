#!/bin/bash

set -euo pipefail

# new-react-project.sh v2.0.0
# Scaffolds a production-ready Next.js 15 project with feature-based architecture.
# Generates: Next.js + TypeScript + Tailwind + shadcn/ui + Zustand + TanStack Query + Auth.js

readonly SCRIPT_VERSION="2.0.0"
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
  Scaffolds a production-ready Next.js 15 project with:
  - Feature-based architecture (features/ directory for scaling)
  - Organized lib/ with api/, auth/, constants/, hooks/, providers/, store/, types/
  - Separated components/layout/ and components/common/ (besides shadcn/ui)
  - Professional test structure: fixtures/, unit/, integration/
  - TypeScript, Tailwind CSS, shadcn/ui, Zustand, TanStack Query, Auth.js, Vitest

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
  new-react-project.sh my-app --no-auth
  new-react-project.sh --name enterprise-app --dir ~/projects

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
    --use-npm \
    --yes \
    --cwd "$project_dir"
  print_success "Next.js app created"
}

install_dependencies() {
  print_info "Installing dependencies..."
  local full_path="$project_dir/$project_name"

  local deps=(
    "zustand"
    "@tanstack/react-query@5"
    "@tanstack/react-query-devtools@5"
    "next-auth@beta"
  )

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
    "eslint-config-prettier"
  )

  run_cmd npm install --prefix "$full_path" "${deps[@]}"
  print_success "Core dependencies installed"

  run_cmd npm install --save-dev --prefix "$full_path" "${dev_deps[@]}"
  print_success "Dev dependencies installed"
}

init_shadcn() {
  print_info "Initializing shadcn/ui..."
  local full_path="$project_dir/$project_name"
  run_cmd npx shadcn@latest init --cwd "$full_path" --yes
  print_success "shadcn/ui initialized"
}

patch_next_config() {
  print_info "Configuring Next.js..."
  local full_path="$project_dir/$project_name"
  local next_config_file="$full_path/next.config.ts"

  cat >"$next_config_file" <<'NEXT_CONFIG'
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone',
  reactStrictMode: true,
  eslint: {
    dirs: ['app', 'components', 'features', 'lib', 'tests'],
  },
}

export default nextConfig
NEXT_CONFIG

  print_success "next.config.ts configured"
}

create_lib_files() {
  print_info "Creating lib/ structure..."
  local full_path="$project_dir/$project_name"

  # lib/api/client.ts
  mkdir -p "$full_path/lib/api"
  cat >"$full_path/lib/api/client.ts" <<'LIB_API_CLIENT'
export interface RequestOptions extends RequestInit {
  params?: Record<string, string>
}

export class ApiClientError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
    public readonly code?: string
  ) {
    super(message)
    this.name = 'ApiClientError'
  }
}

async function request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
  const { params, ...init } = options
  const url = new URL(endpoint, process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000')
  if (params) {
    Object.entries(params).forEach(([key, value]) => url.searchParams.set(key, value))
  }

  const res = await fetch(url.toString(), {
    headers: { 'Content-Type': 'application/json', ...init.headers },
    ...init,
  })

  if (!res.ok) {
    throw new ApiClientError(res.status, res.statusText, undefined)
  }

  return res.json() as Promise<T>
}

export const apiClient = {
  get: <T>(endpoint: string, options?: RequestOptions) =>
    request<T>(endpoint, { ...options, method: 'GET' }),
  post: <T>(endpoint: string, body: unknown, options?: RequestOptions) =>
    request<T>(endpoint, { ...options, method: 'POST', body: JSON.stringify(body) }),
  put: <T>(endpoint: string, body: unknown, options?: RequestOptions) =>
    request<T>(endpoint, { ...options, method: 'PUT', body: JSON.stringify(body) }),
  patch: <T>(endpoint: string, body: unknown, options?: RequestOptions) =>
    request<T>(endpoint, { ...options, method: 'PATCH', body: JSON.stringify(body) }),
  delete: <T>(endpoint: string, options?: RequestOptions) =>
    request<T>(endpoint, { ...options, method: 'DELETE' }),
}
LIB_API_CLIENT

  # lib/types/api.types.ts
  mkdir -p "$full_path/lib/types"
  cat >"$full_path/lib/types/api.types.ts" <<'LIB_TYPES_API'
export interface ApiResponse<T> {
  data: T
  message?: string
  success: boolean
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  page: number
  totalPages: number
  totalCount: number
}

export interface ApiError {
  message: string
  code?: string
  statusCode: number
}
LIB_TYPES_API

  cat >"$full_path/lib/types/index.ts" <<'LIB_TYPES_INDEX'
export type * from './api.types'
LIB_TYPES_INDEX

  # lib/constants/index.ts
  mkdir -p "$full_path/lib/constants"
  cat >"$full_path/lib/constants/index.ts" <<'LIB_CONSTANTS'
export const APP_NAME = 'My App'
export const APP_URL = process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'
LIB_CONSTANTS

  # lib/format.ts
  cat >"$full_path/lib/format.ts" <<'LIB_FORMAT'
export function formatDate(date: Date | string, locale = 'en-US'): string {
  return new Intl.DateTimeFormat(locale, { dateStyle: 'medium' }).format(
    typeof date === 'string' ? new Date(date) : date
  )
}

export function formatCurrency(amount: number, currency = 'USD', locale = 'en-US'): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(amount)
}

export function truncate(str: string, length: number): string {
  return str.length > length ? `${str.substring(0, length)}...` : str
}
LIB_FORMAT

  # lib/store/ui.store.ts
  mkdir -p "$full_path/lib/store"
  cat >"$full_path/lib/store/ui.store.ts" <<'LIB_STORE'
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

interface UiState {
  sidebarOpen: boolean
  theme: 'light' | 'dark' | 'system'
  toggleSidebar: () => void
  setSidebarOpen: (open: boolean) => void
  setTheme: (theme: 'light' | 'dark' | 'system') => void
}

export const useUiStore = create<UiState>()(
  persist(
    set => ({
      sidebarOpen: true,
      theme: 'system',
      toggleSidebar: () => set(state => ({ sidebarOpen: !state.sidebarOpen })),
      setSidebarOpen: (open: boolean) => set({ sidebarOpen: open }),
      setTheme: (theme: 'light' | 'dark' | 'system') => set({ theme }),
    }),
    { name: 'ui-store' }
  )
)
LIB_STORE

  # lib/hooks/use-media-query.ts
  mkdir -p "$full_path/lib/hooks"
  cat >"$full_path/lib/hooks/use-media-query.ts" <<'LIB_HOOKS'
'use client'

import { useState, useEffect } from 'react'

export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false)

  useEffect(() => {
    const media = window.matchMedia(query)
    setMatches(media.matches)
    const listener = (e: MediaQueryListEvent) => setMatches(e.matches)
    media.addEventListener('change', listener)
    return () => media.removeEventListener('change', listener)
  }, [query])

  return matches
}
LIB_HOOKS

  # lib/providers/query-provider.tsx
  mkdir -p "$full_path/lib/providers"
  cat >"$full_path/lib/providers/query-provider.tsx" <<'LIB_PROVIDERS_QUERY'
'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import { useState, type ReactNode } from 'react'

export function QueryProvider({ children }: { children: ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60_000,
            gcTime: 5 * 60_000,
            retry: 1,
            refetchOnWindowFocus: false,
          },
        },
      })
  )

  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  )
}
LIB_PROVIDERS_QUERY

  # lib/providers/index.tsx (with or without auth)
  if [[ "$skip_auth" == false ]]; then
    cat >"$full_path/lib/providers/index.tsx" <<'LIB_PROVIDERS_AUTH'
import { SessionProvider } from 'next-auth/react'
import type { ReactNode } from 'react'
import { QueryProvider } from './query-provider'

export function Providers({ children }: { children: ReactNode }) {
  return (
    <SessionProvider>
      <QueryProvider>{children}</QueryProvider>
    </SessionProvider>
  )
}
LIB_PROVIDERS_AUTH
  else
    cat >"$full_path/lib/providers/index.tsx" <<'LIB_PROVIDERS_NO_AUTH'
import type { ReactNode } from 'react'
import { QueryProvider } from './query-provider'

export function Providers({ children }: { children: ReactNode }) {
  return <QueryProvider>{children}</QueryProvider>
}
LIB_PROVIDERS_NO_AUTH
  fi

  # lib/auth/config.ts (if auth)
  if [[ "$skip_auth" == false ]]; then
    mkdir -p "$full_path/lib/auth"
    cat >"$full_path/lib/auth/config.ts" <<'LIB_AUTH'
import NextAuth from 'next-auth'

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [],
  pages: {
    signIn: '/login',
  },
})
LIB_AUTH
  fi

  print_success "lib/ structure created"
}

create_components() {
  print_info "Creating components/ structure..."
  local full_path="$project_dir/$project_name"

  # components/layout/
  mkdir -p "$full_path/components/layout"
  cat >"$full_path/components/layout/Header.tsx" <<'COMP_HEADER'
import Link from 'next/link'
import { APP_NAME } from '@/lib/constants'

export function Header() {
  return (
    <header className="border-b bg-background">
      <div className="container mx-auto flex h-16 items-center px-4">
        <Link href="/" className="text-lg font-semibold">
          {APP_NAME}
        </Link>
        <nav className="ml-auto flex items-center gap-4">
          {/* Navigation items */}
        </nav>
      </div>
    </header>
  )
}
COMP_HEADER

  cat >"$full_path/components/layout/Footer.tsx" <<'COMP_FOOTER'
import { APP_NAME } from '@/lib/constants'

export function Footer() {
  return (
    <footer className="border-t bg-background">
      <div className="container mx-auto flex h-16 items-center justify-center px-4">
        <p className="text-sm text-muted-foreground">
          © {new Date().getFullYear()} {APP_NAME}. All rights reserved.
        </p>
      </div>
    </footer>
  )
}
COMP_FOOTER

  cat >"$full_path/components/layout/index.ts" <<'COMP_LAYOUT_INDEX'
export { Header } from './Header'
export { Footer } from './Footer'
COMP_LAYOUT_INDEX

  # components/common/
  mkdir -p "$full_path/components/common"
  cat >"$full_path/components/common/LoadingSpinner.tsx" <<'COMP_SPINNER'
import { cn } from '@/lib/utils'

interface LoadingSpinnerProps {
  className?: string
  size?: 'sm' | 'md' | 'lg'
}

const sizeClasses = {
  sm: 'h-4 w-4 border-2',
  md: 'h-8 w-8 border-2',
  lg: 'h-12 w-12 border-4',
}

export function LoadingSpinner({ className, size = 'md' }: LoadingSpinnerProps) {
  return (
    <div
      role="status"
      aria-label="Loading"
      className={cn(
        'animate-spin rounded-full border-muted border-t-primary',
        sizeClasses[size],
        className
      )}
    />
  )
}
COMP_SPINNER

  cat >"$full_path/components/common/EmptyState.tsx" <<'COMP_EMPTY'
interface EmptyStateProps {
  title: string
  description?: string
  action?: React.ReactNode
}

export function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center gap-4 py-16 text-center">
      <h3 className="text-lg font-semibold">{title}</h3>
      {description && <p className="text-sm text-muted-foreground">{description}</p>}
      {action}
    </div>
  )
}
COMP_EMPTY

  cat >"$full_path/components/common/ErrorBoundary.tsx" <<'COMP_ERROR'
'use client'

import { Component, type ReactNode } from 'react'

interface Props {
  children: ReactNode
  fallback?: ReactNode
}

interface State {
  hasError: boolean
  error?: Error
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  render() {
    if (this.state.hasError) {
      return (
        this.props.fallback ?? (
          <div className="flex min-h-[200px] items-center justify-center">
            <p className="text-sm text-muted-foreground">Something went wrong.</p>
          </div>
        )
      )
    }
    return this.props.children
  }
}
COMP_ERROR

  cat >"$full_path/components/common/index.ts" <<'COMP_COMMON_INDEX'
export { LoadingSpinner } from './LoadingSpinner'
export { EmptyState } from './EmptyState'
export { ErrorBoundary } from './ErrorBoundary'
COMP_COMMON_INDEX

  print_success "components/ structure created"
}

create_features() {
  if [[ "$skip_auth" == false ]]; then
    print_info "Creating features/ structure..."
    local full_path="$project_dir/$project_name"

    # features/auth/
    mkdir -p "$full_path/features/auth/components"
    mkdir -p "$full_path/features/auth/hooks"
    mkdir -p "$full_path/features/auth/types"

    cat >"$full_path/features/auth/types/auth.types.ts" <<'FEAT_AUTH_TYPES'
export interface User {
  id: string
  name: string | null
  email: string | null
  image: string | null
}

export interface Session {
  user: User
  expires: string
}
FEAT_AUTH_TYPES

    cat >"$full_path/features/auth/hooks/use-auth.ts" <<'FEAT_AUTH_HOOKS'
'use client'

import { useSession, signIn, signOut } from 'next-auth/react'

export function useAuth() {
  const { data: session, status } = useSession()
  return {
    user: session?.user ?? null,
    isAuthenticated: status === 'authenticated',
    isLoading: status === 'loading',
    signIn: (provider?: string) => signIn(provider),
    signOut: () => signOut(),
  }
}
FEAT_AUTH_HOOKS

    cat >"$full_path/features/auth/components/LoginForm.tsx" <<'FEAT_AUTH_LOGIN'
'use client'

import { signIn } from 'next-auth/react'
import { Button } from '@/components/ui/button'

export function LoginForm() {
  return (
    <div className="flex flex-col gap-4">
      <Button onClick={() => signIn('github')} variant="outline" className="w-full">
        Sign in with GitHub
      </Button>
    </div>
  )
}
FEAT_AUTH_LOGIN

    cat >"$full_path/features/auth/index.ts" <<'FEAT_AUTH_INDEX'
export { LoginForm } from './components/LoginForm'
export { useAuth } from './hooks/use-auth'
export type { User, Session } from './types/auth.types'
FEAT_AUTH_INDEX

    print_success "features/ structure created"
  fi
}

create_app_files() {
  print_info "Creating app/ structure..."
  local full_path="$project_dir/$project_name"

  # app/layout.tsx
  cat >"$full_path/app/layout.tsx" <<'APP_LAYOUT'
import type { Metadata } from 'next'
import { Providers } from '@/lib/providers'
import { APP_NAME } from '@/lib/constants'
import './globals.css'

export const metadata: Metadata = {
  title: { template: `%s | ${APP_NAME}`, default: APP_NAME },
  description: 'Your application description',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
APP_LAYOUT

  # app/page.tsx
  cat >"$full_path/app/page.tsx" <<'APP_PAGE'
import { Header, Footer } from '@/components/layout'

export default function Home() {
  return (
    <>
      <Header />
      <main className="container mx-auto flex min-h-[calc(100vh-8rem)] flex-col items-center justify-center px-4 py-16">
        <h1 className="text-4xl font-bold">Welcome</h1>
        <p className="mt-4 text-lg text-muted-foreground">Your Next.js app is ready.</p>
      </main>
      <Footer />
    </>
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
import { LoadingSpinner } from '@/components/common'

export default function Loading() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <LoadingSpinner size="lg" />
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
      <p className="text-muted-foreground">Could not find the requested resource</p>
      <Link href="/" className="text-blue-500 hover:underline">
        Return Home
      </Link>
    </div>
  )
}
APP_NOT_FOUND

  # Auth routes (if auth)
  if [[ "$skip_auth" == false ]]; then
    mkdir -p "$full_path/app/(auth)/login"
    mkdir -p "$full_path/app/api/auth"

    cat >"$full_path/app/(auth)/layout.tsx" <<'AUTH_LAYOUT'
export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen bg-muted/50">{children}</div>
}
AUTH_LAYOUT

    cat >"$full_path/app/(auth)/login/page.tsx" <<'AUTH_LOGIN'
import { LoginForm } from '@/features/auth'

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="space-y-2 text-center">
          <h1 className="text-2xl font-bold">Sign in</h1>
          <p className="text-muted-foreground">Choose a provider to continue</p>
        </div>
        <LoginForm />
      </div>
    </main>
  )
}
AUTH_LOGIN

    cat >"$full_path/app/api/auth/[...nextauth]/route.ts" <<'AUTH_ROUTE'
import { handlers } from '@/lib/auth/config'

export const GET = handlers.GET
export const POST = handlers.POST
AUTH_ROUTE
  fi

  print_success "app/ structure created"
}

create_middleware() {
  if [[ "$skip_auth" == false ]]; then
    print_info "Creating middleware..."
    local full_path="$project_dir/$project_name"

    cat >"$full_path/middleware.ts" <<'MIDDLEWARE'
import { auth } from '@/lib/auth/config'

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
  print_info "Creating tests/ structure..."
  local full_path="$project_dir/$project_name"

  mkdir -p "$full_path/tests/fixtures"
  mkdir -p "$full_path/tests/unit/lib"
  mkdir -p "$full_path/tests/integration/components/common"

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
      include: ['app/**', 'components/**', 'features/**', 'lib/**'],
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
import { afterEach, afterAll, beforeAll, vi } from 'vitest'
import { cleanup } from '@testing-library/react'
import { setupServer } from 'msw/node'
import { handlers } from './fixtures/handlers'

export const server = setupServer(...handlers)

beforeAll(() => server.listen({ onUnhandledRequest: 'warn' }))
afterEach(() => {
  cleanup()
  server.resetHandlers()
})
afterAll(() => server.close())

vi.mock('next/navigation', () => ({
  useRouter() {
    return {
      push: vi.fn(),
      replace: vi.fn(),
      prefetch: vi.fn(),
      back: vi.fn(),
    }
  },
  useSearchParams() {
    return new URLSearchParams()
  },
  usePathname() {
    return '/'
  },
}))
TEST_SETUP

  # tests/fixtures/handlers.ts
  cat >"$full_path/tests/fixtures/handlers.ts" <<'TEST_HANDLERS'
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/health', () => {
    return HttpResponse.json({ status: 'ok' })
  }),
]
TEST_HANDLERS

  # tests/fixtures/factories.ts
  cat >"$full_path/tests/fixtures/factories.ts" <<'TEST_FACTORIES'
export function createUser(overrides: Partial<{ id: string; name: string; email: string }> = {}) {
  return {
    id: 'user-1',
    name: 'Test User',
    email: 'test@example.com',
    ...overrides,
  }
}
TEST_FACTORIES

  # tests/unit/lib/format.test.ts
  cat >"$full_path/tests/unit/lib/format.test.ts" <<'TEST_FORMAT'
import { describe, it, expect } from 'vitest'
import { formatDate, truncate } from '@/lib/format'

describe('format utilities', () => {
  describe('formatDate', () => {
    it('formats a date string', () => {
      const result = formatDate('2024-01-15')
      expect(result).toMatch(/Jan/)
    })
  })

  describe('truncate', () => {
    it('truncates long strings', () => {
      expect(truncate('Hello World', 5)).toBe('Hello...')
    })

    it('returns original string if short enough', () => {
      expect(truncate('Hi', 5)).toBe('Hi')
    })
  })
})
TEST_FORMAT

  # tests/integration/components/common/LoadingSpinner.test.tsx
  cat >"$full_path/tests/integration/components/common/LoadingSpinner.test.tsx" <<'TEST_SPINNER'
import { render, screen } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { LoadingSpinner } from '@/components/common'

describe('LoadingSpinner', () => {
  it('renders with loading status', () => {
    render(<LoadingSpinner />)
    expect(screen.getByRole('status')).toBeDefined()
  })

  it('applies size classes correctly', () => {
    const { rerender } = render(<LoadingSpinner size="sm" />)
    expect(screen.getByRole('status').className).toContain('h-4')

    rerender(<LoadingSpinner size="lg" />)
    expect(screen.getByRole('status').className).toContain('h-12')
  })
})
TEST_SPINNER

  print_success "tests/ structure created"
}

add_package_scripts() {
  print_info "Configuring package.json scripts..."
  local full_path="$project_dir/$project_name"

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

  # eslint.config.mjs (rewritten)
  cat >"$full_path/eslint.config.mjs" <<'ESLINT_CONFIG'
import { dirname } from 'path'
import { fileURLToPath } from 'url'
import { FlatCompat } from '@eslint/eslintrc'
import eslintConfigPrettier from 'eslint-config-prettier'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const compat = new FlatCompat({ baseDirectory: __dirname })

export default [
  ...compat.extends('next/core-web-vitals', 'next/typescript'),
  eslintConfigPrettier,
]
ESLINT_CONFIG

  print_success "Code quality tools configured"
}

create_env_files() {
  print_info "Creating environment files..."
  local full_path="$project_dir/$project_name"

  local auth_secret=""
  if command -v openssl &>/dev/null; then
    auth_secret=$(openssl rand -base64 32)
  else
    auth_secret=$(head -c 32 /dev/urandom | base64)
  fi

  cat >"$full_path/.env.local" <<ENV_LOCAL
AUTH_SECRET="${auth_secret}"
ENV_LOCAL

  cat >"$full_path/.env.local.example" <<'ENV_EXAMPLE'
# Authentication
AUTH_SECRET=your-generated-secret-here

# API Configuration
# NEXT_PUBLIC_API_URL=http://localhost:3000/api
ENV_EXAMPLE

  print_success "Environment files created"
}

create_docker_files() {
  if [[ "$skip_docker" == false ]]; then
    print_info "Creating Docker configuration..."
    local full_path="$project_dir/$project_name"

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

A production-ready Next.js 15 application with feature-based architecture, comprehensive testing, and commercial-grade tooling.

## Stack

- **Framework**: Next.js 15 (App Router)
- **Language**: TypeScript (strict mode)
- **Styling**: Tailwind CSS + shadcn/ui
- **State**: Zustand (client) + TanStack Query (server)
- **Auth**: Auth.js (NextAuth)
- **Testing**: Vitest + React Testing Library + MSW
- **Code Quality**: ESLint + Prettier + Husky hooks
- **CI/CD**: GitHub Actions
- **Deployment**: Docker (multi-stage build)

## Project Structure

```
app/                    # Next.js routing (pages, layouts, API routes)
components/             # Shared React components
  ├── ui/              # shadcn/ui components
  ├── layout/          # Header, Footer, etc.
  └── common/          # LoadingSpinner, ErrorBoundary, EmptyState
features/              # Self-contained feature modules (auth, etc.)
lib/                   # Core utilities and config
  ├── api/            # Type-safe API client
  ├── auth/           # Auth.js configuration
  ├── constants/      # App-wide constants
  ├── hooks/          # Shared custom hooks
  ├── providers/      # React context providers
  ├── store/          # Zustand stores
  ├── types/          # TypeScript interfaces
  ├── format.ts       # Formatting utilities
  └── utils.ts        # shadcn cn() helper
tests/                # Test infrastructure
  ├── fixtures/       # MSW handlers, test factories
  ├── unit/          # Pure function tests
  └── integration/    # Component tests
```

## Getting Started

```bash
# Install dependencies
npm install

# Set up environment
cp .env.local.example .env.local

# Run dev server
npm run dev

# Open browser
open http://localhost:3000
```

## Available Commands

```bash
npm run dev             # Start development server
npm run build           # Build for production
npm start               # Run production server

npm run type-check      # TypeScript type checking
npm run lint            # ESLint + Prettier check
npm run format          # Auto-format code

npm test                # Run all tests
npm run test:watch      # Watch mode
npm run test:coverage   # With coverage report
```

## Architecture Patterns

### Feature-Based Organization

Each feature lives in its own directory under `features/`:

```
features/auth/
  ├── components/      # Feature-specific components
  ├── hooks/          # Feature-specific hooks (e.g., useAuth)
  ├── types/          # Feature types
  └── index.ts        # Public API / barrel export
```

### API Client

Use the typed `apiClient` from `lib/api/client`:

```tsx
import { apiClient } from '@/lib/api/client'

const todos = await apiClient.get<Todo[]>('/api/todos')
const newTodo = await apiClient.post<Todo>('/api/todos', { title: 'My Todo' })
```

### State Management

**Client state** (Zustand):

```tsx
import { useUiStore } from '@/lib/store/ui.store'

const { sidebarOpen, toggleSidebar } = useUiStore()
```

**Server state** (TanStack Query):

```tsx
const { data: todos } = useQuery({
  queryKey: ['todos'],
  queryFn: () => apiClient.get<Todo[]>('/api/todos'),
})
```

### Authentication

Protected routes via middleware:

```ts
// middleware.ts - automatically runs for all routes
export const config = {
  matcher: ['/((?!api|_next/static).*)',]
}
```

Add providers in `lib/auth/config.ts`:

```ts
export const { handlers, auth } = NextAuth({
  providers: [
    GitHub({ clientId: process.env.GITHUB_ID, ... }),
  ],
})
```

### Testing

**Unit tests** (`tests/unit/`):

```tsx
import { describe, it, expect } from 'vitest'
import { formatDate } from '@/lib/format'

describe('formatDate', () => {
  it('formats dates correctly', () => {
    expect(formatDate('2024-01-15')).toMatch(/Jan/)
  })
})
```

**Integration tests** (`tests/integration/`):

```tsx
import { render, screen } from '@testing-library/react'
import { LoadingSpinner } from '@/components/common'

it('renders spinner', () => {
  render(<LoadingSpinner />)
  expect(screen.getByRole('status')).toBeDefined()
})
```

### Code Quality

Automatic code formatting and linting via pre-commit hooks (Husky):

```bash
git add .
git commit -m "feat: add feature"
# Husky runs: prettier --write, eslint --fix
```

## Deployment

### Vercel (Recommended)

```bash
git push  # GitHub Actions runs tests, Vercel auto-deploys on merge
```

### Docker

```bash
docker build -t myapp .
docker run -p 3000:3000 -e AUTH_SECRET=secret myapp
```

### Environment Variables

Copy `.env.local.example` to `.env.local` and fill in:

- `AUTH_SECRET` (auto-generated during setup)
- `GITHUB_ID` / `GITHUB_SECRET` (if using GitHub auth)
- `NEXT_PUBLIC_API_URL` (if using external API)

## Contributing

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make changes + add tests
3. Commit: `git commit -m "feat: description"`
4. Pre-commit hooks auto-lint and format
5. Push + open PR

## Resources

- [Next.js Docs](https://nextjs.org/docs)
- [TanStack Query](https://tanstack.com/query/latest)
- [Zustand](https://github.com/pmndrs/zustand)
- [shadcn/ui](https://ui.shadcn.com)
- [Auth.js](https://authjs.dev)
- [Vitest](https://vitest.dev)

## License

MIT
README_TEMPLATE

  sed -i "s/PROJECT_NAME/$project_name/g" "$full_path/README.md"

  print_success "README created"
}

initialize_git() {
  print_info "Initializing git repository..."
  local full_path="$project_dir/$project_name"

  run_cmd git -C "$full_path" init
  run_cmd git -C "$full_path" config user.name "$(git config user.name || echo 'Rich Taft')"
  run_cmd git -C "$full_path" config user.email "$(git config user.email || echo 'rt2726@gmail.com')"

  if [[ ! -f "$full_path/.gitignore" ]]; then
    cat >"$full_path/.gitignore" <<'GITIGNORE'
node_modules/
.next/
.env.local
dist/
build/
coverage/
*.log
.DS_Store
GITIGNORE
  fi

  run_cmd git -C "$full_path" add .
  run_cmd git -C "$full_path" commit -m "Initial commit: Production-ready Next.js scaffold

- Feature-based architecture (features/ for scalable apps)
- Organized lib/ with api/, auth/, constants/, hooks/, providers/, store/, types/
- Structured components/ with layout/, common/, and shadcn/ui
- Professional test structure: fixtures/, unit/, integration/
- TypeScript strict mode + ESLint + Prettier
- Vitest + React Testing Library + MSW
- Auth.js pre-configured with middleware
- TanStack Query for server state + Zustand for client state
- Docker multi-stage build
- GitHub Actions CI/CD
- Full test infrastructure with examples"

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
    print_warning "Claude CLI not found. Run manually:"
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
  create_components
  create_features
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
  echo "  3. Open http://localhost:3000"
  echo
  print_info "Key commands:"
  echo "  npm run dev         - Development server"
  echo "  npm test            - Run tests"
  echo "  npm run lint        - Check code quality"
  echo "  npm run type-check  - TypeScript validation"
  echo "  npm run build       - Production build"
  echo
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
