<script setup lang="ts">
import type { AuthorProfile } from '~/types/domain'

/**
 * Author signature (editorial v2, §13.8, D51). `compact`: article head (photo 48, name, date in
 * words, minutes). `full`: end of the article (photo 96, name, role, bio, links). No photo: no
 * circle and no initial. Role and bio are only drawn when Ajustes has them. An own author (guide.authors) has no
 * author page: the name is plain text (no `about` link).
 */
const props = withDefaults(
  defineProps<{
    variant?: 'compact' | 'full'
    publishedAt?: string | null
    minutes?: number | null
    /** Own article author (guide.authors); null/absent = site author (site_settings). */
    author?: AuthorProfile | null
  }>(),
  { variant: 'compact', publishedAt: null, minutes: null, author: null },
)
const { t, locale } = useI18n()
const { linkFor } = usePageLinks()
const site = useAuthor()
const own = computed(() => !!props.author)
const author = computed(() => props.author ?? site.author.value)
const name = computed(() => props.author?.name ?? site.name.value)
const photo = computed(() => author.value?.photo ?? null)
const compact = computed(() => props.variant === 'compact')
</script>

<template>
  <div v-if="compact" class="flex items-center gap-3">
    <AuthorPhoto v-if="photo" :media="photo" :size="48" />
    <p class="min-w-0 text-body-sm leading-snug text-meta">
      <span v-if="own" class="block font-medium text-foreground">{{ name }}</span>
      <NuxtLinkLocale
        v-else
        :to="{ name: 'about' }"
        v-bind="linkFor('about')"
        class="hit block font-medium text-foreground hover:underline"
      >{{ name }}</NuxtLinkLocale>
      <time v-if="publishedAt" :datetime="publishedAt">{{ formatDate(publishedAt, locale) }}</time>
      <template v-if="minutes">
        <template v-if="publishedAt">{{ ' ' }}</template>
        <span class="whitespace-nowrap">
          <span v-if="publishedAt" aria-hidden="true" class="text-hint">{{ '· ' }}</span>
          <span class="font-mono text-note">{{ t('blog.readingTime', { count: minutes }) }}</span>
        </span>
      </template>
    </p>
  </div>

  <aside
    v-else
    :aria-label="t('author.signatureLabel')"
    class="mt-14 grid gap-4 border-t border-foreground pt-5"
    :class="photo ? 'grid-cols-[64px_minmax(0,1fr)] md:grid-cols-[96px_minmax(0,1fr)] md:gap-6' : ''"
  >
    <AuthorPhoto v-if="photo" :media="photo" :size="96" class="max-md:size-16" />
    <div class="min-w-0">
      <p class="text-title-4 font-medium">{{ name }}</p>
      <p v-if="author?.role" class="text-caption text-meta">{{ author.role }}</p>
      <p v-if="author?.bio" class="mt-2 text-body leading-[1.5] text-prose">{{ author.bio }}</p>
      <div class="mt-3 flex flex-wrap gap-x-6">
        <UiTextLink v-if="!own" :to="{ name: 'about' }" v-bind="linkFor('about')" class="inline-flex min-h-11 items-center text-body-sm">
          {{ t('nav.about') }}
        </UiTextLink>
        <UiTextLink
          :to="{ name: 'transparency' }"
          v-bind="linkFor('transparency')"
          class="inline-flex min-h-11 items-center text-body-sm"
        >
          {{ own ? t('author.howWeWork') : t('author.howIWork') }}
        </UiTextLink>
      </div>
    </div>
  </aside>
</template>
