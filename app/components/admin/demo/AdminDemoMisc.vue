<script setup lang="ts">
/** Showcase: status badges, toasts, state blocks and the sortable list. */
const { success, error, info } = useAdminToast()

const categories = ref(DEMO_CATEGORIES.map((c) => ({ ...c })))
const statuses: { kind: AdminStatusKind; label?: string; changes?: number }[] = [
  { kind: 'draft' },
  { kind: 'scheduled' },
  { kind: 'published' },
  { kind: 'revised', changes: 3 },
  { kind: 'hidden' },
  { kind: 'new' },
  { kind: 'visible' },
  { kind: 'hidden', label: 'Oculta' },
  { kind: 'pending' },
  { kind: 'active' },
  { kind: 'unconfirmed' },
  { kind: 'unsubscribed' },
  { kind: 'bounced' },
]

function onReorder(_: unknown, moved: { from: number; to: number }) {
  const previous = [...categories.value]
  success({
    message: `Orden guardado (posición ${moved.from + 1} a ${moved.to + 1})`,
    action: { label: 'Deshacer', run: () => (categories.value = previous) },
  })
}
</script>

<template>
  <div class="grid gap-8 lg:grid-cols-2">
    <div class="space-y-6">
      <div>
        <h3 class="mb-2 text-sm font-semibold">Insignias de estado</h3>
        <div class="flex flex-wrap gap-2">
          <AdminStatusChip v-for="(s, i) in statuses" :key="i" :status="s.kind" :label="s.label" :changes="s.changes" />
        </div>
      </div>
      <div>
        <h3 class="mb-2 text-sm font-semibold">Toasts</h3>
        <div class="flex flex-wrap gap-2">
          <button type="button" :class="admBtnGhost" @click="success({ message: 'Artículo guardado', action: { label: 'Deshacer', run: () => info('Deshecho') } })">Éxito</button>
          <button type="button" :class="admBtnGhost" @click="error({ message: 'No se ha podido guardar.', action: { label: 'Reintentar', run: () => success('Guardado') } })">Error</button>
          <button type="button" :class="admBtnGhost" @click="info('Se ha copiado el enlace')">Info</button>
        </div>
      </div>
      <div>
        <h3 class="mb-2 text-sm font-semibold">Vacío y error</h3>
        <div class="grid gap-3 sm:grid-cols-2">
          <div class="rounded-lg border border-adm-line"><AdminStateBlock kind="empty" title="Aún no hay artículos" description="Empieza por el que más te pregunten."><button type="button" :class="admBtnPrimary">Nuevo artículo</button></AdminStateBlock></div>
          <div class="rounded-lg border border-adm-line"><AdminStateBlock kind="error" code="DEMO-500" @retry="info('Reintentando…')" /></div>
        </div>
      </div>
    </div>
    <div>
      <h3 class="mb-2 text-sm font-semibold">Lista ordenable</h3>
      <p class="mb-2 text-xs text-adm-meta">Arrastra el asa, o con teclado: Espacio levanta, flechas mueven, Espacio suelta, Esc cancela.</p>
      <AdminSortableList v-model:items="categories" label="Orden de las categorías" :item-key="(c) => c.id" :item-label="(c) => c.label" @reorder="onReorder">
        <template #item="{ item }"><span class="text-[13px]">{{ item.label }}</span></template>
      </AdminSortableList>
    </div>
  </div>
</template>
