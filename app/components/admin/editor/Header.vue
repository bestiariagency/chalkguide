<script setup lang="ts">
import { TabsList, TabsRoot, TabsTrigger } from 'reka-ui'
import { ArrowLeft, CalendarClock, Eye, PanelRight, Undo2 } from 'lucide-vue-next'
import type { SaveState } from '~/composables/useArticleAutosave'
import type { ArticleDisplay } from '~/utils/admin-articles'
import type { FormLocale } from '~/utils/article-form'

/** Editor top bar: back, crumbs, status, save indicator, ES/EN switch and publication actions. */
withDefaults(defineProps<{
  title: string
  display: ArticleDisplay
  readonly: boolean
  save: { state: SaveState; savedAt: number | null; message: string }
  enIncomplete: boolean
  busy: boolean
  settingsOpen: boolean
  /** Published article: edits go to a draft of changes (`changes` of them) and the action is "Publicar cambios". */
  live: boolean
  changes: number
  /** Where the editor belongs (default: Artículos). Pages pass their own list. */
  section?: { slug: string; label: string }
  /** Label of the settings button (default: article). */
  settingsLabel?: string
  /** No scheduling (pages publish at once). */
  noSchedule?: boolean
  /** Reason why "Despublicar" is unavailable (legal pages). */
  unpublishDisabled?: string
  /** Replaces the status text (pages: "Publicada", "Sin contenido"). */
  statusLabel?: string
  /** Not-published item with nothing to publish yet: the main button is disabled. */
  publishBlocked?: boolean
}>(), { statusLabel: undefined, publishBlocked: false, section: () => ({ slug: 'articulos', label: 'Artículos' }), settingsLabel: 'Ajustes del artículo', unpublishDisabled: undefined })
const emit = defineEmits<{
  retry: []
  publish: [mode: 'now' | 'schedule']
  draft: []
  settings: []
  preview: []
  'publish-changes': []
  changes: []
  discard: []
  copy: []
  unpublish: []
}>()
const primary = (live: boolean) => (live ? emit('publish-changes') : emit('publish', 'now'))
const lang = defineModel<FormLocale>('lang', { required: true })
</script>

<template>
  <header class="sticky top-14 z-30 flex h-12 items-center gap-2 border-b border-adm-line bg-adm-bg px-2 text-sm md:top-0 md:px-4">
    <NuxtLink :to="adminPath(section.slug)" :class="admIconBtn" :aria-label="`Volver a ${section.label.toLowerCase()}`"><ArrowLeft aria-hidden="true" /></NuxtLink>
    <nav aria-label="Migas" class="hidden items-center gap-2 text-[13px] text-adm-meta lg:flex">
      <NuxtLink :to="adminPath(section.slug)" class="hover:text-adm-fg">{{ section.label }}</NuxtLink><span aria-hidden="true">/</span>
      <span class="max-w-60 truncate text-adm-fg" aria-current="page">{{ title || 'Sin título' }}</span>
    </nav>
    <AdminStatusChip :status="live && changes ? 'revised' : display" :changes="changes" :label="statusLabel" class="ml-1 flex-none" />
    <div class="hidden flex-none xl:block"><AdminEditorSaveStatus :state="save.state" :saved-at="save.savedAt" :message="save.message" :readonly="readonly" @retry="$emit('retry')" /></div>
    <div class="ml-auto flex flex-none items-center gap-1.5">
      <TabsRoot v-model="lang" activation-mode="manual">
        <TabsList aria-label="Idioma del contenido" class="inline-flex rounded-md bg-adm-subtle p-0.5">
          <TabsTrigger value="es" class="h-7 rounded px-2.5 text-[13px] font-medium text-adm-meta data-[state=active]:bg-adm-elev data-[state=active]:text-adm-fg data-[state=active]:shadow-sm max-md:h-11">ES</TabsTrigger>
          <TabsTrigger value="en" class="inline-flex h-7 items-center gap-1 rounded px-2.5 text-[13px] font-medium text-adm-meta data-[state=active]:bg-adm-elev data-[state=active]:text-adm-fg data-[state=active]:shadow-sm max-md:h-11">
            EN<span v-if="enIncomplete" class="size-1.5 rounded-full bg-adm-warn-icon" aria-hidden="true" /><span v-if="enIncomplete" class="sr-only"> (incompleto)</span>
          </TabsTrigger>
        </TabsList>
      </TabsRoot>
      <button type="button" :class="[admBtnGhost, 'max-md:hidden max-lg:w-8 max-lg:px-0']" :disabled="busy" @click="$emit('preview')"><Eye aria-hidden="true" /><span class="max-lg:sr-only">Vista previa</span></button>
      <AdminEditorPublishMenu v-if="live" class="max-md:hidden" live :changes="changes" :busy="busy" :unpublish-disabled="unpublishDisabled" @primary="primary(true)" @changes="$emit('changes')" @discard="$emit('discard')" @copy="$emit('copy')" @unpublish="$emit('unpublish')" />
      <template v-else-if="!readonly">
        <button v-if="!noSchedule && display === 'scheduled'" type="button" :class="[admBtnGhost, 'max-xl:hidden']" :disabled="busy" @click="$emit('draft')"><Undo2 aria-hidden="true" />Volver a borrador</button>
        <button v-if="!noSchedule" type="button" :class="[admBtnGhost, 'max-md:hidden']" :disabled="busy" @click="$emit('publish', 'schedule')"><CalendarClock aria-hidden="true" />{{ display === 'scheduled' ? 'Cambiar fecha' : 'Programar' }}</button>
        <AdminEditorPublishMenu class="max-md:hidden" :live="false" :changes="0" :scheduled="display === 'scheduled'" :busy="busy" :blocked="publishBlocked" @primary="primary(false)" @copy="$emit('copy')" @draft="$emit('draft')" />
      </template>
      <button type="button" :class="[admIconBtn, 'max-md:hidden xl:hidden']" :aria-label="settingsLabel" :aria-expanded="settingsOpen" @click="$emit('settings')"><PanelRight aria-hidden="true" /></button>
    </div>
  </header>
</template>
