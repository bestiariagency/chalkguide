<script setup lang="ts">
/**
 * «Por qué importa» (README §18.9.4, D91): the insight, on a `board` slab with a 3 px chalk rule on the left. Plain text split
 * at blank lines, interpolated (F8.1 F1): never v-html, never links (the internal ones go in «En ChalkGuide»). The first
 * paragraph is the sentence that also shows on the front page. Unsigned: it is not the voice of an author.
 */
const props = defineProps<{ text: string }>()
const { t } = useI18n()
const paragraphs = computed(() => newsParagraphs(props.text))
</script>

<template>
  <section
    v-if="paragraphs.length"
    id="insight"
    aria-labelledby="news-insight-title"
    class="slab relative bg-board py-6 pr-5 pl-6 before:absolute before:inset-y-4 before:left-0 before:w-[3px] before:rounded-r-xs before:bg-chalk md:py-8 md:pr-9 md:pl-10"
  >
    <h2 id="news-insight-title" class="font-mono text-micro leading-[1.3] tracking-[.14em] text-accent uppercase">
      {{ t('news.aporte.title') }}
    </h2>
    <div class="mt-3 space-y-[.9em] text-read leading-[1.62] text-prose">
      <p v-for="(paragraph, i) in paragraphs" :key="i" :class="i === 0 ? 'text-foreground' : ''">{{ paragraph }}</p>
    </div>
  </section>
</template>
