<script setup lang="ts">
import { ExternalLink, LogOut, Plus, Search, X } from 'lucide-vue-next'

/**
 * Panel menu (docs/design/admin/arquitectura.html): 240 px from 1280, 56 px rail 768-1279,
 * drawer under 768. Search (⌘K) opens the palette and "Nuevo" the create sheet.
 */
const route = useRoute()
const { open, close } = useAdminMenu()
const { logout } = useAdminAuth()
const { openPalette, openNew } = useAdminPalette()
const user = useSupabaseUser()
const closeButton = ref<HTMLButtonElement>()

const reviews = useAdminReviewsBadge()
const events = useAdminEventsBadge()
const news = useAdminNewsBadge()
onMounted(() => {
  void reviews.refresh()
  void events.refresh()
  void news.refresh()
})
// New reviews keep arriving while the panel is open: re-count when moving around (the Opiniones page resets it).
watch(() => route.path, (path) => {
  if (!path.startsWith(adminPath('opiniones'))) void reviews.refresh()
  if (!path.startsWith(adminPath('agenda'))) void events.refresh()
  if (!path.startsWith(adminPath('noticias')) && !path.startsWith(adminPath('ingesta'))) void news.refresh()
})
const badgeOf = (slug: string) => (slug === 'opiniones' ? reviews.count.value : slug === 'agenda' ? events.count.value : slug === 'noticias' ? news.count.value : 0)
const BADGE_NOUN: Record<string, string> = { agenda: 'por aprobar', noticias: 'por revisar' }

// Drawer (< 768) as a dialog: focus moves in and comes back, the page behind does not scroll (the layout makes it inert).
let opener: HTMLElement | null = null
watch(open, (isOpen) => {
  document.body.style.overflow = isOpen ? 'hidden' : ''
  if (isOpen) {
    opener = document.activeElement instanceof HTMLElement ? document.activeElement : null
    closeButton.value?.focus()
  } else {
    opener?.focus()
    opener = null
  }
}, { flush: 'post' })
onMounted(() => {
  const wide = window.matchMedia('(min-width: 768px)')
  const onChange = () => wide.matches && close()
  wide.addEventListener('change', onChange)
  onBeforeUnmount(() => {
    wide.removeEventListener('change', onChange)
    document.body.style.overflow = ''
  })
})

const email = computed(() => (user.value as { email?: string } | null)?.email ?? '')
const loggingOut = ref(false)

function isActive(slug: string) {
  const path = adminPath(slug)
  return slug ? route.path === path || route.path.startsWith(`${path}/`) : route.path === path
}

async function signOut() {
  loggingOut.value = true
  try {
    await logout()
  } finally {
    loggingOut.value = false
    await navigateTo(ADMIN_LOGIN)
  }
}
</script>

<template>
  <div v-if="open" class="fixed inset-0 z-40 bg-adm-scrim md:hidden" aria-hidden="true" @click="close" />
  <aside
    id="admin-sidebar"
    aria-label="Menú del panel"
    :role="open ? 'dialog' : undefined"
    :aria-modal="open ? 'true' : undefined"
    :class="[
      'fixed top-0 z-50 flex h-dvh w-[280px] flex-none flex-col border-r border-adm-line bg-adm-side',
      'transition-[transform,visibility] duration-200 motion-reduce:transition-none md:sticky md:h-screen md:w-14 md:translate-x-0 md:visible xl:w-60',
      open ? 'translate-x-0' : '-translate-x-full max-md:invisible',
    ]"
  >
    <div class="flex h-12 flex-none items-center gap-2 border-b border-adm-line px-3 xl:px-4">
      <img src="/brand/logo-dark.svg" alt="ChalkGuide" class="h-[15px] w-auto md:hidden xl:block" width="107" height="15" />
      <AdminIso class="mx-auto hidden size-5 text-adm-fg md:block xl:hidden" />
      <span :class="[admGroupLabel, 'ml-auto md:hidden xl:inline']">Admin</span>
      <button ref="closeButton" type="button" :class="[admIconBtn, 'md:hidden']" aria-label="Cerrar menú" @click="close">
        <X aria-hidden="true" />
      </button>
    </div>

    <div class="flex-none space-y-2 p-2 xl:p-3">
      <button
        type="button"
        aria-label="Buscar o ir a… (⌘K)"
        aria-keyshortcuts="Meta+K Control+K"
        class="flex h-8 w-full items-center gap-2 rounded-md border border-adm-line-strong bg-adm-elev px-2.5 text-[13px] text-adm-muted hover:border-adm-control hover:text-adm-fg max-md:h-11 md:justify-center xl:justify-start"
        @click="openPalette"
      >
        <Search class="size-4" aria-hidden="true" />
        <span class="md:hidden xl:inline">Buscar o ir a…</span>
        <span :class="[admKbd, 'ml-auto max-md:hidden md:hidden xl:inline']" aria-hidden="true">⌘K</span>
      </button>
      <button
        type="button"
        aria-label="Nuevo"
        :class="[admBtnPrimary, 'w-full md:px-0 xl:justify-start xl:px-3']"
        @click="openNew"
      >
        <Plus aria-hidden="true" />
        <span class="md:hidden xl:inline">Nuevo</span>
      </button>
    </div>

    <nav class="flex-1 overflow-y-auto px-2 pb-3 xl:px-3" aria-label="Secciones">
      <template v-for="group in ADMIN_NAV" :key="group.label ?? 'inicio'">
        <template v-if="group.label">
          <p :class="[admGroupLabel, 'mt-4 mb-1 px-2.5 md:hidden xl:block']">{{ group.label }}</p>
          <hr class="my-2 hidden border-adm-line md:block xl:hidden" />
        </template>
        <NuxtLink
          v-for="item in group.items"
          :key="item.slug"
          :to="adminPath(item.slug)"
          :class="admNavItem"
          :title="item.label"
          :aria-current="isActive(item.slug) ? 'page' : undefined"
        >
          <component :is="item.icon" aria-hidden="true" />
          <span class="md:sr-only xl:not-sr-only">{{ item.label }}</span>
          <template v-if="badgeOf(item.slug)">
            <span class="ml-auto rounded-full bg-adm-acc-soft px-1.5 text-[11px] leading-[18px] font-medium text-adm-acc tabular-nums md:absolute md:top-0 md:right-0 md:ml-0 md:px-1 xl:static xl:ml-auto xl:px-1.5" aria-hidden="true">{{ badgeOf(item.slug) }}</span>
            <span class="sr-only">, {{ badgeOf(item.slug) }} {{ BADGE_NOUN[item.slug] ?? (badgeOf(item.slug) === 1 ? 'nueva' : 'nuevas') }}</span>
          </template>
          <template v-else-if="item.slug === 'ingesta' && news.ingestFailing.value">
            <span class="ml-auto size-2 rounded-full bg-adm-danger md:absolute md:top-1 md:right-1 md:ml-0 xl:static xl:ml-auto" aria-hidden="true" />
            <span class="sr-only">, la salud de la rutina falla</span>
          </template>
        </NuxtLink>
      </template>
    </nav>

    <div class="flex-none space-y-0.5 border-t border-adm-line p-2 xl:p-3">
      <NuxtLink
        :to="adminPath(ADMIN_SETTINGS.slug)"
        :class="admNavItem"
        :title="ADMIN_SETTINGS.label"
        :aria-current="isActive(ADMIN_SETTINGS.slug) ? 'page' : undefined"
      >
        <component :is="ADMIN_SETTINGS.icon" aria-hidden="true" />
        <span class="md:sr-only xl:not-sr-only">{{ ADMIN_SETTINGS.label }}</span>
      </NuxtLink>
      <a href="/" target="_blank" rel="noopener" :class="admNavItem" title="Ver sitio (se abre en otra pestaña)">
        <ExternalLink aria-hidden="true" />
        <span class="md:sr-only xl:not-sr-only">Ver sitio<span class="sr-only"> (se abre en otra pestaña)</span></span>
      </a>
      <div class="flex h-10 items-center gap-2 px-1.5 md:justify-center xl:justify-start">
        <span
          class="grid size-6 flex-none place-items-center rounded-full bg-adm-primary text-[11px] font-medium text-adm-on-primary"
          aria-hidden="true"
        >
          {{ (email[0] ?? 'A').toUpperCase() }}
        </span>
        <span class="min-w-0 leading-4 md:hidden xl:block">
          <span class="block truncate text-[13px] text-adm-fg">{{ email || 'Superadmin' }}</span>
          <span class="block text-[11px] text-adm-muted">Superadmin</span>
        </span>
        <button
          type="button"
          :class="[admIconBtn, 'ml-auto md:hidden xl:inline-grid']"
          aria-label="Cerrar sesión"
          :aria-busy="loggingOut"
          :disabled="loggingOut"
          @click="signOut"
        >
          <LogOut aria-hidden="true" />
        </button>
      </div>
      <button
        type="button"
        :class="[admNavItem, 'hidden w-full md:flex xl:hidden']"
        title="Cerrar sesión"
        :disabled="loggingOut"
        @click="signOut"
      >
        <LogOut aria-hidden="true" />
        <span class="sr-only">Cerrar sesión</span>
      </button>
    </div>
  </aside>
</template>
