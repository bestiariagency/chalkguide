<script setup lang="ts">
import { ArrowDown, ArrowUp, Pencil, Sparkles, SquarePlay, X } from 'lucide-vue-next'
import { VIDEO_CHANNEL_MAX, VIDEO_LANGS, VIDEO_LINK_REL, VIDEO_TITLE_MAX, videoIncomplete, videoLangLabel, youtubeThumbUrl, type AdminNewsVideo } from '~/utils/admin-news-videos'
import { youtubeWatchUrl } from '~/utils/news-videos'

/**
 * One video of the «Vídeos» section (README §17.5, D88): thumbnail from i.ytimg.com (FV8: no-referrer, lazy, empty alt,
 * only here in the panel), title and channel, origin chip and the actions. Title and channel are agent or third-party text:
 * interpolated; while the item is an agent draft they carry «Según la rutina, sin verificar» (FV9). The ID is read-only.
 */
const props = defineProps<{ video: AdminNewsVideo; index: number; count: number; proposed: boolean; unverified: boolean; disabled?: boolean; startEditing?: boolean; error?: string }>()
const emit = defineEmits<{ move: [delta: 1 | -1]; remove: []; update: [video: AdminNewsVideo] }>()

const editing = ref(props.startEditing ?? false)
const draft = ref({ title: props.video.title, channel: props.video.channel, lang: props.video.lang })
const thumbFailed = ref(false)
const uid = useId()
const name = computed(() => props.video.title || props.video.youtubeId)
const short = computed(() => (name.value.length > 28 ? `${name.value.slice(0, 28)}…` : name.value))
const draftIncomplete = computed(() => videoIncomplete(draft.value))

function startEdit() {
  draft.value = { title: props.video.title, channel: props.video.channel, lang: props.video.lang }
  editing.value = true
}
function save() {
  if (draftIncomplete.value) return
  emit('update', { ...props.video, title: draft.value.title.trim(), channel: draft.value.channel.trim(), lang: draft.value.lang })
  editing.value = false
}
watch(() => props.video, (v) => !editing.value && (draft.value = { title: v.title, channel: v.channel, lang: v.lang }))
</script>

<template>
  <li :data-video-row="video.youtubeId" class="rounded-lg border border-adm-line-strong p-2.5">
    <div class="grid grid-cols-[96px_minmax(0,1fr)] gap-3 sm:grid-cols-[128px_minmax(0,1fr)_auto]">
      <a :href="youtubeWatchUrl(video.youtubeId)" target="_blank" :rel="VIDEO_LINK_REL" :aria-label="`Abrir en YouTube: ${name} (otra pestaña)`" data-video-focus class="relative block aspect-video overflow-hidden rounded bg-adm-subtle focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-adm-acc">
        <img v-if="!thumbFailed" :src="youtubeThumbUrl(video.youtubeId)" width="320" height="180" alt="" loading="lazy" decoding="async" referrerpolicy="no-referrer" class="size-full object-cover" @error="thumbFailed = true">
        <span v-else class="grid size-full place-items-center text-adm-muted"><SquarePlay class="size-6" aria-hidden="true" /></span>
      </a>
      <div class="min-w-0">
        <p v-if="video.title" class="line-clamp-2 text-[13px] leading-5 font-medium" :lang="video.lang || undefined">{{ video.title }}</p>
        <p v-else class="text-[13px] leading-5 font-medium text-adm-danger">Sin título <span class="font-normal">(obligatorio para publicar)</span></p>
        <p class="mt-0.5 text-xs text-adm-meta"><template v-if="video.channel">{{ video.channel }}</template><span v-else class="text-adm-danger">Sin canal</span><template v-if="video.lang"> · {{ videoLangLabel(video.lang) }}</template></p>
        <p class="mt-1.5 flex flex-wrap items-center gap-1.5">
          <span :class="[admChip, 'bg-adm-subtle text-adm-meta']"><Sparkles v-if="proposed" aria-hidden="true" />{{ proposed ? 'Rutina' : 'Añadido por ti' }}</span>
          <span v-if="unverified && proposed" class="text-xs text-adm-meta">Según la rutina, sin verificar</span>
          <span class="font-mono text-[11px] text-adm-muted">{{ video.youtubeId }}</span>
        </p>
      </div>
      <div class="col-span-full flex items-center justify-end gap-0.5 sm:col-span-1 sm:justify-start">
        <button v-if="count > 1 && index > 0" type="button" :class="admIconBtn" :disabled="disabled" :aria-label="`Subir «${short}»`" @click="emit('move', -1)"><ArrowUp aria-hidden="true" /></button>
        <button v-if="count > 1 && index < count - 1" type="button" :class="admIconBtn" :disabled="disabled" :aria-label="`Bajar «${short}»`" @click="emit('move', 1)"><ArrowDown aria-hidden="true" /></button>
        <button type="button" :class="admIconBtn" :disabled="disabled" :aria-label="`Editar datos de «${short}»`" :aria-expanded="editing" :aria-controls="`${uid}-edit`" @click="editing ? (editing = false) : startEdit()"><Pencil aria-hidden="true" /></button>
        <button type="button" :class="[admIconBtn, 'hover:text-adm-danger!']" :disabled="disabled" :aria-label="`Quitar «${short}»`" @click="emit('remove')"><X aria-hidden="true" /></button>
      </div>
    </div>
    <p v-if="error" class="mt-2 text-xs text-adm-danger" role="alert">{{ error }}</p>
    <div v-if="editing" :id="`${uid}-edit`" class="mt-3 grid gap-3 sm:grid-cols-[minmax(0,1fr)_200px]">
      <div class="sm:col-span-2"><AdminTextField v-model="draft.title" label="Título" required :max="VIDEO_TITLE_MAX" :lang="undefined" autocomplete="off" /></div>
      <AdminTextField v-model="draft.channel" label="Canal" required :max="VIDEO_CHANNEL_MAX" autocomplete="off" />
      <div>
        <label :for="`${uid}-lang`" :class="admLabel">Idioma del vídeo</label>
        <select :id="`${uid}-lang`" v-model="draft.lang" :class="admInput">
          <option v-for="l in VIDEO_LANGS" :key="l.value" :value="l.value">{{ l.label }}</option>
        </select>
      </div>
      <div class="flex items-end justify-end gap-2 sm:col-span-2">
        <button type="button" :class="admBtnGhost" @click="editing = false">Cancelar</button>
        <button type="button" :class="admBtnPrimary" :disabled="draftIncomplete" @click="save">Aplicar</button>
      </div>
    </div>
  </li>
</template>
