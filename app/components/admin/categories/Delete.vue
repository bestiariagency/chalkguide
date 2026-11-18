<script setup lang="ts">
import { countsSummary, pluralArticles, type AdminCategory, type CategoryCounts } from '~/utils/admin-categories'

/**
 * Delete with reassignment (design: alertdialog "con reasignación"). With articles the destination is
 * mandatory and the confirm button says how many move; without articles it is a simple confirmation.
 */
const props = defineProps<{
  category: AdminCategory
  counts: CategoryCounts
  /** Other categories (possible destinations). */
  targets: readonly AdminCategory[]
  /** The database refused a delete without destination (pending drafts use the category). */
  needsTarget?: boolean
  busy: boolean
}>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [reassignTo: string | undefined] }>()

const hasArticles = computed(() => props.counts.total > 0)
const needsDestination = computed(() => hasArticles.value || props.needsTarget === true)
// The only category can never be deleted (with or without articles): the dialog explains and blocks.
const stuck = computed(() => !props.targets.length)
const description = computed(() => {
  if (stuck.value) {
    const has = hasArticles.value ? `Tiene ${countsSummary(props.counts)} y es` : 'Es'
    return `${has} la única categoría y siempre debe quedar una, aunque esté vacía. Crea otra antes de eliminarla.`
  }
  const own = `/blog/categoria/${props.category.slug_es}${props.category.slug_en ? ` y /en/blog/category/${props.category.slug_en}` : ''}`
  if (!needsDestination.value) return `No tiene artículos. Al eliminarla, sus URL (${own}) dejarán de existir, sin redirección.`
  const lead = hasArticles.value
    ? `Tiene ${countsSummary(props.counts)}.`
    : 'No tiene artículos, pero hay borradores de cambios pendientes que la usan.'
  const what = hasArticles.value ? 'Elige a qué categoría moverlos.' : 'Elige a qué categoría moverlos para poder eliminarla.'
  return `${lead} ${what} Sus URL (${own}), también las antiguas, redirigirán (301) a la categoría de destino. Las URL de los artículos no cambian.`
})
</script>

<template>
  <AdminConfirmDelete
    v-model:open="open"
    :level="stuck ? 'in-use' : needsDestination ? 'reassign' : 'simple'"
    :title="`¿Eliminar la categoría «${category.name_es}»?`"
    :description="description"
    :confirm-label="hasArticles ? `Mover ${pluralArticles(counts.total)} y eliminar` : needsTarget ? 'Mover a otra categoría y eliminar' : 'Eliminar categoría'"
    :targets="targets.map((c) => ({ value: c.id, label: c.name_es }))"
    :target-label="hasArticles ? `Mover ${pluralArticles(counts.total)} a` : 'Mover los borradores pendientes a'"
    :target-help="`${counts.total === 0 ? 'Los borradores pasan a esa categoría.' : `${counts.total === 1 ? 'Queda' : 'Quedan'} al final del orden de esa categoría.`}`"
    :busy="busy"
    @confirm="emit('confirm', $event)"
  />
</template>
