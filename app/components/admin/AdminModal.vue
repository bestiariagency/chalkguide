<script setup lang="ts">
import { DialogClose, DialogContent, DialogDescription, DialogOverlay, DialogPortal, DialogRoot, DialogTitle } from 'reka-ui'
import { X } from 'lucide-vue-next'

/**
 * Modal / drawer / bottom sheet (Reka Dialog). Under 768 px it always becomes a bottom sheet with a
 * grab handle and a sticky full-width footer. Focus is trapped, Esc closes, focus returns to the
 * trigger and scroll is locked (Reka). Mark the control that should receive the initial focus with
 * `data-autofocus` (destructive confirmations focus "Cancelar").
 */
const props = withDefaults(
  defineProps<{
    title: string
    description?: string
    /** 480 / 720 / 960 px wide (centered placement). */
    size?: 'sm' | 'md' | 'lg'
    placement?: 'center' | 'right'
    /** `alertdialog`: cannot be dismissed by clicking outside and shows no close button. */
    alert?: boolean
    /** Blocks closing (e.g. while saving). */
    busy?: boolean
    /** `right` drawer only: 520 px instead of 440 (long forms). */
    wide?: boolean
    /** `right` drawer only: 640 px (the news editor, README §19.2). */
    extra?: boolean
    /** Opened on top of another dialog/drawer: its overlay and panel sit above it. */
    stacked?: boolean
  }>(),
  { size: 'sm', placement: 'center', description: undefined },
)
const open = defineModel<boolean>('open', { default: false })

const widths = { sm: 'md:max-w-[480px]', md: 'md:max-w-[720px]', lg: 'md:max-w-[960px]' }
const box = computed(() =>
  props.placement === 'right'
    ? `md:inset-y-0 md:right-0 ${props.extra ? 'md:w-[640px]' : props.wide ? 'md:w-[520px]' : 'md:w-[440px]'} md:max-w-[100vw] md:rounded-none md:border-y-0 md:border-r-0 md:animate-adm-slide md:max-h-none`
    : `md:top-1/2 md:left-1/2 md:w-[calc(100%-2rem)] md:-translate-x-1/2 md:-translate-y-1/2 md:rounded-xl md:max-h-[calc(100dvh-2rem)] ${widths[props.size]} md:animate-adm-rise`,
)

function onOpenAutoFocus(event: Event) {
  const el = event.currentTarget as HTMLElement | null
  const mark = el?.querySelector<HTMLElement>('[data-autofocus]')
  const target = mark?.matches('input,textarea,select,button,a[href],[tabindex]')
    ? mark
    : mark?.querySelector<HTMLElement>('input,textarea,select,button')
  if (target) {
    event.preventDefault()
    target.focus()
  }
}
function guard(event: Event) {
  if (props.alert || props.busy) event.preventDefault()
}
</script>

<template>
  <DialogRoot v-model:open="open">
    <slot name="trigger" />
    <DialogPortal>
      <DialogOverlay :class="['admin fixed inset-0 bg-adm-scrim animate-adm-fade motion-reduce:animate-none', stacked ? 'z-[70]' : 'z-[60]']" />
      <DialogContent
        :role="alert ? 'alertdialog' : 'dialog'"
        :aria-describedby="description ? undefined : ''"
        :class="[
          stacked ? 'z-[70]' : 'z-[60]',
          'admin fixed flex flex-col border border-adm-line bg-adm-elev font-sans text-[14px] leading-[22px] text-adm-fg shadow-adm-pop outline-none',
          'max-md:inset-x-0 max-md:bottom-0 max-md:max-h-[92dvh] max-md:animate-adm-sheet max-md:rounded-t-2xl motion-reduce:animate-none',
          box,
        ]"
        @open-auto-focus="onOpenAutoFocus"
        @escape-key-down="(e: Event) => busy && e.preventDefault()"
        @pointer-down-outside="guard"
        @interact-outside="guard"
      >
        <div class="mx-auto mt-2 h-1 w-9 flex-none rounded-full bg-adm-line-strong md:hidden" aria-hidden="true" />
        <header class="flex flex-none items-start gap-3 px-5 pt-5 max-md:pt-3">
          <div class="min-w-0 flex-1">
            <DialogTitle class="text-base leading-6 font-semibold"><slot name="title">{{ title }}</slot></DialogTitle>
            <DialogDescription v-if="description" class="mt-1 text-sm text-adm-meta">{{ description }}</DialogDescription>
          </div>
          <DialogClose v-if="!alert" :class="[admIconBtn, '-mt-1 -mr-2']" aria-label="Cerrar" :disabled="busy">
            <X aria-hidden="true" />
          </DialogClose>
        </header>
        <div v-if="$slots.default" class="min-h-0 flex-1 overflow-y-auto px-5 py-4"><slot /></div>
        <footer
          v-if="$slots.footer"
          class="flex flex-none flex-wrap justify-end gap-2 px-5 pt-3 pb-5 max-md:sticky max-md:bottom-0 max-md:border-t max-md:border-adm-line max-md:bg-adm-elev max-md:pb-[calc(12px+env(safe-area-inset-bottom))] max-md:[&>*]:flex-1"
        >
          <slot name="footer" />
        </footer>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>
