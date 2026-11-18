<script setup lang="ts">
import { ArrowRight } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'
import type { ChangeEntry } from '~/utils/article-changes'
import { wordDiff } from '~/utils/text-diff'

/** One changed field of the draft in plain language, with its "Revertir". Text is always interpolated, never HTML. */
const props = defineProps<{ entry: ChangeEntry; mediaOf: (id: string | null) => AdminMedia | null; busy?: boolean }>()
defineEmits<{ revert: [key: string] }>()
const mediaUrl = useMediaUrl()

const before = computed(() => props.mediaOf(props.entry.mediaIds?.before ?? null))
const after = computed(() => props.mediaOf(props.entry.mediaIds?.after ?? null))
const blocks = computed(() => props.entry.blocks)
const summary = computed(() => {
  const b = blocks.value
  if (!b) return ''
  const parts = [
    b.added && `${b.added} ${b.added === 1 ? 'bloque nuevo' : 'bloques nuevos'}`,
    b.changed && `${b.changed} ${b.changed === 1 ? 'cambiado' : 'cambiados'}`,
    b.removed && `${b.removed} ${b.removed === 1 ? 'eliminado' : 'eliminados'}`,
  ].filter(Boolean)
  return parts.join(' · ') || 'Cambios de formato'
})
const diffMark = 'no-underline rounded-[2px] px-0.5'
const revertBtn = 'ml-auto text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg disabled:opacity-45 min-h-6 inline-flex items-center max-md:min-h-11'
</script>

<template>
  <li class="p-3">
    <div class="flex items-center gap-2">
      <span class="font-medium">{{ entry.label }}</span>
      <span v-if="entry.lang" class="rounded-[3px] border border-adm-line-strong px-1 font-mono text-[11px] font-medium text-adm-meta">{{ entry.lang }}</span>
      <template v-if="entry.kind === 'body'"><span class="text-xs text-adm-meta">{{ summary }}</span></template>
      <button type="button" :class="revertBtn" :disabled="busy" @click="$emit('revert', entry.key)">
        {{ entry.kind === 'body' ? 'Revertir el cuerpo' : 'Revertir' }}<span class="sr-only">: {{ entry.label }}{{ entry.lang ? ` (${entry.lang})` : '' }}</span>
      </button>
    </div>

    <p v-if="entry.kind === 'words'" class="mt-1.5 leading-6 break-words">
      <template v-for="(part, i) in entry.words" :key="i">
        <ins v-if="part.type === 'add'" :class="[diffMark, 'bg-adm-diff-add']"><span class="sr-only">Añadido: </span>{{ part.text }}</ins>
        <del v-else-if="part.type === 'del'" :class="[diffMark, 'bg-adm-diff-del']"><span class="sr-only">Eliminado: </span>{{ part.text }}</del>
        <template v-else>{{ part.text }}</template>
      </template>
      <span v-if="!entry.words?.length" class="text-adm-meta">Vacío</span>
    </p>

    <p v-else-if="entry.kind === 'value'" class="mt-1.5 flex flex-wrap items-center gap-2 leading-6">
      <span :class="[diffMark, 'bg-adm-diff-del']"><span class="sr-only">Antes: </span>{{ entry.values?.before }}</span>
      <ArrowRight class="size-4 text-adm-muted" aria-hidden="true" />
      <span :class="[diffMark, 'bg-adm-diff-add']"><span class="sr-only">Ahora: </span>{{ entry.values?.after }}</span>
    </p>

    <div v-else-if="entry.kind === 'media'" class="mt-2 flex flex-wrap items-center gap-3">
      <template v-for="(media, i) in [before, after]" :key="i">
        <ArrowRight v-if="i === 1" class="size-4 text-adm-muted" aria-hidden="true" />
        <figure>
          <NuxtImg v-if="media" :src="mediaUrl(media.storage_path)" :alt="`${i === 0 ? 'Antes' : 'Ahora'}: ${media.alt_es ?? media.original_filename}`" width="96" height="56" loading="lazy" :class="['h-14 w-24 rounded object-cover', i === 0 && 'opacity-70']" />
          <span v-else class="grid h-14 w-24 place-items-center rounded border border-dashed border-adm-line-strong text-xs text-adm-meta"><span class="sr-only">{{ i === 0 ? 'Antes: ' : 'Ahora: ' }}</span>Sin imagen</span>
          <figcaption class="mt-1 max-w-24 truncate font-mono text-[11px] text-adm-meta">{{ media?.original_filename ?? '—' }}</figcaption>
        </figure>
      </template>
    </div>

    <details v-else-if="blocks?.changes.length" class="mt-2">
      <summary class="flex min-h-6 cursor-pointer items-center text-xs text-adm-meta underline underline-offset-2 max-md:min-h-11">Ver texto</summary>
      <div class="mt-3 space-y-2 border-l-2 border-adm-line pl-3 text-[13px] leading-6">
        <template v-for="(change, i) in blocks.changes" :key="i">
          <p v-if="change.kind === 'added'" class="rounded bg-adm-diff-add px-2"><span class="sr-only">Añadido: </span>{{ change.after }}</p>
          <p v-else-if="change.kind === 'removed'" class="rounded bg-adm-diff-del px-2"><span class="sr-only">Eliminado: </span>{{ change.before }}</p>
          <p v-else>
            <span class="sr-only">Cambiado: </span>
            <template v-for="(part, k) in wordDiff(change.before ?? '', change.after ?? '')" :key="k">
              <ins v-if="part.type === 'add'" :class="[diffMark, 'bg-adm-diff-add']">{{ part.text }}</ins>
              <del v-else-if="part.type === 'del'" :class="[diffMark, 'bg-adm-diff-del']">{{ part.text }}</del>
              <template v-else>{{ part.text }}</template>
            </template>
          </p>
        </template>
      </div>
    </details>
  </li>
</template>
