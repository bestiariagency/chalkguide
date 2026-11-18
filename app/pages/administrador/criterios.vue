<script setup lang="ts">
import { ListChecks, Plus } from 'lucide-vue-next'
import { CRITERION_CATEGORIES, criterionCategoryOf, type AdminCriterion, type CriterionCategory, type CriterionForm } from '~/utils/admin-criteria'

/**
 * Grading criteria (F6.10, docs/design/admin/criterios.html): one list per item category (in the URL:
 * `?categoria=gym|resoler|shoe`), sortable, with inactive ones apart, the "where they count" panel and
 * a preview of a real item's score block. Edit drawer, deactivate with consequences and delete.
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Criterios de nota')

const route = useRoute()
const category = computed<CriterionCategory>({
  get: () => criterionCategoryOf(route.query.categoria),
  set: (value) => void navigateTo({ query: { ...route.query, categoria: value }, replace: true }),
})
const crit = useAdminCriteria(category)
const { active, inactive } = crit
const loading = computed(() => crit.list.status.value === 'pending')
const showSkeleton = useDelayedFlag(loading, 300)
const errorText = computed(() => (crit.list.error.value ? criterionError(crit.list.error.value).message : undefined))
const empty = computed(() => !loading.value && !errorText.value && !crit.mine.value.length)

const options = computed(() =>
  CRITERION_CATEGORIES.map((c) => ({ value: c.value, label: `${c.label} ${crit.activeCounts.value[c.value] ?? 0}` })),
)
const takenKeys = computed(() => new Set(crit.mine.value.map((c) => c.key)))

/** Edit drawer state: `criterion` undefined means "new". */
const editing = ref<{ criterion?: AdminCriterion }>()
const deactivating = ref<AdminCriterion>()
const removing = ref<AdminCriterion>()
watch(category, () => { editing.value = undefined })

function openEdit(criterion?: AdminCriterion) {
  crit.formError.value = undefined
  editing.value = { criterion }
}
async function save(form: CriterionForm) {
  if (await crit.save(editing.value?.criterion, form)) editing.value = undefined
}
/** With notes it asks first; without them it just turns off (toast with Deshacer). */
async function askDeactivate(criterion: AdminCriterion) {
  if (crit.hasNotes(criterion)) deactivating.value = criterion
  else if (await crit.deactivate(criterion)) editing.value = undefined
}
async function confirmDeactivate() {
  if (deactivating.value && (await crit.deactivate(deactivating.value))) {
    deactivating.value = undefined
    editing.value = undefined
  }
}
async function reactivate(criterion: AdminCriterion) {
  if (await crit.reactivate(criterion)) editing.value = undefined
}
async function confirmRemove() {
  if (removing.value && (await crit.remove(removing.value))) {
    removing.value = undefined
    editing.value = undefined
  }
}
</script>

<template>
  <div>
    <AdminPageBar title="Criterios de nota">
      <button type="button" :class="admBtnPrimary" @click="openEdit()">
        <Plus aria-hidden="true" /><span class="max-sm:hidden">Nuevo criterio</span><span class="sm:hidden">Nuevo</span>
      </button>
    </AdminPageBar>

    <div class="max-w-[1440px] space-y-5 px-4 py-6 md:px-6">
      <div class="w-full sm:w-auto">
        <p id="crit-cat" class="sr-only">Categoría de ficha</p>
        <AdminSegmented v-model="category" labelledby="crit-cat" :options="options" fill />
      </div>

      <AdminStateBlock v-if="errorText" kind="error" :description="errorText" @retry="crit.list.refresh()" />
      <AdminCriteriaSkeleton v-else-if="loading" :visible="showSkeleton" />
      <AdminStateBlock
        v-else-if="empty"
        kind="empty"
        :icon="ListChecks"
        :title="`Todavía no hay criterios en ${crit.label.value}`"
        description="Sin criterios, las fichas de esta categoría no muestran nota del autor ni medias de lectores por criterio. Empieza por 3 o 4."
      >
        <button type="button" :class="admBtnPrimary" @click="openEdit()"><Plus aria-hidden="true" />Nuevo criterio</button>
      </AdminStateBlock>
      <div v-else class="grid grid-cols-[minmax(0,1fr)] items-start gap-6 xl:grid-cols-[minmax(0,1fr)_400px]">
        <section class="min-w-0" aria-labelledby="h-list">
          <h2 id="h-list" class="text-sm font-semibold">Orden al puntuar y en la ficha</h2>
          <p class="mt-0.5 text-xs text-adm-meta">Es el orden de tu editor de fichas, del formulario de opiniones y del bloque de notas del sitio. Arrastra desde el asa, usa Espacio y flechas o el menú «Mover».</p>
          <div class="mt-3">
            <AdminCriteriaList v-model:items="active" :usage-of="crit.usageOf" :category-label="crit.label.value" @edit="openEdit" @reorder="crit.reorder()" />
          </div>
          <AdminCriteriaInactive :items="inactive" :usage-of="crit.usageOf" :busy="crit.busy.value" @edit="openEdit" @reactivate="reactivate" />
        </section>
        <AdminCriteriaWhere :active="active" :samples="crit.samples.value" :is-gym="category === 'gym'" />
      </div>
    </div>

    <AdminCriteriaForm
      v-if="editing"
      :key="editing.criterion?.id ?? 'new'"
      :open="true"
      :criterion="editing.criterion"
      :taken-keys="takenKeys"
      :category-label="crit.label.value"
      :usage="crit.usageOf(editing.criterion?.id ?? '')"
      :busy="crit.busy.value"
      :server-error="crit.formError.value"
      @update:open="(v: boolean) => { if (!v) editing = undefined }"
      @save="save"
      @deactivate="askDeactivate(editing!.criterion!)"
      @reactivate="reactivate(editing!.criterion!)"
      @remove="removing = editing!.criterion"
    />
    <AdminCriteriaDeactivate
      v-if="deactivating"
      :open="true"
      stacked
      :criterion="deactivating"
      :usage="crit.usageOf(deactivating.id)"
      :active="active"
      :samples="crit.samples.value"
      :category-label="crit.label.value"
      :busy="crit.busy.value"
      @update:open="(v: boolean) => { if (!v) deactivating = undefined }"
      @confirm="confirmDeactivate"
    />
    <AdminCriteriaDelete
      v-if="removing"
      :open="true"
      stacked
      :criterion="removing"
      :category-label="crit.label.value"
      :busy="crit.busy.value"
      @update:open="(v: boolean) => { if (!v) removing = undefined }"
      @confirm="confirmRemove"
    />
  </div>
</template>
