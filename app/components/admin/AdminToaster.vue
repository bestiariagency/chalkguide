<script setup lang="ts">
import { ToastAction, ToastClose, ToastDescription, ToastProvider, ToastRoot, ToastViewport } from 'reka-ui'
import { CircleAlert, CircleCheck, Info, X } from 'lucide-vue-next'

/**
 * Renders the queue of `useAdminToast()`. Mount once (admin layout). Top right, below the top bar
 * (success in soft green); errors are persistent and assertive (role alert).
 */
const { toasts, dismiss } = useAdminToast()

const tone = {
  success: 'border border-adm-ok/25 bg-adm-ok-soft text-adm-ok',
  error: 'border border-adm-danger bg-adm-elev text-adm-fg',
  info: 'border border-adm-line-strong bg-adm-elev text-adm-fg',
} as const
const icon = { success: CircleCheck, error: CircleAlert, info: Info } as const

function run(toast: AdminToast) {
  toast.action?.run()
  dismiss(toast.id)
}
</script>

<template>
  <ToastProvider label="Avisos" :duration="5000" swipe-direction="right">
    <ToastRoot
      v-for="toast in toasts"
      :key="toast.id"
      :open="true"
      :type="toast.kind === 'error' ? 'foreground' : 'background'"
      :duration="toast.duration"
      :class="[
        'flex min-h-11 items-center gap-2.5 rounded-lg py-2.5 pr-2 pl-3.5 text-[13px] shadow-adm-pop animate-adm-slide motion-reduce:animate-none',
        tone[toast.kind],
      ]"
      @update:open="(value: boolean) => !value && dismiss(toast.id)"
    >
      <component :is="icon[toast.kind]" :class="['size-4 flex-none', toast.kind === 'error' && 'text-adm-danger']" aria-hidden="true" />
      <ToastDescription class="min-w-0 flex-1 break-words">{{ toast.message }}</ToastDescription>
      <ToastAction
        v-if="toast.action"
        :alt-text="toast.action.label"
        :class="[admBtn, 'h-8 px-2 font-semibold underline underline-offset-2', toast.kind === 'success' ? 'hover:bg-adm-ok/10' : 'hover:bg-adm-subtle']"
        @click="run(toast)"
      >
        {{ toast.action.label }}
      </ToastAction>
      <ToastClose :class="[admIconBtn, 'flex-none', toast.kind === 'success' && 'text-adm-ok/80 hover:bg-adm-ok/10 hover:text-adm-ok']" aria-label="Cerrar aviso">
        <X aria-hidden="true" />
      </ToastClose>
    </ToastRoot>
    <ToastViewport
      label="Avisos ({hotkey})"
      class="fixed top-16 right-6 z-[80] m-0 flex w-[420px] max-w-[calc(100vw-1.5rem)] list-none flex-col gap-2 p-0 outline-none max-md:inset-x-3 max-md:top-14 max-md:w-auto"
    />
  </ToastProvider>
</template>
