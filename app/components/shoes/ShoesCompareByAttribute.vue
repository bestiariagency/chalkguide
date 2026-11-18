<script setup lang="ts">
import { X } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/**
 * Below lg (README §9.9.1): one block per attribute with the models side by side, no label
 * column and no horizontal scroll. Long attributes ("Lo que aprendí", "Dónde comprar") stack by
 * model below md. The header of models is sticky under the compact bar and compacts (only the
 * names) once it is stuck.
 */
const props = defineProps<{ shoes: ShoeSummary[]; flashSlug: string | null }>()
const emit = defineEmits<{ remove: [shoe: ShoeSummary] }>()
const { t } = useI18n()

const STICKY_TOP_PX = 56
const sentinel = ref<HTMLElement | null>(null)
const stuck = useStuck(sentinel, STICKY_TOP_PX)
const uid = useId()
const columns = computed(() => ({ '--cols': `repeat(${props.shoes.length}, minmax(0, 1fr))` }))
const flash = (slug: string) => props.flashSlug === slug && 'animate-flash motion-reduce:animate-none'
const collapsible =
  'grid grid-rows-[1fr] transition-[grid-template-rows] duration-200 ease-standard group-data-[stuck=true]:grid-rows-[0fr] motion-reduce:transition-none'
</script>

<template>
  <div class="lg:hidden" :style="columns">
    <div ref="sentinel" class="h-px" aria-hidden="true" />
    <div
      class="group sticky top-14 z-10 -mx-4 bg-elevated px-4 transition-shadow data-[stuck=true]:before:absolute data-[stuck=true]:before:inset-x-0 data-[stuck=true]:before:bottom-full data-[stuck=true]:before:h-14 data-[stuck=true]:before:bg-elevated duration-200 md:-mx-6 md:px-6"
      :class="stuck && 'shadow-[0_8px_16px_-12px_rgb(28_26_23/.55)]'"
      :data-stuck="stuck"
    >
      <ul class="grid grid-cols-(--cols) gap-x-5 py-2">
        <li v-for="shoe in shoes" :key="shoe.id" class="min-w-0" :class="flash(shoe.slug)">
          <div :class="collapsible">
            <div class="min-h-0 overflow-hidden">
              <ShoesPhotoTile :media="shoe.cover" :brand="shoe.brand" :model="shoe.model" sizes="160px" class="mb-1.5 h-16 w-full" />
            </div>
          </div>
          <div :class="collapsible">
            <div class="min-h-0 overflow-hidden">
              <span class="block truncate text-note text-meta">{{ shoe.brand }}</span>
            </div>
          </div>
          <span class="block text-body-sm leading-tight font-medium hyphens-auto">{{ shoe.model }}</span>
          <div :class="collapsible">
            <div class="min-h-0 overflow-hidden">
              <button
                type="button"
                class="inline-flex min-h-11 items-center gap-1 text-note text-meta underline underline-offset-2 hover:text-foreground"
                :aria-label="t('shoes.compare.removeNamed', { name: shoe.model })"
                @click="emit('remove', shoe)"
              >
                <X :size="14" aria-hidden="true" />{{ t('common.remove') }}
              </button>
            </div>
          </div>
        </li>
      </ul>
    </div>

    <section
      v-for="row in COMPARE_FIELDS"
      :key="row.key"
      :aria-labelledby="`${uid}-${row.key}`"
      class="border-b-[0.5px] border-line py-4"
    >
      <h3 :id="`${uid}-${row.key}`" class="label-mini mb-2">{{ t(`shoes.rows.${row.key}`) }}</h3>
      <ul
        class="grid gap-x-5 text-body-sm"
        :class="row.long ? 'grid-cols-1 gap-y-4 md:grid-cols-(--cols)' : 'grid-cols-(--cols) gap-y-0'"
      >
        <li
          v-for="shoe in shoes"
          :key="shoe.id"
          class="min-w-0 hyphens-auto"
          :class="flash(shoe.slug)"
        >
          <span :class="row.long ? 'mb-1 block text-caption font-medium md:sr-only' : 'sr-only'">
            {{ shoe.model }}<span class="sr-only">: </span>
          </span>
          <ShoesCompareCell :shoe="shoe" :field="row.key" />
        </li>
      </ul>
    </section>
  </div>
</template>
