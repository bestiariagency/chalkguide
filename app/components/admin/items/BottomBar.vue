<script setup lang="ts">
import { ExternalLink, Upload } from 'lucide-vue-next'
import type { ItemInfo } from '~/utils/item-spec'

/** Editor bottom bar under 768 px: view on the site and the publication action. */
defineProps<{ info: ItemInfo; live: boolean; slug: string; changes: number; busy: boolean }>()
defineEmits<{ publish: []; changes: []; discard: []; hide: [] }>()
</script>

<template>
  <div class="fixed inset-x-0 bottom-0 z-40 flex gap-2 border-t border-adm-line bg-adm-bg px-3 pt-2 pb-[calc(8px+env(safe-area-inset-bottom))] md:hidden">
    <a v-if="live" :href="`${info.publicPath}/${slug}`" target="_blank" rel="noopener" :class="[admBtnGhost, 'flex-none']"><ExternalLink aria-hidden="true" />Ver<span class="sr-only"> en el sitio (se abre en otra pestaña)</span></a>
    <AdminEditorPublishMenu v-if="live" block live no-preview unpublish-label="Ocultar ficha…" :changes="changes" :busy="busy" @primary="$emit('changes')" @changes="$emit('changes')" @discard="$emit('discard')" @unpublish="$emit('hide')" />
    <button v-else type="button" :class="[admBtnPrimary, 'flex-1']" :disabled="busy" @click="$emit('publish')"><Upload aria-hidden="true" />Publicar</button>
  </div>
</template>
