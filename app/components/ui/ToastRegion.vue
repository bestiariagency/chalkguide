<script setup lang="ts">
const { toasts, dismiss } = useToast()
// The comparison tray (sticky, ~64px) must stay reachable: lift toasts above it.
const trayVisible = useState('compare-tray-visible', () => false)
</script>

<template>
  <div
    class="pointer-events-none fixed inset-x-4 bottom-[calc(16px+env(safe-area-inset-bottom))] z-[70] flex flex-col gap-2 md:inset-x-auto md:right-6 md:bottom-6 md:w-[380px]"
    :class="trayVisible && '!bottom-[calc(88px+env(safe-area-inset-bottom))] md:!bottom-24'"
  >
    <TransitionGroup
      enter-active-class="transition duration-300 ease-out"
      enter-from-class="opacity-0 translate-y-2"
      leave-active-class="transition duration-200 ease-in"
      leave-to-class="opacity-0 translate-y-2"
    >
      <UiToast
        v-for="toast in toasts"
        :key="toast.id"
        :toast="toast"
        @dismiss="dismiss(toast.id)"
      />
    </TransitionGroup>
  </div>
</template>
