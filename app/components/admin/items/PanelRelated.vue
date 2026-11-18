<script setup lang="ts">
import { FileText } from 'lucide-vue-next'
import type { ItemRelatedArticle } from '~/services/admin/item-editor'

/** Relacionados (read-only for now): articles that carry this item's card, from `article_items`. */
defineProps<{ articles: ItemRelatedArticle[]; noun: string }>()
</script>

<template>
  <AdminItemsSection :title="`Artículos que hablan de este ${noun}`" description="Salen al final de la ficha como «Lo he contado aquí». Se añaden solos cuando un artículo inserta su tarjeta; para quitarlos, edita el artículo.">
    <ul v-if="articles.length" class="divide-y divide-adm-line rounded-lg border border-adm-line bg-adm-elev text-sm">
      <li v-for="article in articles" :key="article.id" class="flex min-h-11 items-center gap-3 px-3">
        <FileText class="size-4 flex-none text-adm-meta" aria-hidden="true" />
        <NuxtLink :to="adminPath(`articulos/${article.id}`)" class="flex-1 truncate underline-offset-2 hover:underline">{{ article.title }}</NuxtLink>
        <AdminStatusChip :status="article.live ? 'published' : 'draft'" />
      </li>
    </ul>
    <p v-else class="rounded-lg border border-dashed border-adm-line-strong p-6 text-center text-sm text-adm-meta">Ningún artículo enlaza esta ficha todavía.</p>
  </AdminItemsSection>
</template>
