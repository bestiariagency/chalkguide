<script setup lang="ts">
import { ArrowRight } from 'lucide-vue-next'
import type { LocaleRouteTo, SegmentOption } from '~/types/ui'

/** "¿Por dónde empiezas?": two profiles (tabs), three numbered entry points each. */
type Profile = 'new' | 'regular'

const { t, locale } = useI18n()
const profile = ref<Profile>('new')
const options = computed<SegmentOption<Profile>[]>(() => [
  { value: 'new', label: t('home.paths.new') },
  { value: 'regular', label: t('home.paths.regular') },
])

// Article slugs are translated: both articles exist in English with their own slug.
const article = (es: string, en: string): LocaleRouteTo => ({
  name: 'blog-slug',
  params: { slug: locale.value === 'en' ? en : es },
})

const paths = computed<Record<Profile, { key: string; to: LocaleRouteTo }[]>>(() => ({
  new: [
    { key: 'home.paths.new1', to: { name: 'climbing-gyms' } },
    { key: 'home.paths.new2', to: article('cuanto-cuesta-escalar-en-barcelona', 'how-much-climbing-costs-in-barcelona') },
    { key: 'home.paths.new3', to: article('como-elegir-pies-de-gato', 'how-to-choose-climbing-shoes') },
  ],
  regular: [
    { key: 'home.paths.regular1', to: { name: 'climbing-gyms' } },
    { key: 'home.paths.regular2', to: { name: 'climbing-shoe-resoling' } },
    { key: 'home.paths.regular3', to: { name: 'blog' } },
  ],
}))
</script>

<template>
  <section
    id="paths"
    class="bg-background scroll-mt-20"
    aria-labelledby="home-paths-title"
  >
    <div class="mx-auto max-w-page px-4 py-20 md:px-6 md:py-28 lg:py-[120px]">
      <div class="grid gap-x-6 gap-y-10 lg:grid-cols-12">
        <div class="lg:col-span-6">
          <h2 id="home-paths-title" class="title-section">{{ t('home.paths.title') }}</h2>
          <UiSegmentedControl
            v-model="profile"
            mode="tabs"
            id-prefix="home-paths"
            :label="t('home.paths.label')"
            :options="options"
            class="mt-8 w-full sm:w-auto"
          />
        </div>
        <div class="lg:col-span-6">
          <ul
            v-for="(items, key) in paths"
            v-show="profile === key"
            :id="`home-paths-panel-${key}`"
            :key="key"
            role="tabpanel"
            :aria-labelledby="`home-paths-tab-${key}`"
            class="animate-panel-in border-t border-foreground"
          >
            <li v-for="item in items" :key="item.key" class="border-b border-line-strong">
              <NuxtLinkLocale
                :to="item.to"
                class="group/card flex min-h-24 items-center gap-4 py-4 md:min-h-28 md:gap-6"
              >
                <span
                  class="flex-1 text-[22px] leading-[1.2] font-medium tracking-[-0.015em] md:text-[28px]"
                >
                  <span :class="cardTitleUnderline">{{ t(item.key) }}</span>
                </span>
                <ArrowRight
                  :size="24"
                  aria-hidden="true"
                  class="shrink-0 motion-safe:transition-transform motion-safe:duration-200 motion-safe:ease-out motion-safe:group-hover/card:translate-x-1"
                />
              </NuxtLinkLocale>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </section>
</template>
