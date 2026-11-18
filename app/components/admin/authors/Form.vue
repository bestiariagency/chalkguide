<script setup lang="ts">
import { CircleAlert, Loader2, Trash2 } from 'lucide-vue-next'
import { slugify } from '~/utils/admin-form'
import { pluralArticles } from '~/utils/admin-categories'
import type { AdminMedia } from '~/utils/admin-media'
import {
  AUTHOR_LIMITS,
  publishedText,
  authorSlugFrom,
  authorToForm,
  emptyAuthorForm,
  enStatus,
  validateAuthor,
  type AdminAuthor,
  type AuthorCounts,
  type AuthorErrors,
  type AuthorForm,
} from '~/utils/admin-authors'

/**
 * Create / edit drawer of an author (440 px; bottom sheet under 768 px). Saved at once, no draft. The
 * parent mounts it with `v-if` so it always starts from the author. Closing with edits asks first.
 * The identifier follows the name only when creating; it is not a public URL.
 */
const props = defineProps<{
  author?: AdminAuthor
  authors: readonly AdminAuthor[]
  counts: AuthorCounts
  busy: boolean
  /** The database refused the identifier (`authors_slug_key`). */
  slugTaken: boolean
}>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ save: [form: AuthorForm]; remove: [] }>()

const form = reactive<AuthorForm>(props.author ? authorToForm(props.author) : emptyAuthorForm())
const initial = JSON.stringify(form)
const photo = ref<AdminMedia | null>(props.author?.photo ?? null)
const errors = ref<AuthorErrors>({})
const slugPinned = ref(!!props.author)
const discarding = ref(false)

const dirty = computed(() => JSON.stringify(form) !== initial)
const takenLocally = computed(() => props.authors.some((a) => a.id !== props.author?.id && a.slug === form.slug.trim()))
const slugError = computed(() => errors.value.slug ?? (takenLocally.value || (props.slugTaken && form.slug === lastSubmitted.value) ? 'Ya hay un autor con este identificador. Cámbialo.' : undefined))
const lastSubmitted = ref('')
const en = computed(() => enStatus(form.role_en, form.bio_en))

watch(() => form.name, (name) => { if (!slugPinned.value) form.slug = authorSlugFrom(name) })
watch(() => form.slug, () => { errors.value = { ...errors.value, slug: undefined } })

function pick(media: AdminMedia | null) {
  photo.value = media
  form.photo_media_id = media?.id ?? null
  errors.value = { ...errors.value, photo_media_id: undefined }
}
function submit() {
  form.slug = slugify(form.slug)
  errors.value = validateAuthor(form, photo.value)
  if (takenLocally.value) errors.value.slug = 'Ya hay un autor con este identificador. Cámbialo.'
  const first = (['name', 'slug', 'role_es', 'role_en', 'bio_es', 'bio_en', 'photo_media_id'] as const).find((k) => errors.value[k])
  if (first) return void focusField(first)
  lastSubmitted.value = form.slug
  emit('save', { ...form })
}
const focusField = (name: string) => document.querySelector<HTMLElement>(`#author-form [name="${name}"]`)?.focus()

/** Esc, the scrim and the X ask before throwing away edits. */
const shown = computed({
  get: () => open.value,
  set: (value) => {
    if (value || props.busy) open.value = value
    else if (dirty.value) discarding.value = true
    else open.value = false
  },
})
const title = computed(() => (props.author ? `Editar «${props.author.name}»` : 'Nuevo autor'))
</script>

<template>
  <AdminModal v-model:open="shown" :title="title" placement="right" :busy="busy">
    <div v-if="slugTaken && form.slug === lastSubmitted" class="mb-4 flex gap-2 rounded-md bg-adm-danger-soft px-3 py-2.5 text-sm text-adm-danger" role="alert">
      <CircleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />
      <span>No se ha podido guardar: ya hay un autor con el identificador <span class="font-mono">{{ form.slug }}</span>. <button type="button" class="underline underline-offset-2" @click="focusField('slug')">Cámbialo</button>.</span>
    </div>
    <form id="author-form" class="space-y-5" novalidate @submit.prevent="submit">
      <AdminAuthorsPhoto
        :media="photo"
        :name="form.name"
        shape="circle"
        subtitle="Para la firma de este autor. Mejor vertical: se recorta en círculo."
        help="Al guardar, la foto pasa a ser pública (sale en su firma). Al quitarla, deja de salir en el sitio si no se usa en otra página; quien ya tenga el enlace al archivo aún puede abrirlo."
        empty-help="Sin foto, la firma sale sin círculo."
        field-name="photo_media_id"
        :error="errors.photo_media_id"
        @pick="pick"
      />
      <AdminTextField v-model="form.name" name="name" label="Nombre" required :max="AUTHOR_LIMITS.name" :error="errors.name" :data-autofocus="author ? undefined : ''" placeholder="Nombre con el que firma" />
      <AdminTextField v-model="form.slug" name="slug" label="Identificador" mono :maxlength="AUTHOR_LIMITS.slug" :error="slugError" help="Se rellena con el nombre al crear. Lo usan los datos estructurados para buscadores; no es una URL pública. Usa minúsculas, números y guiones." @update:model-value="slugPinned = true" />
      <AdminLangPair legend="Rol">
        <template #es><AdminTextField v-model="form.role_es" name="role_es" label="Rol" lang="ES" :max="AUTHOR_LIMITS.role" :error="errors.role_es" placeholder="Debajo del nombre" /></template>
        <template #en><AdminTextField v-model="form.role_en" name="role_en" label="Rol" lang="EN" :max="AUTHOR_LIMITS.role" :error="errors.role_en" placeholder="Opcional" /></template>
      </AdminLangPair>
      <AdminLangPair legend="Bio">
        <template #es><AdminTextArea v-model="form.bio_es" name="bio_es" label="Bio" lang="ES" :rows="3" :max="AUTHOR_LIMITS.bio" :error="errors.bio_es" placeholder="Una o dos frases para el final del artículo" /></template>
        <template #en><AdminTextArea v-model="form.bio_en" name="bio_en" label="Bio" lang="EN" :rows="3" :max="AUTHOR_LIMITS.bio" :error="errors.bio_en" placeholder="Opcional" /></template>
      </AdminLangPair>
      <p class="-mt-2 flex items-center gap-1.5 text-xs text-adm-meta" role="status"><AdminAuthorsEnBadge :role="form.role_en" :bio="form.bio_en" />{{ en.text }}</p>

      <section aria-labelledby="author-preview" :class="[admCard, 'p-4']">
        <h3 id="author-preview" class="text-sm font-semibold">Así firma</h3>
        <div class="mt-3 flex items-start gap-3">
          <AdminAuthorsAvatar v-if="photo" :media="photo" :name="form.name" size="md" />
          <div class="min-w-0">
            <p class="text-sm font-semibold">{{ form.name.trim() || 'Nombre' }}</p>
            <p v-if="form.role_es.trim()" class="text-xs text-adm-meta">{{ form.role_es.trim() }}</p>
            <p v-if="form.bio_es.trim()" class="mt-1 text-sm break-words">{{ form.bio_es.trim() }}</p>
          </div>
        </div>
        <p class="mt-3 text-xs text-adm-meta">Vista aproximada: la real usa la tipografía y los colores del sitio.</p>
      </section>

      <section v-if="author" aria-labelledby="author-use" class="border-t border-adm-line pt-4">
        <h3 id="author-use" class="text-sm font-semibold">Dónde firma</h3>
        <div class="mt-2 flex items-center gap-3 text-sm">
          <span class="tabular-nums">{{ counts.total ? `${pluralArticles(counts.total)} · ${publishedText(counts.live)}` : 'Sin artículos' }}</span>
          <NuxtLink v-if="counts.total" :to="`${adminPath('articulos')}?autor=${author.id}`" class="ml-auto inline-flex items-center text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11">Ver en Artículos</NuxtLink>
        </div>
      </section>
    </form>
    <template #footer>
      <button v-if="author" type="button" :class="[admBtnDangerGhost, 'sm:mr-auto']" :disabled="busy" @click="emit('remove')">
        <Trash2 aria-hidden="true" />Eliminar…
      </button>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="shown = false">Cancelar</button>
      <button type="submit" form="author-form" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />{{ author ? 'Guardar' : 'Crear autor' }}
      </button>
    </template>
    <AdminConfirmDelete
      v-model:open="discarding"
      level="simple"
      stacked
      title="¿Descartar cambios?"
      description="Has editado este autor y no has guardado. Si cierras, se pierden."
      confirm-label="Descartar cambios"
      @confirm="open = false"
    />
  </AdminModal>
</template>
