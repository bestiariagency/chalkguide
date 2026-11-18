<script setup lang="ts">
/** Sticky section index (≥ 1024 px). The current section follows the scroll. */
defineProps<{ sections: { id: string; label: string }[]; current: string }>()
</script>

<template>
  <nav class="sticky top-6 hidden self-start lg:block" aria-label="Secciones de ajustes">
    <a
      v-for="s in sections"
      :key="s.id"
      :href="`#${s.id}`"
      :aria-current="current === s.id ? 'true' : undefined"
      class="block rounded-md px-2.5 py-1.5 text-[13px] text-adm-meta hover:bg-adm-subtle hover:text-adm-fg focus-visible:outline-2 focus-visible:outline-adm-acc aria-[current=true]:bg-adm-subtle aria-[current=true]:font-medium aria-[current=true]:text-adm-fg"
    >{{ s.label }}</a>
  </nav>
</template>
