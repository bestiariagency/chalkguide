<script setup lang="ts">
import type { ArticleItemRef } from '~/types/domain'
import type { LocaleRouteTo } from '~/types/ui'

/** "Fichas de este artículo": the gyms, resolers and shoes the article mentions, with photo and note. */
defineProps<{ items: ArticleItemRef[] }>()
const { t } = useI18n()

const routeByKind = {
  gym: 'climbing-gyms-slug',
  resoler: 'climbing-shoe-resoling-slug',
  shoe: 'climbing-shoes-slug',
} as const
const itemTo = (item: ArticleItemRef): LocaleRouteTo => ({
  name: routeByKind[item.kind],
  params: { slug: item.slug },
})
</script>

<template>
  <section v-if="items.length" aria-labelledby="article-items" class="mt-16 md:mt-20">
    <h2 id="article-items" class="text-title-3 font-medium">{{ t('blog.mentioned') }}</h2>
    <ul class="mt-6 grid gap-4 sm:grid-cols-2 md:gap-6">
      <li v-for="item in items" :key="item.id" class="group/card slab relative flex items-center gap-4 bg-board p-3 pr-5 transition-colors duration-150 hover:bg-elevated has-[a:focus-visible]:ring-focus">
        <div class="relative size-24 shrink-0">
          <UiPhoto :media="item.cover ? { ...item.cover, alt: '' } : null" sizes="xs:96px md:96px" class="size-full overflow-hidden rounded-sm" />
          <p v-if="!item.cover" class="chrome-dark absolute inset-0 grid place-items-center bg-transparent px-1 text-center font-mono text-micro">
            {{ t('blog.noCover') }}
          </p>
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-note font-medium text-meta">{{ t(`blog.itemKind.${item.kind}`) }}</p>
          <NuxtLinkLocale :to="itemTo(item)" class="mt-0.5 block text-[19px] leading-tight font-medium after:absolute after:inset-0 after:z-[1] focus-visible:shadow-none">
            <span :class="cardTitleUnderline">{{ item.name }}</span>
          </NuxtLinkLocale>
          <p v-if="item.summary" class="mt-1 line-clamp-2 text-caption text-meta">{{ item.summary }}</p>
          <div v-if="item.visitType === 'invited' || item.isAffiliate" class="mt-2 flex flex-wrap gap-2">
            <UiBadge v-if="item.visitType === 'invited'" kind="guest-visit">{{ t('transparency.guestVisit') }}</UiBadge>
            <UiBadge v-if="item.isAffiliate" kind="affiliate">{{ t('transparency.affiliate') }}</UiBadge>
          </div>
        </div>
        <!-- Right slot for the author's note: it joins when the list carries it. -->
      </li>
    </ul>
  </section>
</template>
