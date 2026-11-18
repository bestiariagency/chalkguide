<script setup lang="ts">
import { Loader2, Trash2 } from 'lucide-vue-next'
import {
  categoryToForm,
  emptyCategoryForm,
  takenCategorySlugs,
  validateCategory,
  type AdminCategory,
  type CategoryErrors,
  type CategoryForm,
} from '~/utils/admin-categories'
import { uniqueSlug } from '~/utils/admin-articles'

/**
 * Create / edit drawer (right panel on desktop, bottom sheet on mobile). The parent mounts it with
 * `v-if` so the form always starts from the category. If the category has live articles its URLs are
 * public: changing a slug asks for confirmation and the database creates the 301 (D24).
 */
const props = defineProps<{
  category?: AdminCategory
  categories: readonly AdminCategory[]
  /** Articles live on the site in this category (its public URLs). */
  live: number
  busy: boolean
  /** Unsaved edits to restore (coming back from the delete dialog). */
  draft?: CategoryForm
}>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ save: [form: CategoryForm]; remove: [draft: CategoryForm] }>()

const form = reactive<CategoryForm>(props.draft ? { ...props.draft } : props.category ? categoryToForm(props.category) : emptyCategoryForm())
const errors = ref<CategoryErrors>({})
const taken = computed(() => takenCategorySlugs(props.categories, props.category?.id))
const takenEs = computed(() => !!form.slug_es && taken.value.es.has(form.slug_es))
const takenEn = computed(() => !!form.slug_en && taken.value.en.has(form.slug_en))
const dirtyEs = computed(() => form.slug_es !== props.category?.slug_es)
const dirtyEn = computed(() => form.slug_en !== (props.category?.slug_en ?? ''))

function submit() {
  errors.value = validateCategory(form)
  if (takenEs.value) errors.value.slug_es = 'Ya hay otra categoría con esta URL.'
  if (takenEn.value) errors.value.slug_en = 'Ya hay otra categoría con esta URL.'
  if (Object.keys(errors.value).length) return
  emit('save', { ...form })
}
const title = computed(() => (props.category ? `Editar «${props.category.name_es}»` : 'Nueva categoría'))
</script>

<template>
  <AdminModal v-model:open="open" :title="title" placement="right" :busy="busy">
    <form id="category-form" class="space-y-5" novalidate @submit.prevent="submit">
      <AdminLangPair legend="Nombre">
        <template #es><AdminTextField v-model="form.name_es" label="Nombre" lang="ES" required :error="errors.name_es" :max="80" :data-autofocus="draft ? undefined : ''" /></template>
        <template #en><AdminTextField v-model="form.name_en" label="Nombre" lang="EN" :error="errors.name_en" :max="80" /></template>
      </AdminLangPair>
      <AdminLangPair legend="URL">
        <template #es>
          <AdminSlugField
            v-model="form.slug_es"
            label="URL"
            lang="ES"
            prefix="/blog/categoria/"
            :source="form.name_es"
            :published="!!category && live > 0"
            :taken="takenEs && dirtyEs"
            :suggestion="uniqueSlug(form.slug_es, taken.es)"
            :available="!takenEs"
            :error="errors.slug_es"
          />
        </template>
        <template #en>
          <AdminSlugField
            v-model="form.slug_en"
            label="URL"
            lang="EN"
            :required="false"
            prefix="/en/blog/category/"
            :source="form.name_en"
            :published="!!category?.slug_en && live > 0"
            :taken="takenEn && dirtyEn"
            :suggestion="uniqueSlug(form.slug_en, taken.en)"
            :available="!takenEn"
            :error="errors.slug_en"
          />
          <p class="mt-1.5 text-xs text-adm-meta">Nombre y URL en inglés van juntos: si falta uno, la categoría no aparece en la versión en inglés.</p>
        </template>
      </AdminLangPair>
      <AdminLangPair legend="Descripción">
        <template #es><AdminTextArea v-model="form.description_es" label="Descripción" lang="ES" seo="description" :error="errors.description_es" help="También es la descripción para buscadores." /></template>
        <template #en><AdminTextArea v-model="form.description_en" label="Descripción" lang="EN" seo="description" placeholder="Opcional" :error="errors.description_en" /></template>
      </AdminLangPair>
      <AdminCategoriesColor v-model="form.color" :error="errors.color" />
    </form>
    <template #footer>
      <button v-if="category" type="button" :class="[admBtnDangerGhost, 'sm:mr-auto']" :disabled="busy" :data-autofocus="draft ? '' : undefined" @click="emit('remove', { ...form })">
        <Trash2 aria-hidden="true" />Eliminar…
      </button>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="submit" form="category-form" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Guardar
      </button>
    </template>
  </AdminModal>
</template>
