<script setup lang="ts">
import { Users } from 'lucide-vue-next'

/**
 * "Encuentra compañero": waitlist block. Visual only until the real waitlist exists (F9):
 * the CTA is disabled and says it is coming soon; no invented counts.
 */
defineProps<{ gymName: string }>()
const { t } = useI18n()
</script>

<template>
  <section id="partner" class="scroll-mt-20" aria-labelledby="gym-partner-title">
    <h2 id="gym-partner-title" class="text-title-2 font-medium">{{ t('partner.title') }}</h2>
    <div class="mt-6 max-w-read rounded-xl border-[0.5px] border-line-strong bg-board p-5 md:p-6">
      <div class="flex items-center gap-3">
        <Users :size="24" class="shrink-0 text-accent" aria-hidden="true" />
        <p class="text-lg font-medium">{{ t('gyms.detail.partner.title', { gym: gymName }) }}</p>
      </div>
      <p class="mt-2 text-body-sm text-meta">{{ t('gyms.detail.partner.body') }}</p>
      <UiButton variant="ghost" disabled class="mt-5 w-full">
        {{ t('partner.waitlistCta') }}
      </UiButton>
      <p class="mt-3 text-caption text-meta">{{ t('gyms.detail.partner.soon') }}</p>
    </div>
  </section>
</template>
