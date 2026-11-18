/**
 * Guard for /administrador/** (UX only: the real protection is RLS, .ai/security-rls.md).
 * - no session → login with a validated `next`;
 * - session without guide.is_admin() → out of the panel (the site home);
 * - the login page itself is public, but an admin who is already in goes straight to `next`.
 * - the components showcase (/administrador/componentes, D54) follows the same rule as the rest: admins only.
 * The panel is a SPA (ssr: false), so this always runs in the browser.
 */
export default defineNuxtRouteMiddleware(async (to) => {
  if (to.path !== ADMIN_BASE && !to.path.startsWith(`${ADMIN_BASE}/`)) return

  // The recovery link lands here with a recovery session, not an admin one: public page.
  if (to.path === ADMIN_RESET) return

  const isLogin = to.path === ADMIN_LOGIN
  const { checkAdmin } = useAdminAuth()

  let isAdmin: boolean | null
  try {
    isAdmin = await checkAdmin()
  } catch {
    // Could not verify (network): treat as no access rather than showing the panel.
    isAdmin = isLogin ? null : false
  }

  if (isLogin) {
    return isAdmin ? navigateTo(adminNextPath(to.query.next), { replace: true }) : undefined
  }
  if (isAdmin === null) {
    const next = adminNextPath(to.fullPath)
    return navigateTo({ path: ADMIN_LOGIN, query: next === ADMIN_BASE ? {} : { next } }, { replace: true })
  }
  if (!isAdmin) return navigateTo('/', { replace: true })
})
