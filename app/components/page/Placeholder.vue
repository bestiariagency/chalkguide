<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * Minimal page shell: board-textured header with breadcrumbs and the title, then the slot.
 * Used by the utility pages (newsletter results, legal) until they get their own layout.
 */
const props = withDefaults(defineProps<{
  title: string
  /** Crumbs after "Inicio"; the last one is the current page. */
  crumbs?: BreadcrumbItem[]
  /** e.g. 'noindex, follow' for legal pages, 'noindex, nofollow' for utility pages (§6). */
  robots?: string
  /** Page description. */
  description?: string
  /** false when the page sets its own metadata (usePageSeo / useItemSeo). */
  seo?: boolean
  /** Display title (title-section) for the newsletter result pages. */
  display?: boolean
}>(), { seo: true, display: false, crumbs: undefined, robots: undefined, description: undefined })

const { t } = useI18n()
const items = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  ...(props.crumbs ?? [{ label: props.title }]),
])

if (props.seo !== false) {
  usePageSeo(() => ({ title: props.title, description: props.description, robots: props.robots }))
}
</script>

<template>
  <section class="border-b-[0.5px] border-line board-tex">
    <div class="mx-auto max-w-page px-4 pt-8 pb-12 md:px-6 md:pt-10 md:pb-16">
      <UiBreadcrumbs :items="items" />
      <slot name="before-title" />
      <h1 class="mt-5" :class="display ? 'title-section' : 'text-title-1 font-medium'">{{ title }}</h1>
      <slot />
    </div>
  </section>
</template>
