<script setup lang="ts">
import type { AuthorStat } from '~/types/domain'

/**
 * "En números" (§13.8): up to 4 boxes in mono, 2 written by the author and 2 calculated (published
 * gyms and shoes). A box without a figure is not drawn; with fewer than two the section disappears.
 * Never a filler 0.
 */
const props = defineProps<{ written: AuthorStat[]; gyms: number; shoes: number; hasPhoto?: boolean }>()
const { t } = useI18n()

const boxes = computed(() => {
  const [first, second] = props.written
  const calculated = [
    { value: props.gyms, label: t('about.numbers.gyms') },
    { value: props.shoes, label: t('about.numbers.shoes') },
  ]
    .filter((box) => box.value > 0)
    .map((box) => ({ value: String(box.value), label: box.label }))
  return [first, ...calculated, second].filter((box): box is AuthorStat => !!box)
})
const columns: Record<number, string> = { 2: 'lg:grid-cols-2', 3: 'lg:grid-cols-3', 4: 'lg:grid-cols-4' }
</script>

<template>
  <section v-if="boxes.length >= 2" class="mx-auto max-w-page px-4 pt-12 md:px-6" :class="hasPhoto ? 'lg:pt-28' : 'lg:pt-16'" aria-labelledby="about-numbers">
    <h2 id="about-numbers" class="text-title-3 font-medium">{{ t('about.numbers.title') }}</h2>
    <dl class="mt-5 grid grid-cols-2 border-t border-foreground" :class="columns[boxes.length]">
      <div
        v-for="box in boxes"
        :key="box.label"
        class="border-line-strong py-5 pr-4 max-lg:even:border-l max-lg:even:pl-4 lg:border-l lg:pl-6 lg:first:border-l-0 lg:first:pl-0"
      >
        <dd class="font-mono text-[40px] leading-none tracking-[-.03em] tabular-nums md:text-[56px]">{{ box.value }}</dd>
        <dt class="mt-3 text-body-sm leading-snug text-meta">{{ box.label }}</dt>
      </div>
    </dl>
  </section>
</template>
