<script setup lang="ts">
/** Three uneven bars (24/15/20 px) in a 44 px target; morphs to an X when `open` (D42). */
defineProps<{ open: boolean; label: string }>()
</script>

<template>
  <button
    type="button"
    :aria-label="label"
    :aria-expanded="open"
    :data-open="open"
    class="group -mr-2.5 grid size-11 place-items-center rounded-md text-white"
  >
    <span
      aria-hidden="true"
      class="grid w-6 justify-items-end gap-[5px] transition-transform duration-300 ease-out group-active:scale-92 motion-reduce:transition-none"
    >
      <i
        class="block h-[3px] w-6 rounded-xs bg-current transition-[translate,rotate,width,opacity] duration-300 ease-out group-data-[open=true]:translate-y-2 group-data-[open=true]:rotate-45 motion-reduce:transition-none"
      />
      <i
        class="block h-[3px] w-[15px] rounded-xs bg-current transition-[translate,rotate,width,opacity] duration-300 ease-out group-data-[open=true]:opacity-0 motion-reduce:transition-none"
      />
      <i
        class="block h-[3px] w-5 rounded-xs bg-current transition-[translate,rotate,width,opacity] duration-300 ease-out group-data-[open=true]:w-6 group-data-[open=true]:-translate-y-2 group-data-[open=true]:-rotate-45 motion-reduce:transition-none"
      />
    </span>
  </button>
</template>
