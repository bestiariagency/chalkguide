<script setup lang="ts">
import '~/assets/css/admin.css'
import '@fontsource/inter/latin-600.css'
/**
 * Panel layout (D23, docs/design/admin): own `.admin` token scope, light theme only (dark tokens
 * ready, no switch). Independent from the public site layout and its components.
 */
useAdminHead('Panel')
useAdminShortcuts()
const route = useRoute()
// Drawer open under 768: the rest of the page is inert (focus stays in the menu).
const { open: menuOpen } = useAdminMenu()
</script>

<template>
  <div class="admin flex min-h-dvh bg-adm-bg font-sans text-[14px] leading-[22px] text-adm-fg antialiased">
    <a
      href="#contenido"
      :inert="menuOpen || undefined"
      :class="[admBtnPrimary, 'sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[100]']"
    >
      Saltar al contenido
    </a>
    <AdminSidebar />
    <div class="flex min-w-0 flex-1 flex-col" :inert="menuOpen || undefined">
      <AdminMobileBar />
      <main id="contenido" tabindex="-1" :class="['flex-1 focus-visible:outline-none', route.meta.adminEditor ? '' : 'pb-16 md:pb-0']">
        <slot />
      </main>
      <AdminBottomNav v-if="!route.meta.adminEditor" />
    </div>
    <NuxtLoadingIndicator :throttle="150" :height="2" color="var(--adm-acc)" />
    <AdminToaster />
    <AdminCommandPalette />
    <AdminNewSheet />
  </div>
</template>
