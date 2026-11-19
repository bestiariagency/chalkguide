<script setup lang="ts">
import type { NewsSummary } from '~/types/news'

/**
 * The front page of /noticias (README §18): one `ul` that is a newspaper grid (opener + 2 + rest) or, under
 * `html[data-news-view=list]`, the list grouped by week (§15.2). Weeks only show in the list: in the grid the date is on each
 * piece (§18.4). The DOM is chronological, with the opener drawn first for the grid when it is not the newest (see `leadFirst`). The week of "now" is
 * computed on the server and on the client, so the labels agree unless the page crosses a week boundary while open.
 */
const props = defineProps<{ items: NewsSummary[]; page: number }>()
const { t, locale } = useI18n()
const weeks = computed(() => groupNewsByWeek(props.items))
const positions = computed(() => newsPositions(props.items, props.page))
// The grid shows the opener first but the DOM must keep reading order: if it is not the first by date, it is drawn twice
// (first for the grid, at its date for the list) and each view only exposes one of them.
const lead = computed(() => props.items.find((item) => positions.value.get(item.id) === 'lead'))
const leadFirst = computed(() => !!lead.value && lead.value !== props.items[0])

function title(age: number) {
  return age === 0 ? t('news.thisWeek') : age === 1 ? t('news.previousWeek') : t('news.weekOf')
}
</script>

<template>
  <section class="mx-auto max-w-page px-4 pt-8 md:px-6 md:pt-10" aria-labelledby="news-latest-title">
    <h2 id="news-latest-title" class="sr-only news-list:hidden">{{ t('news.latest') }}</h2>
    <ul
      class="grid grid-cols-1 gap-x-4 gap-y-8 md:grid-cols-2 md:gap-x-6 md:gap-y-10 lg:grid-cols-3 xl:gap-x-7 xl:gap-y-12 news-list:block"
    >
      <NewsPiece v-if="lead && leadFirst" :key="`${lead.id}-grid`" :news="lead" pos="lead" :age="0" view="grid" />
      <template v-for="week in weeks" :key="week.key">
        <li class="hidden news-list:block news-list:pt-12 news-list:first:pt-0 md:news-list:pt-16">
          <h2 class="border-b border-foreground pb-4 text-[22px] font-medium tracking-[-.015em] md:text-[26px]">
            {{ title(week.age) }}
            <span class="ml-1 font-mono text-[16px] font-normal text-meta">{{ formatWeekRange(week, locale) }}</span>
          </h2>
        </li>
        <NewsPiece
          v-for="news in week.items"
          :key="news.id"
          :news="news"
          :pos="positions.get(news.id) ?? 'grid'"
          :age="week.age"
          :view="news.id === lead?.id && leadFirst ? 'list' : undefined"
        />
      </template>
    </ul>
  </section>
</template>
