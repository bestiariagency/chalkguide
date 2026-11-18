<script setup lang="ts">
import { Info } from 'lucide-vue-next'

/** Model the author has not used: says so plainly, never an empty score or a "0" (the summary is already in the header). */
const { t } = useI18n()
</script>

<template>
  <section id="review" class="scroll-mt-20" aria-labelledby="shoe-no-review">
    <div class="flex max-w-read items-start gap-3 rounded-lg border-[0.5px] border-line-strong bg-board p-5 md:p-6">
      <Info :size="20" aria-hidden="true" class="mt-0.5 shrink-0 text-meta" />
      <div>
        <h2 id="shoe-no-review" class="font-medium">{{ t('shoes.detail.noReview.title') }}</h2>
        <p class="mt-1 text-body-sm text-meta">{{ t('shoes.detail.noReview.body') }}</p>
        <UiTextLink href="#opinions" class="mt-3 inline-block text-caption">
          {{ t('shoes.detail.noReview.link') }}
        </UiTextLink>
      </div>
    </div>
  </section>
</template>
