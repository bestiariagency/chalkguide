<script setup lang="ts">
import { CornerDownLeft } from 'lucide-vue-next'
import type { PaletteOption } from '~/utils/admin-palette'

/** One row of the ⌘K listbox (a `role="option"`, never a nested link). 48 px, 56 px on phones. */
defineProps<{ option: PaletteOption; active: boolean }>()
defineEmits<{ hover: []; pick: [] }>()
const mediaUrl = useMediaUrl()
</script>

<template>
  <div
    :id="`pal-${option.id}`"
    role="option"
    :aria-selected="active"
    :class="['flex min-h-14 cursor-pointer items-center gap-3 px-3 py-1.5 md:min-h-12', active ? 'bg-adm-subtle' : '']"
    @mousemove="$emit('hover')"
    @click="$emit('pick')"
  >
    <span v-if="option.thumb" class="relative h-7 w-9 flex-none overflow-hidden rounded" :style="{ backgroundColor: option.thumb.color ?? undefined }">
      <NuxtImg :src="mediaUrl(option.thumb.path)" alt="" width="36" height="28" loading="lazy" class="size-full object-cover" />
    </span>
    <span v-else-if="option.icon" class="grid size-7 flex-none place-items-center rounded-md bg-adm-subtle text-adm-meta [&_svg]:size-4"><component :is="option.icon" aria-hidden="true" /></span>
    <span class="min-w-0 flex-1">
      <span class="block truncate text-sm leading-5 font-medium"><AdminPaletteMarked :text="option.label" :mark="option.type === 'result' ? option.mark : undefined" /></span>
      <span v-if="option.sub" :class="['block truncate text-xs leading-4 text-adm-meta', option.subItalic && 'italic']"><AdminPaletteMarked :text="option.sub" :mark="option.type === 'result' ? option.mark : undefined" /></span>
    </span>
    <span v-if="option.chip" :class="[admChip, option.chip.tone, 'max-sm:hidden']">{{ option.chip.label }}</span>
    <CornerDownLeft v-if="active" class="size-4 flex-none text-adm-muted max-md:hidden" aria-hidden="true" />
  </div>
</template>
