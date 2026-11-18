<script setup lang="ts">
import { ArrowUpRight } from 'lucide-vue-next'
import { pluralArticles } from '~/utils/admin-categories'
import type { AuthorCounts, SiteAuthor } from '~/utils/admin-authors'

/** The site author, fixed on top of the list (no order, no delete): it lives in Ajustes because it is also «Sobre mí». */
defineProps<{ site: SiteAuthor; counts: AuthorCounts }>()
</script>

<template>
  <section aria-labelledby="h-site">
    <h2 id="h-site" class="text-sm font-semibold">Autor del sitio</h2>
    <p class="mt-0.5 text-xs text-adm-meta">Firma por defecto: todo artículo sin autor asignado. Se edita en Ajustes porque también es «Sobre mí».</p>
    <div :class="[admCard, 'mt-3 flex items-center gap-3 px-3 py-2.5']">
      <AdminAuthorsAvatar :media="site.photo" :name="site.name ?? ''" />
      <div class="min-w-0 flex-1">
        <p class="truncate text-sm font-medium">
          {{ site.name || 'Sin nombre todavía' }}
          <span class="ml-1 rounded bg-adm-subtle px-1.5 py-0.5 align-middle text-[11px] font-medium text-adm-meta">Por defecto</span>
        </p>
        <p class="truncate text-xs text-adm-meta">{{ site.role_es || 'Sin rol' }}</p>
      </div>
      <span class="hidden text-xs text-adm-meta tabular-nums sm:inline">{{ counts.total ? pluralArticles(counts.total) : 'Sin artículos' }}</span>
      <AdminAuthorsEnBadge :role="site.role_en" :bio="site.bio_en" class="max-sm:hidden" />
      <NuxtLink :to="`${adminPath('ajustes')}#autor`" :class="[admBtnGhost, 'max-md:min-h-11']">
        <span class="max-sm:hidden">Editar en Ajustes</span><span class="sm:hidden">Ajustes</span><ArrowUpRight aria-hidden="true" />
      </NuxtLink>
    </div>
  </section>
</template>
