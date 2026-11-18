<script setup lang="ts">
import type { ArticleSummary } from '~/types/domain'

/**
 * Main article of the home: cover (or the photo placeholder) on a slab, with a dark gradient and
 * category + title overlaid at the bottom. The category stays in Inter (D44), not mono.
 */
const props = withDefaults(
  defineProps<{
    article: ArticleSummary
    sizes?: string
    /** `sm`: smaller title and padding for narrow mosaic tiles. */
    size?: 'md' | 'sm'
    /** First image of the page (LCP). */
    priority?: boolean
    /** No slab shadow (blog grid, at Xavi's request). */
    flat?: boolean
  }>(),
  { sizes: '100vw md:66vw', size: 'md', priority: false, flat: false },
)
const to = computed(() => ({ name: 'blog-slug' as const, params: { slug: props.article.slug } }))
</script>

<template>
  <article :class="flat ? 'rounded-slab' : 'slab'" class="group/card relative isolate overflow-hidden bg-neutral-900 has-[a:focus-visible]:ring-focus">
    <UiPhoto
      :media="article.cover"
      :sizes="sizes"
      :priority="priority"
      class="absolute inset-0 -z-20 size-full transition-transform duration-[600ms] ease-out motion-reduce:transition-none motion-safe:group-hover/card:scale-[1.03]"
    />
    <div
      class="absolute inset-0 -z-10 bg-linear-to-b from-black/0 from-20% via-black/55 via-45% to-black/85"
      aria-hidden="true"
    />
    <div class="absolute inset-x-0 bottom-0 p-5 text-white" :class="size === 'sm' ? 'md:p-5' : 'md:p-8'">
      <p v-if="article.category" class="text-note font-medium text-white/90">{{ article.category.name }}</p>
      <h3
        class="mt-2 max-w-[22ch] leading-[1.12] font-medium tracking-[-0.025em]"
        :class="size === 'sm' ? 'text-2xl md:text-lg' : 'text-2xl md:text-4xl'"
      >
        <!-- Stretched link: the whole card is clickable, focus ring on the card. -->
        <NuxtLinkLocale
          :to="to"
          class="after:absolute after:inset-0 after:z-[1] focus-visible:shadow-none focus-visible:outline-none"
        >
          <span
            class="bg-[linear-gradient(#fff,#fff)] bg-size-[0%_1.5px] bg-position-[0_100%] bg-no-repeat pb-0.5 transition-[background-size] duration-300 ease-out group-hover/card:bg-size-[100%_1.5px]"
          >
            {{ article.title }}
          </span>
        </NuxtLinkLocale>
      </h3>
    </div>
  </article>
</template>
