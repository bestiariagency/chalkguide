<script setup lang="ts">
import { CircleAlert, CircleCheck, CircleMinus, Clock } from 'lucide-vue-next'
import type { PreferenceFlash } from '~/composables/useConsentPreferences'

/**
 * One consent on the preferences page (D66, README §14.4): h2, state label (text + icon, never
 * colour alone), description, optional extra, action on the right. The row's own result message
 * is `role="status"` and takes focus so the change is announced where it happened.
 */
const props = defineProps<{
  title: string
  tone: 'on' | 'wait' | 'off'
  stateLabel: string
  flash?: PreferenceFlash | null
}>()
const { t } = useI18n()
const titleId = useId()
const flashBox = ref<HTMLElement | null>(null)
const icon = computed(() => ({ on: CircleCheck, wait: Clock, off: CircleMinus })[props.tone])
const toneClass = computed(
  () => ({ on: 'bg-success-muted text-success-text', wait: 'bg-accent-muted text-accent', off: 'bg-elevated text-meta' })[props.tone],
)
watch(
  () => props.flash,
  (value) => value && nextTick(() => flashBox.value?.focus()),
)
</script>

<template>
  <li class="slab bg-board">
    <section :aria-labelledby="titleId" class="grid gap-4 p-5 md:grid-cols-[minmax(0,1fr)_auto] md:items-start md:gap-6 md:p-7">
      <div class="min-w-0">
        <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
          <h2 :id="titleId" class="text-[20px] leading-tight font-medium tracking-[-0.01em] md:text-[22px]">{{ title }}</h2>
          <span class="inline-flex items-center gap-1.5 rounded-xs px-2 py-1 text-note font-medium whitespace-nowrap" :class="toneClass">
            <component :is="icon" :size="14" aria-hidden="true" />{{ stateLabel }}
          </span>
        </div>
        <p class="mt-2 max-w-[56ch] text-body-sm text-meta"><slot name="body" /></p>
        <slot />
        <p
          v-if="flash"
          ref="flashBox"
          role="status"
          tabindex="-1"
          class="mt-3 flex items-start gap-1.5 text-body-sm"
          :class="flash.kind === 'error' ? 'text-danger-text' : 'text-success-text'"
        >
          <component :is="flash.kind === 'error' ? CircleAlert : CircleCheck" :size="16" aria-hidden="true" class="mt-0.5 shrink-0" />
          <span>{{ t(`consent.prefs.flash.${flash.key}`) }}</span>
        </p>
      </div>
      <div class="md:pt-1"><slot name="action" /></div>
    </section>
  </li>
</template>
