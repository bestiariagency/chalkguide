<script setup lang="ts">
import { CircleCheck, ImageOff, ImagePlus, Loader2, TriangleAlert } from 'lucide-vue-next'
import type { CoverRow } from '~/composables/useAdminCovers'
import { COVER_LABEL } from '~/utils/admin-import-covers'
import type { AdminItemRow } from '~/utils/admin-items'
import type { AdminMedia } from '~/utils/admin-media'
import type { ItemInfo } from '~/utils/item-spec'

/**
 * "Asignar portadas" (README §13.6): items without cover, the ones with problems first. The photo is suggested by slug
 * (the server does not keep the name that came in the file). Published items get the cover in their draft of changes.
 */
const props = defineProps<{ info: ItemInfo; items: AdminItemRow[] }>()
const emit = defineEmits<{ done: [] }>()
const open = defineModel<boolean>('open', { required: true })
const covers = useAdminCovers(props.info, () => emit('done'))
const mediaUrl = useMediaUrl()
const showLoading = useDelayedFlag(() => covers.loading.value, 300)
const picking = ref<CoverRow>()
const pickerOpen = computed({ get: () => !!picking.value, set: (v) => { if (!v) picking.value = undefined } })
watch(open, (value) => value && void covers.load(props.items), { immediate: true })

const noAlt = (row: CoverRow) => !!row.choice && !row.choice.alt_es
const pickedMedia = (media: AdminMedia) => picking.value && void covers.pick(picking.value, media)
async function submit() {
  if (await covers.assign()) open.value = false
}
</script>

<template>
  <AdminModal v-model:open="open" title="Asignar portadas" size="lg" :busy="covers.busy.value" description="La foto se sugiere por la URL de la ficha. Revisa cada una antes de asignarla.">
    <div class="mb-3 flex flex-wrap gap-2">
      <a :href="adminPath('medios')" target="_blank" rel="noopener" :class="admBtnGhost">Subir en Medios<span class="sr-only"> (pestaña nueva)</span> ↗</a>
      <button type="button" :class="admBtnGhost" :disabled="covers.loading.value" @click="covers.load(items)">Buscar de nuevo</button>
    </div>
    <p v-if="covers.loading.value" class="flex min-h-24 items-center justify-center gap-2 py-8 text-sm text-adm-meta" role="status"><template v-if="showLoading"><Loader2 class="size-4 animate-adm-spin motion-reduce:animate-none" aria-hidden="true" />Buscando fotos en Medios…</template></p>
    <AdminStateBlock v-else-if="!covers.rows.value.length" kind="empty" title="No hay fichas sin portada" description="Todas las fichas tienen portada." />
    <ul v-else class="grid gap-2">
      <li v-for="row in covers.rows.value" :key="row.item.id" class="grid items-center gap-x-3 gap-y-2 rounded-lg border border-adm-line p-3 md:grid-cols-[auto_minmax(0,1fr)_minmax(0,1.3fr)]">
        <AdminCheckbox v-model="row.checked" :label="`Asignar portada a ${row.item.name}`" :disabled="!covers.ready(row)" />
        <div class="min-w-0">
          <p class="truncate text-[13px] font-medium">{{ row.item.name || 'Sin nombre' }}</p>
          <code class="font-mono text-xs break-all text-adm-meta">{{ row.item.slug }}</code>
        </div>
        <div class="grid gap-1.5 text-[13px] max-md:col-span-2">
          <div class="flex items-center gap-2.5">
            <NuxtImg v-if="row.choice" :src="mediaUrl(row.choice.storage_path)" :alt="row.choice.alt_es ?? ''" width="72" height="48" loading="lazy" class="h-12 w-[72px] flex-none rounded object-cover" :style="{ backgroundColor: row.choice.dominant_color ?? undefined }" />
            <span v-else class="grid h-12 w-[72px] flex-none place-items-center rounded border border-dashed border-adm-control text-adm-muted"><ImageOff class="size-4" aria-hidden="true" /></span>
            <div class="min-w-0">
              <p :class="['inline-flex items-center gap-1.5', row.state === 'match' && !noAlt(row) ? 'text-adm-ok' : 'text-adm-warn']">
                <CircleCheck v-if="row.state === 'match' && !noAlt(row)" class="size-3.5" aria-hidden="true" /><TriangleAlert v-else class="size-3.5" aria-hidden="true" />
                {{ noAlt(row) ? 'Sin texto alternativo' : COVER_LABEL[row.state] }}
              </p>
              <code v-if="row.choice" class="block font-mono text-xs break-all text-adm-meta">{{ row.choice.original_filename }}</code>
            </div>
            <button type="button" :class="[admBtnGhost, 'ml-auto']" @click="picking = row"><ImagePlus aria-hidden="true" />{{ row.choice ? 'Cambiar…' : 'Elegir de Medios…' }}</button>
          </div>
          <label v-if="row.state === 'several' && row.options.length" class="flex items-center gap-2"><span class="text-adm-meta">Hay {{ row.options.length }} con este nombre</span>
            <select :class="[admInput, 'w-auto!']" :value="row.choice?.id ?? ''" @change="covers.choose(row, row.options.find((m) => m.id === ($event.target as HTMLSelectElement).value)!)">
              <option value="" disabled>Elige una</option>
              <option v-for="media in row.options" :key="media.id" :value="media.id">{{ media.original_filename }} · {{ media.width }}×{{ media.height }}</option>
            </select>
          </label>
          <label v-if="noAlt(row)" class="grid gap-1"><span class="text-adm-meta">Texto alternativo (ES): se guarda en Medios y vale para todas las fichas que usen la foto</span>
            <input v-model="row.altEs" type="text" :class="admInput" maxlength="200" @input="row.checked = !!row.altEs.trim()" />
          </label>
        </div>
      </li>
    </ul>
    <template #footer>
      <button type="button" :class="admBtnGhost" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnPrimary" :disabled="!covers.selected.value.length || covers.busy.value" :aria-busy="covers.busy.value || undefined" @click="submit">
        {{ covers.busy.value ? 'Asignando…' : `Asignar ${covers.selected.value.length} ${covers.selected.value.length === 1 ? 'portada' : 'portadas'}` }}
      </button>
    </template>
    <AdminMediaPicker v-model:open="pickerOpen" title="Elegir portada" @select="pickedMedia" />
  </AdminModal>
</template>
