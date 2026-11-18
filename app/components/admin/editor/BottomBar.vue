<script setup lang="ts">
import { Eye, SlidersHorizontal } from 'lucide-vue-next'

/** Editor bottom bar under 768 px: settings, preview and the split publication button (menu opens upwards). */
defineProps<{ live: boolean; changes: number; scheduled?: boolean; busy: boolean; settingsOpen: boolean; unpublishDisabled?: string; publishBlocked?: boolean }>()
defineEmits<{ settings: []; preview: []; primary: []; changes: []; discard: []; copy: []; unpublish: []; draft: [] }>()
</script>

<template>
  <div class="fixed inset-x-0 bottom-0 z-40 flex gap-2 border-t border-adm-line bg-adm-bg px-3 pt-2 pb-[calc(8px+env(safe-area-inset-bottom))] md:hidden">
    <button type="button" :class="[admBtnGhost, 'flex-none']" :aria-expanded="settingsOpen" @click="$emit('settings')"><SlidersHorizontal aria-hidden="true" />Ajustes</button>
    <button type="button" :class="[admBtnGhost, 'size-11 flex-none px-0']" aria-label="Vista previa" :disabled="busy" @click="$emit('preview')"><Eye aria-hidden="true" /></button>
    <AdminEditorPublishMenu
      block
      :live="live"
      :changes="changes"
      :scheduled="scheduled"
      :busy="busy"
      :unpublish-disabled="unpublishDisabled"
      :blocked="publishBlocked"
      @primary="$emit('primary')"
      @changes="$emit('changes')"
      @discard="$emit('discard')"
      @copy="$emit('copy')"
      @unpublish="$emit('unpublish')"
      @draft="$emit('draft')"
    />
  </div>
</template>
