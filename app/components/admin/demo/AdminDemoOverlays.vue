<script setup lang="ts">
/** Showcase: modal, bottom sheet / drawer and the 4 delete confirmations. */
const modal = ref(false)
const drawer = ref(false)
const confirm = ref<'simple' | 'in-use' | 'reassign' | 'irreversible' | null>(null)
const open = computed({
  get: () => confirm.value !== null,
  set: (value) => !value && (confirm.value = null),
})
const busy = ref(false)
const { success, info } = useAdminToast()

const usages: AdminUsage[] = [
  { label: 'Magnesi Poblenou', where: 'Portada', href: '#' },
  { label: 'Dónde escalar en Barcelona cuando llueve', where: 'Cuerpo ES', href: '#' },
  { label: 'Ajustes · imagen para redes', where: 'OG', href: '#' },
]
const targets = [
  { value: 'empezar', label: 'Empezar a escalar' },
  { value: 'progresion', label: 'Progresión y cuidado' },
]
const config = {
  simple: { title: '¿Eliminar «Magnesio líquido o en polvo»?', description: 'Es un borrador y nunca se ha publicado. Queda en el registro de actividad por si hay que recuperarlo.', confirmLabel: 'Eliminar borrador' },
  'in-use': { title: 'No se puede borrar «sala-bloque-poblenou.jpg»', description: 'Está en uso en 3 sitios. Quítala o cámbiala por otra en cada uno y vuelve a intentarlo.', confirmLabel: 'Eliminar' },
  reassign: { title: '¿Eliminar la categoría «Costes»?', description: 'Tiene 4 artículos (3 publicados). Antes hay que moverlos a otra categoría; sus URL no cambian.', confirmLabel: 'Mover y eliminar' },
  irreversible: { title: '¿Borrar los datos de marta.g@ejemplo.test?', description: 'Solicitud de supresión (RGPD). Se borra el registro y su consentimiento. No se puede deshacer.', confirmLabel: 'Borrar para siempre' },
}
const levels = [
  { value: 'simple', label: 'Simple' },
  { value: 'in-use', label: 'Medio en uso' },
  { value: 'reassign', label: 'Con reasignación' },
  { value: 'irreversible', label: 'Irreversible' },
] as const

function run() {
  busy.value = true
  setTimeout(() => {
    busy.value = false
    confirm.value = null
    success({ message: 'Eliminado (ejemplo)', action: { label: 'Deshacer', run: () => info('Deshecho (ejemplo)') } })
  }, 700)
}
</script>

<template>
  <div class="space-y-4">
    <div class="flex flex-wrap gap-2">
      <button type="button" :class="admBtnGhost" @click="modal = true">Abrir modal</button>
      <button type="button" :class="admBtnGhost" @click="drawer = true">Abrir drawer (hoja en móvil)</button>
      <button v-for="level in levels" :key="level.value" type="button" :class="admBtnDangerGhost" @click="confirm = level.value">
        Borrar · {{ level.label }}
      </button>
    </div>

    <AdminModal v-model:open="modal" title="Nueva categoría" description="Foco atrapado, Esc cierra y el foco vuelve al botón.">
      <AdminTextField label="Nombre" required />
      <template #footer>
        <button type="button" :class="admBtnGhost" @click="modal = false">Cancelar</button>
        <button type="button" :class="admBtnPrimary" @click="modal = false">Guardar</button>
      </template>
    </AdminModal>
    <AdminModal v-model:open="drawer" placement="right" title="Editar categoría" description="Drawer de 440 px; por debajo de 768 px es una hoja inferior.">
      <div class="space-y-4"><AdminTextField label="Nombre" lang="ES" /><AdminTextField label="Nombre" lang="EN" /></div>
      <template #footer>
        <button type="button" :class="admBtnGhost" @click="drawer = false">Cancelar</button>
        <button type="button" :class="admBtnPrimary" @click="drawer = false">Guardar</button>
      </template>
    </AdminModal>
    <AdminConfirmDelete
      v-if="confirm"
      v-model:open="open"
      v-bind="config[confirm]"
      :level="confirm"
      :busy="busy"
      :usages="usages"
      :targets="targets"
      target-label="Mover los 4 artículos a"
      target-help="Se añaden al final del orden de esa categoría."
      expected="marta.g@ejemplo.test"
      expected-label="Escribe el email para confirmar"
      alternative-label="Reemplazar archivo en su lugar"
      @confirm="run"
      @alternative="(confirm = null), info('Abriría «Reemplazar archivo»')"
    />
  </div>
</template>
