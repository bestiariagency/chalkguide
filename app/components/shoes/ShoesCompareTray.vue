<script setup lang="ts">
import { ArrowDown, X } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/**
 * Floating comparison pill: count, one chip per chosen model (thumbnail, name, remove) and a
 * jump to the side-by-side view (disabled until there are 2). Hidden while the comparison
 * itself is on screen (no stacked bars).
 */
const props = defineProps<{ shoes: ShoeSummary[]; hidden?: boolean }>()
const emit = defineEmits<{ remove: [shoe: ShoeSummary] }>()
// Tells the toast region to sit above the tray while it is visible.
const trayVisible = useState('compare-tray-visible', () => false)
const shown = computed(() => props.shoes.length > 0 && !props.hidden)
watchEffect(() => (trayVisible.value = shown.value))
onBeforeUnmount(() => (trayVisible.value = false))
const { t } = useI18n()
const ready = computed(() => props.shoes.length >= 2)
</script>

<template>
  <div
    v-if="shown"
    class="pointer-events-none fixed inset-x-0 bottom-0 z-30 flex justify-center px-3 pb-[calc(12px+env(safe-area-inset-bottom))]"
    role="region"
    :aria-label="t('shoes.compare.title')"
    aria-live="polite"
  >
    <div
      class="pointer-events-auto flex max-w-full flex-wrap items-center justify-center gap-2 rounded-xl bg-foreground p-2 text-background shadow-[var(--shadow-bar)]"
    >
      <p class="shrink-0 pl-2 font-mono text-note text-background/70">
        <span class="sr-only">{{ t('shoes.compare.capacity', { count: shoes.length, max: MAX_COMPARE }) }}</span>
        <span aria-hidden="true">{{ shoes.length }}/{{ MAX_COMPARE }}</span>
      </p>
      <ul class="flex min-w-0 items-center gap-1.5">
        <li
          v-for="shoe in shoes"
          :key="shoe.id"
          class="flex min-w-0 items-center gap-1 rounded-md bg-background/10 py-1 pr-0.5 pl-1"
        >
          <ShoesPhotoTile :media="shoe.cover" :brand="shoe.brand" :model="shoe.model" sizes="40px" class="size-9 shrink-0 !rounded-sm [&_img]:p-0.5" />
          <span class="hidden max-w-28 truncate px-1 text-note sm:inline">{{ shoe.model }}</span>
          <button
            type="button"
            class="-my-1 grid size-11 shrink-0 place-items-center rounded-md text-background/70 hover:text-background focus-visible:ring-focus"
            :aria-label="t('shoes.compare.removeNamed', { name: shoe.model })"
            @click="emit('remove', shoe)"
          >
            <X :size="14" aria-hidden="true" />
          </button>
        </li>
      </ul>
      <UiButton :href="ready ? '#comparacion' : undefined" :disabled="!ready" class="shrink-0 whitespace-nowrap">
        <span v-if="ready" class="inline-flex items-center gap-2">
          {{ t('common.compare') }} <ArrowDown :size="16" aria-hidden="true" />
        </span>
        <template v-else>{{ t('shoes.compare.pickOneMore') }}</template>
      </UiButton>
    </div>
  </div>
</template>
