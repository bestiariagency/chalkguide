<script setup lang="ts">
import { Menu, Search } from 'lucide-vue-next'

/** Top bar under 768: menu drawer, logo and the ⌘K search button. */
const { open, toggle } = useAdminMenu()
const { openPalette } = useAdminPalette()
</script>

<template>
  <div class="sticky top-0 z-30 flex h-14 items-center gap-1 border-b border-adm-line bg-adm-bg px-1 md:hidden">
    <button
      type="button"
      :class="admIconBtn"
      aria-label="Abrir menú"
      aria-controls="admin-sidebar"
      :aria-expanded="open"
      @click="toggle"
    >
      <Menu class="!size-5" aria-hidden="true" />
    </button>
    <img src="/brand/logo-dark.svg" alt="ChalkGuide" class="h-3.5 w-auto" width="100" height="14" />
    <button
      type="button"
      aria-label="Buscar o ir a…"
      aria-haspopup="dialog"
      :class="[admIconBtn, 'ml-auto']"
      @click="openPalette"
    >
      <Search class="!size-5" aria-hidden="true" />
    </button>
  </div>
</template>
