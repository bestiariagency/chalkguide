<script setup lang="ts">
import { Check, Info, Search, TriangleAlert } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'

/**
 * Picker of existing images (name or alt search). Uploading and managing media is the library
 * (F6.6). Single mode: choosing one emits `select` and closes. `multiple`: images toggle and the
 * footer button emits `select-many` with them (already `exclude`d ones are not offered).
 * `photo` (a person's photo, README §17.3): needs alt in ES and EN (images without it are dimmed and
 * explain why), «Todas / Verticales» filter, public-on-save notice and «Usar esta foto» to confirm.
 * `subtitle` says who the photo is for.
 */
const props = defineProps<{ title: string; multiple?: boolean; exclude?: readonly string[]; photo?: boolean; subtitle?: string }>()
const emit = defineEmits<{ select: [media: AdminMedia]; 'select-many': [media: AdminMedia[]] }>()
const open = defineModel<boolean>('open', { default: false })

const mediaUrl = useMediaUrl()
const { query, items, pending, failed, reload } = useMediaPicker(open)
const chosen = ref<AdminMedia[]>([])
const vertical = ref(false)
const isVertical = (item: AdminMedia) => (item.height ?? 0) > (item.width ?? 0)
const shown = computed(() => items.value.filter((item) => !props.exclude?.includes(item.id) && (!props.photo || !vertical.value || isVertical(item))))
const missingAlt = (item: AdminMedia): string | null => {
  if (!props.photo) return null
  const es = !!item.alt_es?.trim()
  const en = !!item.alt_en?.trim()
  return es && en ? null : !es && !en ? 'Sin alt' : en ? 'Falta alt ES' : 'Falta alt EN'
}
const { error: toastError } = useAdminToast()
const isChosen = (item: AdminMedia) => chosen.value.some((c) => c.id === item.id)
watch(open, (value) => {
  if (!value) return
  chosen.value = []
  vertical.value = false
})

function pick(item: AdminMedia) {
  if (missingAlt(item)) {
    toastError({ message: 'Esta foto no tiene texto alternativo en español e inglés. Complétalo en Medios para poder usarla.', action: { label: 'Ir a Medios (pestaña nueva)', run: () => void navigateTo(adminPath('medios'), { open: { target: '_blank' } }) } })
    return
  }
  if (props.photo) {
    chosen.value = [item]
    return
  }
  if (props.multiple) {
    chosen.value = isChosen(item) ? chosen.value.filter((c) => c.id !== item.id) : [...chosen.value, item]
    return
  }
  emit('select', item)
  open.value = false
}
function confirm() {
  if (props.photo) emit('select', chosen.value[0]!)
  else emit('select-many', chosen.value)
  open.value = false
}
</script>

<template>
  <AdminModal v-model:open="open" :title="title" size="lg" :description="subtitle ?? (multiple ? 'Marca las imágenes que quieras añadir.' : 'Elige una imagen de la biblioteca.')">
    <p v-if="photo" class="mb-4 flex gap-2 rounded-md bg-adm-subtle px-3 py-2.5 text-sm text-adm-fg">
      <Info class="mt-0.5 size-4 flex-none" aria-hidden="true" />La foto que elijas será pública al guardar, aunque hoy no salga en ninguna página.
    </p>
    <div class="mb-4 flex flex-wrap items-center gap-3">
    <div class="relative min-w-0 flex-1 basis-56">
      <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted max-md:hidden" aria-hidden="true" />
      <input v-model="query" type="search" aria-label="Buscar por nombre o texto alternativo" placeholder="Buscar por nombre o alt" :class="[admInput, 'md:pl-8']" data-autofocus />
    </div>
    <AdminSegmented v-if="photo" v-model="vertical" label="Formato" :options="[{ value: false, label: 'Todas' }, { value: true, label: 'Verticales' }]" />
    </div>
    <AdminStateBlock v-if="failed" kind="error" title="No se han podido cargar las imágenes" @retry="reload" />
    <p v-else-if="pending && !shown.length" class="py-8 text-center text-sm text-adm-meta" role="status">Cargando imágenes…</p>
    <AdminStateBlock v-else-if="!shown.length" kind="empty" :title="query ? 'Sin resultados' : 'Todavía no hay imágenes'" description="Súbelas desde Medios." />
    <ul v-else aria-label="Fotos de Medios" :class="['grid gap-3', photo ? 'grid-cols-3 md:grid-cols-5' : 'grid-cols-2 sm:grid-cols-3 md:grid-cols-4']" :aria-busy="pending">
      <li v-for="item in shown" :key="item.id">
        <button type="button" :aria-pressed="multiple || photo ? isChosen(item) : undefined" :aria-disabled="missingAlt(item) ? true : undefined" :aria-describedby="missingAlt(item) ? 'picker-alt-why' : undefined" :class="['group relative block w-full rounded-lg border p-1.5 text-left hover:border-adm-control focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-adm-acc', isChosen(item) ? 'border-adm-acc bg-adm-acc-soft ring-2 ring-adm-acc' : 'border-adm-line', missingAlt(item) && 'opacity-55']" @click="pick(item)">
           <NuxtImg :src="mediaUrl(item.storage_path)" :alt="item.alt_es ?? ''" width="240" height="160" loading="lazy" :class="['w-full rounded object-cover', photo ? 'aspect-[4/5]' : 'aspect-[3/2]']" :style="{ backgroundColor: item.dominant_color ?? undefined }" />
          <span v-if="isChosen(item)" class="absolute top-3 right-3 grid size-5 place-items-center rounded-full bg-adm-acc text-adm-on-primary"><Check class="size-3.5" aria-hidden="true" /></span>
          <span class="mt-1.5 block truncate font-mono text-[11px] text-adm-meta">{{ item.original_filename }}</span>
          <span v-if="missingAlt(item)" class="mt-0.5 inline-flex items-center gap-1 rounded bg-adm-warn-soft px-1 text-[11px] font-medium text-adm-warn"><TriangleAlert class="size-3" aria-hidden="true" />{{ missingAlt(item) }}</span>
          <span v-else-if="!item.alt_es" class="block text-xs text-adm-warn">Sin texto alternativo</span>
          <span v-else class="sr-only">Texto alternativo: {{ item.alt_es }}</span>
        </button>
      </li>
    </ul>
    <p v-if="photo" id="picker-alt-why" class="mt-3 text-xs text-adm-meta">
      Las fotos atenuadas no tienen texto alternativo en español e inglés, y una foto pública lo necesita. <a :href="adminPath('medios')" target="_blank" rel="noopener" class="underline underline-offset-2">Complétalo en Medios<span class="sr-only"> (se abre en otra pestaña)</span></a>.
    </p>
    <template #footer>
      <a v-if="photo" :href="adminPath('medios')" target="_blank" rel="noopener" :class="[admBtnQuiet, 'sm:mr-auto']">Subir en Medios<span class="sr-only"> (se abre en otra pestaña)</span></a>
      <button type="button" :class="admBtnGhost" @click="open = false">Cancelar</button>
      <button v-if="photo" type="button" :class="admBtnPrimary" :disabled="!chosen.length" @click="confirm">Usar esta foto</button>
      <button v-if="multiple" type="button" :class="admBtnPrimary" :disabled="!chosen.length" @click="confirm">{{ chosen.length ? `Añadir ${chosen.length} ${chosen.length === 1 ? 'foto' : 'fotos'}` : 'Añadir fotos' }}</button>
    </template>
  </AdminModal>
</template>
