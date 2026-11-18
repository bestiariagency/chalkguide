<script setup lang="ts">
import type { NewsSummary } from '~/types/news'

/**
 * List grouped by week (§15.2): H2 in Inter ("Esta semana · 16–22 nov", range in mono) over text
 * rows. Weeks run Monday to Sunday in Barcelona time. The week of "now" is computed on the server
 * and on the client, so the labels agree unless the page crosses a week boundary while open.
 */
const props = defineProps<{ items: NewsSummary[] }>()
const { t, locale } = useI18n()
const weeks = computed(() => groupNewsByWeek(props.items))
const id = useId()

function title(age: number) {
  return age === 0 ? t('news.thisWeek') : age === 1 ? t('news.previousWeek') : t('news.weekOf')
}
</script>

<template>
  <div class="mx-auto max-w-page px-4 pt-14 md:px-6 md:pt-20">
    <section
      v-for="(week, i) in weeks"
      :key="week.key"
      :aria-labelledby="`${id}-${week.key}`"
      :class="i > 0 ? 'pt-12 md:pt-16' : ''"
    >
      <h2 :id="`${id}-${week.key}`" class="text-[22px] font-medium tracking-[-.015em] md:text-[26px]">
        {{ title(week.age) }}
        <span class="ml-1 font-mono text-[16px] font-normal text-meta md:text-[18px]">{{ formatWeekRange(week, locale) }}</span>
      </h2>
      <ul class="mt-4 border-t border-foreground">
        <li v-for="news in week.items" :key="news.id" class="border-b border-line-strong">
          <NewsRow :news="news" />
        </li>
      </ul>
    </section>
  </div>
</template>
