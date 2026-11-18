<script setup lang="ts">
import { ChevronDown } from 'lucide-vue-next'
import type { TocHeading } from '~/utils/article-toc'

/**
 * Article index (editorial v2, §13.5). `rail`: from 1100 px, sticky in the 240 px rail with the
 * current section marked, "Quedan N min" and the one newsletter line allowed by D48.
 * `inline`: below 1100 px, a closed <details> after the cover. Links are server-rendered; the H2
 * ids come from <UiProse anchors> (same `bodyHeadings` slugs).
 */
const props = defineProps<{
  variant: 'rail' | 'inline'
  headings: TocHeading[]
  activeId?: string | null
  minutes?: number | null
  progress?: number
}>()
const { t } = useI18n()

const left = computed(() => {
  if (!props.minutes) return null
  const remaining = Math.ceil(props.minutes * (1 - (props.progress ?? 0)))
  return remaining > 0 ? t('blog.toc.remaining', { count: remaining }) : t('blog.toc.done')
})
</script>

<template>
  <aside v-if="variant === 'rail'" class="max-[1099px]:hidden" :aria-label="t('blog.toc.label')">
    <div class="sticky top-[88px]">
      <p class="text-note font-medium text-meta">{{ t('blog.toc.title') }}</p>
      <ol class="relative mt-2 pl-4 before:absolute before:top-1 before:bottom-1 before:left-0 before:w-0.5 before:rounded-[2px] before:bg-line before:content-['']">
        <li v-for="heading in headings" :key="heading.id" class="relative">
          <a
            :href="`#${heading.id}`"
            :aria-current="activeId === heading.id ? 'true' : undefined"
            class="flex min-h-11 items-center py-1.5 text-body-sm leading-[1.3] text-meta transition-colors duration-150 hover:text-foreground aria-[current=true]:font-medium aria-[current=true]:text-foreground aria-[current=true]:before:absolute aria-[current=true]:before:top-2 aria-[current=true]:before:bottom-2 aria-[current=true]:before:-left-4 aria-[current=true]:before:w-0.5 aria-[current=true]:before:rounded-[2px] aria-[current=true]:before:bg-chalk aria-[current=true]:before:content-['']"
          >
            {{ heading.text }}
          </a>
        </li>
      </ol>
      <p v-if="left" class="mt-6 font-mono text-note text-meta" aria-live="off">{{ left }}</p>
      <a href="#newsletter" class="mt-3 inline-flex min-h-11 items-center text-body-sm font-medium text-accent underline decoration-accent underline-offset-4">
        {{ t('blog.toc.newsletter') }}<span aria-hidden="true">{{ ' →' }}</span>
      </a>
    </div>
  </aside>

  <details v-else class="group/toc border-y border-line-strong min-[1100px]:hidden">
    <summary class="flex min-h-[52px] cursor-pointer list-none items-center justify-between gap-3 font-medium [&::-webkit-details-marker]:hidden">
      {{ t('blog.toc.summary', { count: headings.length }) }}
      <ChevronDown :size="20" class="transition-transform duration-200 group-open/toc:rotate-180" aria-hidden="true" />
    </summary>
    <nav :aria-label="t('blog.toc.label')">
      <ol class="pb-2">
        <li v-for="(heading, i) in headings" :key="heading.id">
          <a :href="`#${heading.id}`" class="flex min-h-11 items-baseline gap-3 py-2.5 leading-[1.35] text-prose">
            <span class="font-mono text-note text-meta" aria-hidden="true">{{ String(i + 1).padStart(2, '0') }}</span>
            {{ heading.text }}
          </a>
        </li>
      </ol>
    </nav>
  </details>
</template>
