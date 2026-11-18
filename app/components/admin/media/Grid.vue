<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import { formatBytes, hasAlt, mediaFormatLabel, type AdminMediaItem } from '~/utils/admin-media-library'

/** Thumbnails with name, colour, size and alt/usage state. Each tile opens the detail. */
defineProps<{ items: readonly AdminMediaItem[] }>()
const emit = defineEmits<{ open: [id: string] }>()
const mediaUrl = useMediaUrl()

function label(m: AdminMediaItem) {
  const alt = hasAlt(m) ? '' : ', sin texto alternativo'
  const use = m.usage_count ? `, en uso en ${m.usage_count} ${m.usage_count === 1 ? 'sitio' : 'sitios'}` : ', sin usar'
  return `${m.original_filename}${alt}${use}`
}
</script>

<template>
  <ul class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 xl:grid-cols-6 2xl:grid-cols-7" aria-label="Imágenes">
    <li v-for="m in items" :key="m.id" class="min-w-0">
      <button
        type="button"
        :aria-label="label(m)"
        class="group relative block aspect-[4/3] w-full overflow-hidden rounded-lg bg-adm-subtle text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-adm-acc"
        :style="{ backgroundColor: m.dominant_color ?? undefined }"
        @click="emit('open', m.id)"
      >
        <NuxtImg :src="mediaUrl(m.storage_path)" alt="" width="320" height="240" loading="lazy" class="absolute inset-0 size-full object-cover transition-transform duration-150 group-hover:scale-[1.02] motion-reduce:transition-none" />
        <span class="absolute inset-0 rounded-lg ring-1 ring-black/10 ring-inset group-hover:ring-black/25" aria-hidden="true" />
        <span v-if="!hasAlt(m)" class="absolute top-1.5 left-1.5 inline-flex h-[18px] items-center gap-1 rounded bg-adm-warn-soft px-1.5 text-[11px] font-medium text-adm-warn">
          <TriangleAlert class="size-3" aria-hidden="true" />Sin alt
        </span>
        <span v-if="!m.usage_count" class="absolute top-1.5 right-1.5 inline-flex h-[18px] items-center rounded bg-adm-elev/90 px-1.5 text-[11px] font-medium text-adm-meta">Sin usar</span>
      </button>
      <p class="mt-1.5 flex items-center gap-1.5 text-xs">
        <span class="size-3 flex-none rounded-sm bg-adm-muted ring-1 ring-black/10" :style="{ backgroundColor: m.dominant_color ?? undefined }" :title="m.dominant_color ? `Color dominante ${m.dominant_color}` : undefined" aria-hidden="true" />
        <span class="truncate font-mono text-adm-meta">{{ m.original_filename }}</span>
      </p>
      <p class="truncate text-[11px] text-adm-muted tabular-nums">
        <template v-if="m.usage_count">{{ m.usage_count }} {{ m.usage_count === 1 ? 'uso' : 'usos' }} · </template>{{ m.width && m.height ? `${m.width} × ${m.height} · ` : '' }}{{ formatBytes(m.size_bytes) }} · {{ mediaFormatLabel(m.mime_type) }}
      </p>
    </li>
  </ul>
</template>
