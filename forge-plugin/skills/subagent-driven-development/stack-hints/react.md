# React / Next.js Stack Hints

Inject when `.forge/conventions.yml` has framework including `react`, `nextjs`, or `next`.

## Component Patterns

- Functional components only (no class components)
- Props interface above component: `interface Props { ... }`
- Destructure props: `function Card({ title, children }: Props)`
- Composition over configuration — slots via `children` and render props
- `React.memo()` only after measuring, not by default
- Keep components under ~100 lines — extract when they have their own state/logic

## Hooks

- `useState` for simple local state
- `useReducer` for complex state with multiple actions
- `useMemo` / `useCallback` — only when passing to `memo`'d children or expensive computation
- Custom hooks for reusable logic: `useDebounce`, `useLocalStorage`, `useMediaQuery`
- Never call hooks conditionally or in loops

## State Management

- Server state: `TanStack Query` (React Query) — caching, revalidation, optimistic updates
- Client state: `zustand` (simple) or `jotai` (atomic) — not Redux for new projects
- Form state: `react-hook-form` + Zod validation
- URL state: search params via `nuqs` or `useSearchParams`

## Next.js (if applicable)

- App Router over Pages Router for new projects
- Server Components by default — add `'use client'` only when needed (hooks, events, browser APIs)
- Server Actions for mutations: `'use server'` functions
- `loading.tsx` for suspense boundaries, `error.tsx` for error boundaries
- `generateMetadata()` for dynamic SEO
- Route groups `(marketing)` for shared layouts without URL segments
- `unstable_cache` / `revalidateTag` for fine-grained cache control

## Testing

- `@testing-library/react` — test behavior, not implementation
- `render()` + `screen.getByRole()` — query by accessibility role, not test IDs
- `userEvent` over `fireEvent` (simulates real user interaction)
- `MSW` (Mock Service Worker) for API mocking in tests
- Don't test internal state — test what the user sees

## Accessibility

- Semantic HTML: `<button>` not `<div onClick>`, `<nav>` not `<div class="nav">`
- `aria-label` on icon-only buttons
- `cursor-pointer` on all clickable elements
- Focus visible styles (`outline`, not `outline: none`)
- Color contrast 4.5:1 minimum (WCAG AA)
- `prefers-reduced-motion` for animations

## Performance

- Dynamic imports: `const Heavy = dynamic(() => import('./Heavy'), { ssr: false })`
- Image optimization: `<Image>` component (Next.js) or lazy loading
- Virtualize long lists: `@tanstack/react-virtual`
- Bundle analysis: `@next/bundle-analyzer`
- Core Web Vitals targets: LCP <2.5s, FID <100ms, CLS <0.1
