<script setup lang="ts">
import type { AboutCheckedItem } from '~/types/domain'

/** "Lo último que he comprobado" (§13.8): the published items with the most recent verification. */
const props = defineProps<{ items: AboutCheckedItem[] }>()
const { t, locale } = useI18n()

const ROUTES = {
  gym: 'climbing-gyms-slug',
  resoler: 'climbing-shoe-resoling-slug',
  shoe: 'climbing-shoes-slug',
} as const

const rows = computed(() =>
  props.items.map((item) => ({
    ...item,
    to: { name: ROUTES[item.category], params: { slug: item.slug } },
    kind: t(`about.latest.kind.${item.category}`),
    score: formatScore(item.authorScore, locale.value),
  })),
)
</script>

<template>
  <section v-if="rows.length" class="mx-auto max-w-page px-4 pt-16 md:px-6 md:pt-24" aria-labelledby="about-latest">
    <div class="flex items-end justify-between gap-4">
      <h2 id="about-latest" class="text-title-3 font-medium">{{ t('about.latest.title') }}</h2>
      <UiTextLink :to="{ name: 'climbing-gyms' }" class="hidden min-h-11 items-center text-body-sm sm:inline-flex">
        {{ t('about.latest.allGyms') }}
      </UiTextLink>
    </div>
    <ul class="mt-6 grid gap-x-6 gap-y-8 md:grid-cols-3">
      <li v-for="row in rows" :key="row.slug">
        <NuxtLinkLocale :to="row.to" class="group block">
          <UiPhoto
            :media="row.cover"
            sizes="xs:100vw md:384px"
            class="slab aspect-[4/3] overflow-hidden rounded-slab"
          />
          <span class="mt-4 flex items-baseline justify-between gap-3">
            <span class="text-title-4 leading-tight font-medium group-hover:underline">{{ row.name }}</span>
            <span v-if="row.score" class="font-mono text-title-4 tabular-nums">
              <span class="sr-only">{{ t('about.latest.score') }}: </span>{{ row.score }}
            </span>
          </span>
          <span class="mt-1 block text-caption text-meta">
            {{ row.kind }} ·
            <time :datetime="row.verifiedAt" class="font-mono">{{ formatShortDate(row.verifiedAt, locale) }}</time>
          </span>
        </NuxtLinkLocale>
      </li>
    </ul>
  </section>
</template>
