<script setup lang="ts">
/** Settings conflict (README §17.2): nothing was saved; see the server's version or save mine over it. */
const props = defineProps<{ sections: string[]; theirs: { label: string; value: string }[] | null; busy: boolean; view: () => Promise<unknown> }>()
defineEmits<{ mine: [] }>()
const viewing = ref(false)
async function viewOther() {
  viewing.value = true
  try { await props.view() } finally { viewing.value = false }
}
</script>

<template>
  <div class="space-y-2 rounded-md bg-adm-warn-soft px-3 py-2.5 text-sm text-adm-warn" role="alert">
    <div class="flex flex-wrap items-start gap-x-3 gap-y-2">
      <span class="min-w-[220px] flex-1">
        <b>Otra sesión ha cambiado estos ajustes</b><template v-if="sections.length"> ({{ sections.join(', ') }})</template> desde que abriste la pantalla. No se ha guardado nada. «Descartar» recarga lo último del servidor.
      </span>
      <span class="flex flex-wrap gap-x-4 gap-y-1">
        <button type="button" class="font-medium underline underline-offset-2 disabled:opacity-60 max-md:min-h-11" :disabled="viewing" @click="viewOther">{{ viewing ? 'Cargando…' : 'Ver la otra versión' }}</button>
        <button type="button" class="font-medium underline underline-offset-2 disabled:opacity-60 max-md:min-h-11" :disabled="busy" @click="$emit('mine')">Guardar la mía</button>
      </span>
    </div>
    <dl v-if="theirs" class="grid gap-x-3 gap-y-1 border-t border-adm-warn/20 pt-2 text-xs sm:grid-cols-[max-content_minmax(0,1fr)]">
      <template v-for="item in theirs" :key="item.label">
        <dt class="font-medium">{{ item.label }}</dt>
        <dd class="break-words">{{ item.value }}</dd>
      </template>
    </dl>
  </div>
</template>
