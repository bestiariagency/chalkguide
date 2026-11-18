<script setup lang="ts">
import { ArrowLeft, ExternalLink, Upload } from 'lucide-vue-next'
import type { SaveState } from '~/composables/useArticleAutosave'
import type { ItemInfo } from '~/utils/item-spec'

/** Editor top bar: back, crumbs, status, save indicator and the publication actions. */
defineProps<{
  info: ItemInfo
  name: string
  live: boolean
  hidden: boolean
  slug: string
  changes: number
  save: { state: SaveState; savedAt: number | null; message: string }
  busy: boolean
  canPublish: boolean
}>()
defineEmits<{ retry: []; publish: []; 'publish-changes': []; changes: []; discard: []; hide: [] }>()
</script>

<template>
  <header class="sticky top-14 z-30 flex h-12 items-center gap-2 border-b border-adm-line bg-adm-bg px-2 text-sm md:top-0 md:px-4">
    <NuxtLink :to="adminPath(info.route)" :class="admIconBtn" :aria-label="`Volver a ${info.nouns}`"><ArrowLeft aria-hidden="true" /></NuxtLink>
    <nav aria-label="Migas" class="hidden items-center gap-2 text-[13px] text-adm-meta lg:flex">
      <NuxtLink :to="adminPath(info.route)" class="hover:text-adm-fg">{{ info.title }}</NuxtLink><span aria-hidden="true">/</span>
      <span class="max-w-60 truncate text-adm-fg" aria-current="page">{{ name || 'Sin nombre' }}</span>
    </nav>
    <span class="min-w-0 truncate font-medium lg:hidden">{{ name || 'Sin nombre' }}</span>
    <AdminStatusChip :status="live ? (changes ? 'revised' : 'published') : hidden ? 'hidden' : 'draft'" :changes="changes" :label="itemChipLabel(live ? (changes ? 'revised' : 'published') : hidden ? 'hidden' : 'draft')" class="ml-1 flex-none" />
    <div class="hidden flex-none xl:block"><AdminEditorSaveStatus :state="save.state" :saved-at="save.savedAt" :message="save.message" @retry="$emit('retry')" /></div>
    <div class="ml-auto flex flex-none items-center gap-1.5">
      <a v-if="live" :href="`${info.publicPath}/${slug}`" target="_blank" rel="noopener" :class="[admBtnGhost, 'max-lg:hidden']"><ExternalLink aria-hidden="true" />Ver en el sitio<span class="sr-only"> (se abre en otra pestaña)</span></a>
      <AdminEditorPublishMenu v-if="live" class="max-md:hidden" live no-preview unpublish-label="Ocultar ficha…" :changes="changes" :busy="busy" @primary="$emit('publish-changes')" @changes="$emit('changes')" @discard="$emit('discard')" @unpublish="$emit('hide')" />
      <button v-else type="button" :class="[admBtnPrimary, 'max-md:hidden']" :disabled="busy" :aria-disabled="!canPublish || undefined" @click="$emit('publish')"><Upload aria-hidden="true" />Publicar</button>
    </div>
  </header>
</template>
