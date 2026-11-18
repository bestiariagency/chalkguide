<script setup lang="ts">
import { Image, LayoutDashboard, MessageSquare, Plus } from 'lucide-vue-next'

/** Bottom bar under 768: Inicio, Opiniones, Medios and Nuevo (opens the create sheet). */
const route = useRoute()
const { openNew } = useAdminPalette()
const reviews = useAdminReviewsBadge()
const links = [
  { slug: '', label: 'Inicio', icon: LayoutDashboard },
  { slug: 'opiniones', label: 'Opiniones', icon: MessageSquare },
  { slug: 'medios', label: 'Medios', icon: Image },
]
const isActive = (slug: string) =>
  slug ? route.path.startsWith(adminPath(slug)) : route.path === adminPath(slug)
const item = 'flex min-h-11 flex-col items-center justify-center gap-1'
</script>

<template>
  <nav
    aria-label="Accesos rápidos"
    class="fixed inset-x-0 bottom-0 z-30 grid h-16 grid-cols-4 border-t border-adm-line bg-adm-bg pb-[env(safe-area-inset-bottom)] text-[11px] md:hidden"
  >
    <NuxtLink
      v-for="link in links"
      :key="link.slug"
      :to="adminPath(link.slug)"
      :class="[item, isActive(link.slug) ? 'font-medium text-adm-fg' : 'text-adm-meta']"
      :aria-current="isActive(link.slug) ? 'page' : undefined"
    >
      <span class="relative">
        <component :is="link.icon" :class="['size-5', isActive(link.slug) && 'text-adm-acc']" aria-hidden="true" />
        <span v-if="link.slug === 'opiniones' && reviews.count.value" class="absolute -top-1.5 -right-2.5 rounded-full bg-adm-acc px-1 text-[11px] leading-4 font-medium text-white tabular-nums" aria-hidden="true">{{ reviews.count.value }}</span>
      </span>
      {{ link.label }}<span v-if="link.slug === 'opiniones' && reviews.count.value" class="sr-only">, {{ reviews.count.value }} nuevas</span>
    </NuxtLink>
    <button
      type="button"
      aria-label="Nuevo"
      :class="[item, 'text-adm-meta']"
      @click="openNew"
    >
      <span class="-my-0.5 grid size-7 place-items-center rounded-lg bg-adm-primary text-adm-on-primary">
        <Plus class="size-4" aria-hidden="true" />
      </span>
      Nuevo
    </button>
  </nav>
</template>
