<script setup lang="ts">
/**
 * "Nota de Xavi" plaque (§15.2 featured, §15.3 page): `accent-muted`, label in Caveat (decorative:
 * the aside carries the accessible name). Plain text split in paragraphs, always interpolated.
 * `signed` adds the small signature (photo, name, date) of the page.
 */
const props = defineProps<{ note: string; signed?: boolean; date?: string; large?: boolean }>()
const { t, locale } = useI18n()
const paragraphs = computed(() => newsParagraphs(props.note))
const { name, author } = useAuthor()
const photo = computed(() => author.value?.photo ?? null)
</script>

<template>
  <aside :aria-label="t('news.noteLabel')" class="rounded-slab bg-accent-muted p-5 md:p-6" :class="large ? 'md:px-7' : ''">
    <span aria-hidden="true" class="block origin-left -rotate-[1.5deg] font-hand text-[28px] leading-none font-bold text-accent">
      {{ t('news.noteLabel') }}
    </span>
    <div class="mt-3 space-y-3 text-[17px] leading-[1.55] text-foreground" :class="large ? 'md:text-[18px]' : ''">
      <p v-for="(paragraph, i) in paragraphs" :key="i">{{ paragraph }}</p>
    </div>
    <p v-if="signed" class="mt-4 flex items-center gap-3 text-caption text-meta">
      <AuthorPhoto v-if="photo" :media="photo" :size="32" />
      <span>{{ name }}<template v-if="date"> · <time :datetime="date">{{ formatDate(date, locale, { day: 'numeric', month: 'short', year: 'numeric' }) }}</time></template></span>
    </p>
  </aside>
</template>
