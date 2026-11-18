<script setup lang="ts">
import { Check, Link2, Lock, LockOpen, TriangleAlert } from 'lucide-vue-next'

/**
 * URL (slug) field. Follows `source` (the title) until edited or locked; input is normalised as you
 * type (accents, spaces, symbols). Published content: read-only, and "Cambiar…" asks for
 * confirmation because the old URL stops working and a redirect is created. The parent decides
 * availability (`taken`/`suggestion`, `available`).
 */
const props = defineProps<{
  label?: string
  lang?: 'ES' | 'EN'
  prefix: string
  /** Text the slug follows (title). */
  source?: string
  /** The URL is already public: fixed until the user confirms the change. */
  published?: boolean
  /** Published slug, to explain the redirect. Defaults to the first value received. */
  original?: string
  taken?: boolean
  suggestion?: string
  available?: boolean
  error?: string
  /** Fixed value (published, view only): hides "Cambiar…" and "Disponible". */
  readonly?: boolean
  /** What the slug follows, for the help text (default "título"). */
  sourceNoun?: string
  /** Marks the field as required (default true). */
  required?: boolean
}>()
const model = defineModel<string>({ default: '' })

const initial = props.original ?? model.value
const confirming = ref(false)
const unlocked = ref(!props.published)
const pinned = ref(!!model.value && model.value !== slugify(props.source ?? ''))
const corrected = ref(false)

/** What the input shows: lets us overwrite characters the model would otherwise leave on screen. */
const text = ref(model.value)

watch(
  () => props.source,
  (source) => {
    if (!pinned.value && unlocked.value && source !== undefined) text.value = model.value = slugify(source)
  },
  { immediate: true },
)
watch(model, (value) => (text.value = value))

function onInput(value: string) {
  const clean = slugifyTyping(value)
  corrected.value = clean !== value && value !== ''
  pinned.value = true
  text.value = value
  model.value = clean
  void nextTick(() => (text.value = clean))
}
function togglePin() {
  pinned.value = !pinned.value
  if (!pinned.value) model.value = slugify(props.source ?? model.value)
}
function onBlur() {
  model.value = slugify(model.value)
}
function unlock() {
  unlocked.value = true
  confirming.value = false
}
const redirects = computed(() => !!props.published && unlocked.value && !!initial && model.value !== initial)
const message = computed(() => (props.taken ? `Ya existe algo con esta URL.` : props.error))
const showAvailable = computed(() => !props.readonly && unlocked.value && model.value !== initial && !!props.available && !!model.value && !message.value)
const help = computed(() => {
  if (props.published && !unlocked.value) return 'URL pública: no se cambia sola. Cambiarla deja de funcionar la anterior.'
  if (corrected.value) return 'Hemos corregido los caracteres no válidos.'
  if (showAvailable.value) return 'Disponible'
  return pinned.value ? `Fija: ya no sigue al ${props.sourceNoun ?? 'título'}.` : `Se genera del ${props.sourceNoun ?? 'título'} hasta que la edites.`
})
</script>

<template>
  <div>
    <AdminTextField
      :model-value="text"
      :label="label ?? 'URL'"
      :lang="lang"
      :prefix="prefix"
      :readonly="!unlocked || readonly"
      :error="message"
      :help="showAvailable ? undefined : help"
      mono
      :required="props.required !== false"
      autocomplete="off"
      @update:model-value="onInput"
      @blur="onBlur"
    />
    <p v-if="showAvailable" class="mt-1.5 flex items-center gap-1.5 text-xs text-adm-ok">
      <Check class="size-3.5" aria-hidden="true" />Disponible
    </p>
    <div class="mt-1.5 flex flex-wrap items-center gap-2">
      <button v-if="taken && suggestion" type="button" class="text-xs underline underline-offset-2" @click="onInput(suggestion)">
        Usar {{ suggestion }}
      </button>
      <button
        v-if="published && !unlocked && !readonly"
        type="button"
        :class="[admBtnGhost, 'h-7 text-xs max-md:h-11']"
        @click="confirming = true"
      >
        <Lock aria-hidden="true" />Cambiar…
      </button>
      <button
        v-else-if="!published && !readonly"
        type="button"
        :class="[admBtnQuiet, '-ml-2 h-7 text-xs max-md:h-11']"
        @click="togglePin"
      >
        <component :is="pinned ? Link2 : Lock" aria-hidden="true" />{{ pinned ? 'Seguir al título' : 'Bloquear la URL' }}
      </button>
    </div>
    <p v-if="redirects" class="mt-2 flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5" role="status">
      <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
      <span>Al guardar, <span class="font-mono text-xs">{{ prefix }}{{ initial }}</span> redirigirá a la nueva URL.</span>
    </p>
    <AdminModal v-model:open="confirming" alert title="¿Cambiar la URL de algo publicado?" description="La URL actual dejará de funcionar para quien la tenga guardada. Crearemos una redirección automática hacia la nueva, pero los enlaces externos y el posicionamiento tardarán en actualizarse.">
      <template #footer>
        <button type="button" :class="admBtnGhost" data-autofocus @click="confirming = false">Mantener la URL</button>
        <button type="button" :class="admBtnPrimary" @click="unlock"><LockOpen aria-hidden="true" />Cambiar la URL</button>
      </template>
    </AdminModal>
  </div>
</template>
