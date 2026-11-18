<script setup lang="ts">
import { Info } from 'lucide-vue-next'

/** "Qué significa cada dato": one legend for the whole list, closed by default (README §9.9.2). */
withDefaults(defineProps<{ showVariety?: boolean }>(), { showVariety: true })
const { t } = useI18n()
const { linkFor } = usePageLinks()
</script>

<template>
  <details class="group/legend mb-3 text-body-sm text-meta">
    <summary
      class="inline-flex min-h-11 cursor-pointer list-none items-center gap-1.5 rounded-sm transition-colors duration-150 select-none hover:text-foreground focus-visible:ring-focus [&::-webkit-details-marker]:hidden"
    >
      <Info :size="16" aria-hidden="true" />
      {{ t('gyms.legend.summary') }}
    </summary>
    <div class="max-w-[760px] space-y-4 pt-1 pb-3">
      <dl class="grid gap-x-8 gap-y-2 sm:grid-cols-3">
        <div>
          <dt class="inline text-foreground">{{ t('gyms.legend.entry.term') }}</dt>
          {{ ' ' }}<dd class="inline">{{ t('gyms.legend.entry.text') }}</dd>
        </div>
        <div>
          <dt class="inline text-foreground">{{ t('gyms.legend.family.term') }}</dt>
          {{ ' ' }}<dd class="inline">
            {{ t('gyms.legend.family.text') }}
            <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')">{{ t('gyms.howIndex') }}</UiTextLink>
          </dd>
        </div>
        <div v-if="showVariety">
          <dt class="inline text-foreground">{{ t('gyms.legend.variety.term') }}</dt>
          {{ ' ' }}<dd class="inline">{{ t('gyms.legend.variety.text') }}</dd>
        </div>
      </dl>
      <div class="border-t-[0.5px] border-line pt-3">
        <p class="font-medium text-foreground">{{ t('gyms.legend.scalesTitle') }}</p>
        <dl class="mt-1.5 grid gap-x-8 gap-y-2 sm:grid-cols-2">
          <div>
            <dt class="inline text-foreground">{{ t('gyms.legend.grading.term') }}</dt>
            {{ ' ' }}<dd class="inline">{{ t('gyms.legend.grading.text') }}</dd>
          </div>
          <div>
            <dt class="inline text-foreground">{{ t('gyms.legend.style.term') }}</dt>
            {{ ' ' }}<dd class="inline">{{ t('gyms.legend.style.text') }}</dd>
          </div>
        </dl>
        <p class="mt-2">{{ t('gyms.legend.scalesNote') }}</p>
      </div>
    </div>
  </details>
</template>
