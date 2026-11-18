<script setup lang="ts">
/**
 * "¿Vas solo?": bridge to Chalk app. The board is a sample and says so twice (label inside and
 * caption below): no real gym, no real date, no real count. Independent of the gym table, so it
 * also renders when that table does not load.
 */
import { ExternalLink } from 'lucide-vue-next'

const { t } = useI18n()
</script>

<template>
  <section class="bg-background" aria-labelledby="home-partner-title">
    <div class="mx-auto max-w-page px-4 py-20 md:px-6 md:py-24">
      <div class="grid items-center gap-x-6 gap-y-10 lg:grid-cols-12">
        <figure class="order-2 lg:order-1 lg:col-span-7">
          <div
            class="chrome-dark slab-ink dust overflow-hidden bg-[length:32px_32px] bg-[linear-gradient(var(--tex-line)_1px,transparent_1px),linear-gradient(90deg,var(--tex-line-2)_1px,transparent_1px)] p-5 md:p-8"
          >
            <div class="flex items-start justify-between gap-4">
              <p class="font-hand text-[30px] leading-[1.1] md:text-[36px]">{{ t('partner.sampleWhen') }}</p>
              <UiBadge class="shrink-0 !bg-paper !text-ink">{{ t('partner.exampleLabel') }}</UiBadge>
            </div>
            <ul class="mt-5 font-hand text-[28px] leading-[1.2] md:mt-6 md:text-[32px]">
              <li class="flex items-center gap-3 border-b border-line-strong pb-3">
                <span>{{ t('partner.sampleName') }}</span>
                <span class="text-accent">7b</span>
                <UiBadge kind="author" class="ml-auto font-sans">{{ t('partner.authorBadge') }}</UiBadge>
              </li>
              <li class="h-[52px] border-b border-line-strong" aria-hidden="true" />
              <li class="flex items-center gap-1 pt-3 text-meta">
                <UiChalkStroke variant="circle" class="px-[.5em] py-[.28em] text-foreground">
                  {{ t('partner.sampleMore') }}
                </UiChalkStroke>
              </li>
            </ul>
          </div>
          <figcaption class="mt-5 text-caption text-meta">{{ t('partner.exampleCaption') }}</figcaption>
        </figure>
        <div class="order-1 lg:order-2 lg:col-span-5 lg:col-start-8">
          <h2 id="home-partner-title" class="title-section">{{ t('partner.heading') }}</h2>
          <p class="mt-5 max-w-[44ch] text-lead text-meta">
            {{ t('partner.intro') }} {{ t('partner.body') }}
          </p>
          <UiButton :href="CHALK_APP_URL" variant="ghost" class="mt-7">
            <span class="inline-flex items-center gap-2">
              {{ t('partner.openApp') }}
              <ExternalLink :size="16" aria-hidden="true" />
            </span>
          </UiButton>
        </div>
      </div>
    </div>
  </section>
</template>
