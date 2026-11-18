<script setup lang="ts">
import { Info } from 'lucide-vue-next'

/**
 * "More information" for the related-products consent (D66, README §14.1). A button outside the
 * checkbox <label>, so pressing it never ticks the box. Opens the extended text in a modal (sheet
 * on mobile); focus returns to the button on close. The extended text is i18n: it is not the text
 * the person accepts (that one comes from the DB).
 */
const { t } = useI18n()
const { linkFor } = usePageLinks()
const open = ref(false)
const sections = ['what', 'who', 'optional', 'withdraw', 'keep'] as const
</script>

<template>
  <button
    type="button"
    aria-haspopup="dialog"
    class="group/more inline-flex min-h-11 items-center gap-1.5 rounded-sm text-body-sm font-medium text-accent"
    @click="open = true"
  >
    <Info :size="16" aria-hidden="true" />
    <span class="bg-[linear-gradient(currentColor,currentColor)] bg-[length:100%_1px] bg-bottom bg-no-repeat pb-0.5 group-hover/more:bg-[length:100%_1.5px]">
      {{ t('newsletter.moreInfo') }}
    </span>
  </button>
  <UiSheet v-model:open="open" :title="t('consent.info.title')" :close-label="t('consent.info.close')">
    <div class="space-y-4">
      <section v-for="key in sections" :key="key">
        <h3 class="text-body-sm font-medium">{{ t(`consent.info.${key}Title`) }}</h3>
        <p class="mt-1 text-body-sm text-prose">{{ t(`consent.info.${key}Body`) }}</p>
      </section>
      <section>
        <h3 class="text-body-sm font-medium">{{ t('consent.info.legalTitle') }}</h3>
        <p class="mt-1 text-body-sm text-prose">
          {{ t('consent.info.legalBody') }}
          <UiTextLink :to="{ name: 'privacy' }" v-bind="linkFor('privacy')">{{ t('consent.info.legalLink') }}</UiTextLink>.
        </p>
      </section>
    </div>
    <div class="mt-6 flex border-t border-line pt-4">
      <UiButton variant="ghost" class="w-full sm:ml-auto sm:w-auto" @click="open = false">
        {{ t('consent.info.close') }}
      </UiButton>
    </div>
  </UiSheet>
</template>
