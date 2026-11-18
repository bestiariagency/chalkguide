<script setup lang="ts">
import { X } from 'lucide-vue-next'

/**
 * Bottom sheet on mobile, centred modal from md (same shell as the review dialog). Focus goes
 * to the first control, or to `[data-autofocus]` if present; Tab is trapped, Esc and the scrim
 * close, focus returns to the opener, body scroll is locked while open.
 */
const props = defineProps<{
  title: string
  closeLabel: string
  /** Small label above the title (item name, listing…). */
  eyebrow?: string
  /** Selector of the element that regains focus on close when the opener is not the active element. */
  returnFocusTo?: string
  /** Padding of the content area. */
  paddingClass?: string
}>()
const open = defineModel<boolean>('open', { required: true })
const panel = ref<HTMLElement | null>(null)
const titleId = useId()
useSheetBehaviour(open, panel, props.returnFocusTo)

const AUTOFOCUS_DELAY_MS = 90 // after useSheetBehaviour's own first-control focus (60 ms)
watch(open, (isOpen) => {
  if (!isOpen) return
  setTimeout(() => panel.value?.querySelector<HTMLElement>('[data-autofocus]')?.focus(), AUTOFOCUS_DELAY_MS)
})
const close = () => (open.value = false)
</script>

<template>
  <div
    class="group fixed inset-0 z-50 transition-[visibility] duration-0"
    :class="open ? 'visible delay-0' : 'invisible delay-300'"
    :data-open="open"
    :aria-hidden="!open"
  >
    <div
      class="absolute inset-0 bg-(--scrim) opacity-0 transition-opacity duration-300 ease-standard group-data-[open=true]:opacity-100"
      @click="close"
    />
    <div
      ref="panel"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="titleId"
      class="absolute inset-x-0 bottom-0 max-h-[92vh] translate-y-full overflow-auto rounded-t-xl border-t-[0.5px] border-line-strong bg-board pb-[env(safe-area-inset-bottom)] transition-transform duration-[250ms] ease-in group-data-[open=true]:translate-y-0 group-data-[open=true]:duration-300 group-data-[open=true]:ease-out md:inset-auto md:top-1/2 md:left-1/2 md:max-h-[calc(100vh-64px)] md:w-[min(560px,calc(100vw-48px))] md:-translate-x-1/2 md:-translate-y-[48%] md:scale-[.98] md:rounded-xl md:border-[0.5px] md:opacity-0 md:transition-[transform,opacity] md:group-data-[open=true]:-translate-y-1/2 md:group-data-[open=true]:scale-100 md:group-data-[open=true]:opacity-100 motion-reduce:transition-none"
    >
      <div class="mx-auto mt-3 h-1 w-12 rounded-full bg-line-strong md:hidden" aria-hidden="true" />
      <div :class="paddingClass ?? 'p-5 md:p-8'">
        <div class="flex items-start justify-between gap-4">
          <div>
            <p v-if="eyebrow" class="label-mini">{{ eyebrow }}</p>
            <h2 :id="titleId" class="text-xl font-medium" :class="eyebrow && 'mt-1'">{{ title }}</h2>
          </div>
          <button
            type="button"
            class="-m-2 grid size-11 shrink-0 place-items-center rounded-md text-meta hover:text-foreground"
            :aria-label="closeLabel"
            @click="close"
          >
            <X :size="20" aria-hidden="true" />
          </button>
        </div>
        <div class="mt-4"><slot :close="close" /></div>
      </div>
    </div>
  </div>
</template>
