<script setup lang="ts">
import { Link, Plus, SquarePlay } from 'lucide-vue-next'
import { MAX_NEWS_VIDEOS } from '~/utils/news-videos'
import { addVideo, moveVideo, videoIncomplete, type AdminNewsVideo } from '~/utils/admin-news-videos'

/**
 * Section «Vídeos» (README §17.5, D88), shared by the inbox detail and the editor. Controlled by `v-model`: the editor keeps it
 * in its form (saved with the item), the detail saves each change at once. Add by pasting a URL or an ID (`parseYoutubeId`, max 2,
 * no repeats); «Quitar» has no dialog but a toast with Deshacer. Nothing is asked of YouTube from here but the thumbnails (FV8).
 */
defineProps<{ proposedIds?: readonly string[]; unverified?: boolean; disabled?: boolean; error?: string }>()
const videos = defineModel<AdminNewsVideo[]>({ required: true })
const { success } = useAdminToast()
const url = ref('')
const addError = ref('')
const fresh = ref<string>()
const input = ref<HTMLInputElement>()
const uid = useId()
const full = computed(() => videos.value.length >= MAX_NEWS_VIDEOS)
const incomplete = computed(() => videos.value.some(videoIncomplete))

function add() {
  const result = addVideo(videos.value, url.value)
  if ('error' in result) {
    addError.value = result.error
    return
  }
  addError.value = ''
  url.value = ''
  fresh.value = result.added.youtubeId
  videos.value = result.videos
}
function update(index: number, video: AdminNewsVideo) {
  videos.value = videos.value.map((v, i) => (i === index ? video : v))
}
function remove(index: number) {
  const before = videos.value
  const gone = before[index]!
  videos.value = before.filter((_, i) => i !== index)
  success({ message: 'Vídeo quitado', action: { label: 'Deshacer', run: () => (videos.value = before) } })
  // Focus passes to the next row, or to the field when there is none.
  void nextTick(() => {
    const rows = document.querySelectorAll<HTMLElement>(`[data-video-section="${uid}"] [data-video-row]:not([data-video-row="${gone.youtubeId}"]) [data-video-focus]`)
    ;(rows[Math.min(index, rows.length - 1)] ?? input.value)?.focus()
  })
}
</script>

<template>
  <section :aria-labelledby="`${uid}-h`" :data-video-section="uid">
    <div class="flex items-center gap-2">
      <h3 :id="`${uid}-h`" class="text-sm font-semibold">Vídeos</h3>
      <span class="text-xs text-adm-meta tabular-nums" aria-live="polite">{{ videos.length }} / {{ MAX_NEWS_VIDEOS }}</span>
      <span class="ml-auto hidden text-xs text-adm-meta sm:inline">Salen tras «Por qué importa»; el vídeo solo se carga al pulsarlo</span>
    </div>

    <ol v-if="videos.length" class="mt-2 space-y-2" aria-label="Vídeos de la noticia, en orden">
      <AdminNewsVideoRow
        v-for="(v, i) in videos"
        :key="v.youtubeId"
        :video="v"
        :index="i"
        :count="videos.length"
        :proposed="!!proposedIds?.includes(v.youtubeId)"
        :unverified="!!unverified"
        :disabled="disabled"
        :start-editing="fresh === v.youtubeId"
        @move="(d) => (videos = moveVideo(videos, i, d))"
        @remove="remove(i)"
        @update="(next) => update(i, next)"
      />
    </ol>
    <p v-else class="mt-2 flex gap-2 rounded-lg border border-dashed border-adm-line-strong p-3 text-xs text-adm-meta"><SquarePlay class="size-4 flex-none" aria-hidden="true" />Sin vídeos. Pega la dirección de uno si quieres añadirlo.</p>

    <p v-if="error" class="mt-2 text-xs text-adm-danger" role="alert">{{ error }}</p>
    <p v-else-if="incomplete" class="mt-2 text-xs text-adm-meta">Falta el título o el canal de algún vídeo: sin ellos no se puede publicar.</p>

    <div class="mt-3" @keydown.enter.prevent="add">
      <label :for="`${uid}-url`" :class="admLabel">Añadir vídeo de YouTube <span class="font-normal text-adm-meta">(pega la URL o el ID)</span></label>
      <div class="flex gap-2">
        <div class="relative min-w-0 flex-1">
          <Link class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted" aria-hidden="true" />
          <input
            :id="`${uid}-url`"
            ref="input"
            v-model="url"
            :class="[admInput, 'pl-8', addError && admInputInvalid]"
            inputmode="url"
            autocomplete="off"
            placeholder="https://www.youtube.com/watch?v=… o youtu.be/…"
            :disabled="disabled || full"
            :aria-invalid="addError ? true : undefined"
            :aria-describedby="`${uid}-help`"
            @input="addError = ''"
          >
        </div>
        <button type="button" :class="admBtnGhost" :disabled="disabled || full || !url.trim()" @click="add"><Plus aria-hidden="true" />Añadir</button>
      </div>
      <p :id="`${uid}-help`" :class="['mt-1.5 text-xs', addError ? 'text-adm-danger' : 'text-adm-meta']" :role="addError ? 'alert' : undefined">{{ addError || (full ? 'Máximo 2. Quita uno para añadir otro.' : 'Acepta youtube.com/watch?v=…, youtu.be/…, /shorts/… o /embed/… y el ID suelto.') }}</p>
    </div>
  </section>
</template>
