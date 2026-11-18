<script setup lang="ts">
import { ArrowLeft, ArrowRight } from 'lucide-vue-next'

/**
 * Pager (§15.2): "Más recientes / Anteriores" as 44 px bordered buttons and mono numbers (the current
 * one in ink); in 390 px "1 / 5". The disabled arrow is `muted` (5.13:1), not opacity. `?pagina=N`
 * keeps the other query keys; page 1 has no `pagina`.
 */
const props = defineProps<{ page: number; pages: number }>()
const { t } = useI18n()
const route = useRoute()

function href(n: number) {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(route.query)) {
    if (key !== 'pagina' && typeof value === 'string') query.set(key, value)
  }
  if (n > 1) query.set('pagina', String(n))
  const qs = query.toString()
  return qs ? `${route.path}?${qs}` : route.path
}
const items = computed(() => pagerItems(props.page, props.pages))
const button =
  'inline-flex h-11 min-w-11 items-center justify-center gap-1.5 rounded-md border border-control px-3.5 text-body-sm font-medium'
</script>

<template>
  <nav v-if="pages > 1" :aria-label="t('news.pager.label')" class="mx-auto max-w-page px-4 pt-10 pb-20 md:px-6 md:pb-28">
    <div class="flex items-center justify-between gap-2 border-t border-line-strong pt-6">
      <NuxtLink v-if="page > 1" :to="href(page - 1)" rel="prev" :class="[button, 'hover:bg-elevated']">
        <ArrowLeft :size="16" aria-hidden="true" />
        <span class="max-sm:sr-only">{{ t('news.pager.newer') }}</span>
      </NuxtLink>
      <span v-else aria-disabled="true" :class="[button, 'border-line-strong text-muted']">
        <ArrowLeft :size="16" aria-hidden="true" />
        <span class="max-sm:sr-only">{{ t('news.pager.newer') }}</span>
      </span>
      <span class="font-mono text-caption text-meta sm:hidden">{{ t('news.pager.of', { current: page, total: pages }) }}</span>
      <ol class="hidden items-center gap-1 sm:flex">
        <li v-for="(n, i) in items" :key="i">
          <span v-if="n === null" aria-hidden="true" class="grid h-11 min-w-11 place-items-center font-mono text-caption">…</span>
          <span
            v-else-if="n === page"
            aria-current="page"
            class="grid h-11 min-w-11 place-items-center rounded-md bg-foreground px-2 font-mono text-caption text-background"
          >{{ n }}</span>
          <NuxtLink
            v-else
            :to="href(n)"
            :aria-label="t('news.pager.goTo', { n })"
            class="grid h-11 min-w-11 place-items-center rounded-md px-2 font-mono text-caption hover:bg-elevated"
          >{{ n }}</NuxtLink>
        </li>
      </ol>
      <NuxtLink v-if="page < pages" :to="href(page + 1)" rel="next" :class="[button, 'hover:bg-elevated']">
        <span class="max-sm:sr-only">{{ t('news.pager.older') }}</span>
        <ArrowRight :size="16" aria-hidden="true" />
      </NuxtLink>
      <span v-else aria-disabled="true" :class="[button, 'border-line-strong text-muted']">
        <span class="max-sm:sr-only">{{ t('news.pager.older') }}</span>
        <ArrowRight :size="16" aria-hidden="true" />
      </span>
    </div>
  </nav>
</template>
