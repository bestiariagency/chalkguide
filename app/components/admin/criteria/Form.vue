<script setup lang="ts">
import { CircleAlert, Info, Loader2, Lock, Trash2 } from 'lucide-vue-next'
import {
  MAX_DESCRIPTION,
  MAX_KEY,
  MAX_NAME,
  criterionKeyFrom,
  criterionToForm,
  emptyCriterionForm,
  noteCount,
  validateCriterion,
  type AdminCriterion,
  type CriterionError,
  type CriterionErrors,
  type CriterionForm,
  type CriterionUsage,
} from '~/utils/admin-criteria'

/**
 * Create / edit drawer (right panel on desktop, bottom sheet on mobile); the parent mounts it with
 * `v-if`. New: the key follows the name until edited. Edit: the key is read-only (formulas, per-criterion
 * averages and exports use it). Server errors arrive in `serverError` and mark their field.
 */
const props = defineProps<{
  criterion?: AdminCriterion
  /** Keys already used in the category. */
  takenKeys: ReadonlySet<string>
  categoryLabel: string
  usage: CriterionUsage
  busy: boolean
  serverError?: CriterionError
}>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ save: [form: CriterionForm]; deactivate: []; reactivate: []; remove: [] }>()

const isNew = computed(() => !props.criterion)
const form = reactive<CriterionForm>(props.criterion ? criterionToForm(props.criterion) : emptyCriterionForm())
const errors = ref<CriterionErrors>({})
const keyTouched = ref(false)
watch(() => form.name_es, (name) => { if (isNew.value && !keyTouched.value) form.key = criterionKeyFrom(name) })
watch(() => props.serverError, (e) => { if (e?.field) errors.value = { ...errors.value, [e.field]: e.message } })

function focusField(field: keyof CriterionForm) {
  document.querySelector<HTMLElement>(`#criterion-form [name="${field}"]`)?.focus()
}
function submit() {
  errors.value = validateCriterion(form, { isNew: isNew.value, takenKeys: props.takenKeys, categoryLabel: props.categoryLabel })
  const first = Object.keys(errors.value)[0] as keyof CriterionForm | undefined
  if (first) { nextTick(() => focusField(first)); return }
  emit('save', { ...form })
}

const notes = computed(() => noteCount(props.usage))
const locked = computed(() => props.criterion?.used_in_formula === true)
const canDelete = computed(() => props.usage.can_delete && !locked.value && notes.value === 0)
const deleteWhy = computed(() => {
  if (canDelete.value) return ''
  const n = `${notes.value} ${notes.value === 1 ? 'nota guardada' : 'notas guardadas'}`
  if (locked.value) return `No se puede eliminar: ${notes.value ? `tiene ${n} y ` : ''}entra en un índice.`
  if (notes.value) return `No se puede eliminar: tiene ${n}. ${props.criterion?.is_active ? 'Desactivar lo saca de medias e índices y conserva las notas.' : 'Seguirá inactivo con sus notas.'}`
  return 'No se puede eliminar: está citado en borradores de fichas. Desactivarlo lo saca de medias e índices.'
})
const deleteWhyId = `crit-del-${useId()}`
const title = computed(() => (props.criterion ? `Editar «${props.criterion.name_es}»` : `Nuevo criterio · ${props.categoryLabel}`))
const previewName = computed(() => form.name_es.trim() || 'Nombre del criterio')
</script>

<template>
  <AdminModal v-model:open="open" :title="title" placement="right" :busy="busy">
    <form id="criterion-form" class="space-y-5" novalidate @submit.prevent="submit">
      <p v-if="serverError" class="flex items-start gap-2 rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px] leading-5 text-adm-danger" role="alert">
        <CircleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />
        <span>
          {{ serverError.message }}
          <button v-if="serverError.field" type="button" class="underline underline-offset-2" @click="focusField(serverError.field)">Ir al campo</button>
        </span>
      </p>
      <p v-if="isNew" class="flex items-start gap-2 rounded-lg bg-adm-subtle px-3 py-2 text-[13px] leading-5">
        <Info class="mt-0.5 size-4 flex-none text-adm-info" aria-hidden="true" />
        <span>Se añade al final de {{ categoryLabel }}. Las fichas ya puntuadas no tienen nota en este criterio: su media no cambia hasta que lo puntúes.</span>
      </p>

      <AdminLangPair legend="Nombre">
        <template #es><AdminTextField v-model="form.name_es" label="Nombre" lang="ES" name="name_es" required :max="MAX_NAME" :error="errors.name_es" data-autofocus /></template>
        <template #en><AdminTextField v-model="form.name_en" label="Nombre" lang="EN" name="name_en" required :max="MAX_NAME" :error="errors.name_en" /></template>
      </AdminLangPair>

      <div v-if="!isNew">
        <span :class="admLabel">Clave interna</span>
        <p class="flex items-center gap-2 text-sm"><Lock class="size-3.5 text-adm-muted" aria-hidden="true" /><span class="font-mono text-[13px]">{{ criterion!.key }}</span></p>
        <p class="mt-1 text-xs text-adm-meta">Fija desde que se crea: la usan las fórmulas, las medias de lectores y las exportaciones.</p>
      </div>
      <AdminTextField
        v-else
        v-model="form.key"
        label="Clave interna"
        name="key"
        required
        mono
        :max="MAX_KEY"
        :error="errors.key"
        help="Sigue al nombre. Minúsculas, números y guion bajo (a-z 0-9 _). No se podrá cambiar después."
        @update:model-value="keyTouched = true"
      />

      <AdminLangPair legend="Ayuda al puntuar">
        <template #es><AdminTextArea v-model="form.description_es" label="Ayuda al puntuar" lang="ES" name="description_es" :max="MAX_DESCRIPTION" placeholder="Opcional. Qué miras para dar un 1 o un 5." :error="errors.description_es" help="Sale debajo del nombre al puntuar. No se publica en la ficha." /></template>
        <template #en><AdminTextArea v-model="form.description_en" label="Ayuda al puntuar" lang="EN" name="description_en" :max="MAX_DESCRIPTION" placeholder="Opcional" :error="errors.description_en" /></template>
      </AdminLangPair>

      <div>
        <p :class="admLabel">Así sale al puntuar</p>
        <div :class="[admCard, 'p-3']">
          <p class="text-sm">{{ previewName }}</p>
          <p v-if="form.description_es.trim()" class="mt-0.5 text-xs text-adm-meta">{{ form.description_es }}</p>
          <div class="mt-2 inline-flex gap-0.5 rounded-md border border-adm-line-strong p-0.5 text-[13px] text-adm-meta" aria-hidden="true">
            <span v-for="n in 5" :key="n" :class="['grid h-7 min-w-9 place-items-center rounded', n === 5 && 'bg-adm-primary text-adm-on-primary']">{{ n }}</span>
            <span class="grid h-7 place-items-center px-2">Sin nota</span>
          </div>
        </div>
      </div>

      <AdminCriteriaState v-if="criterion" :criterion="criterion" :usage="usage" :busy="busy" @deactivate="emit('deactivate')" @reactivate="emit('reactivate')" />
      <p v-if="criterion && !canDelete" :id="deleteWhyId" class="-mt-2 text-xs text-adm-meta">{{ deleteWhy }}</p>
    </form>
    <template #footer>
      <div v-if="criterion" class="sm:mr-auto">
        <button type="button" :class="admBtnDangerGhost" :disabled="busy || !canDelete" :aria-describedby="canDelete ? undefined : deleteWhyId" @click="emit('remove')">
          <Trash2 aria-hidden="true" />Eliminar…
        </button>
      </div>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="submit" form="criterion-form" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Guardar
      </button>
    </template>
  </AdminModal>
</template>
