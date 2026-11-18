<script setup lang="ts">
import { ImagePlus } from 'lucide-vue-next'
import type { Database } from '~/types/database.types'
import { fetchMediaById } from '~/services/admin/media'
import type { AdminMedia } from '~/utils/admin-media'
import { IMAGE_LICENSES } from '~/utils/admin-news'
import type { NewsErrors, NewsForm } from '~/utils/admin-news-form'

/**
 * «Imagen»: none (default) or one from Medios with its licence and credit. Without licence and credit it cannot be published
 * with an image, and Medios must have the Spanish alt (D27). The image of the source is never linked or copied.
 */
defineProps<{ errors: NewsErrors }>()
const form = defineModel<NewsForm>('form', { required: true })
const picking = ref(false)
const client = useSupabaseClient<Database>()
const mediaUrl = useMediaUrl()
const preview = ref('')
const modeId = `news-img-${useId()}`
const options = [
  { value: false, label: 'Sin imagen', sub: 'Lo normal. La ficha se sostiene con el texto y la fuente.' },
  { value: true, label: 'De Medios, con licencia', sub: 'Foto propia, cedida con permiso o con licencia abierta. Nunca la de la fuente.' },
]
// An item that already has an image shows it: the form only keeps the id.
onMounted(async () => {
  if (!form.value.mediaId || preview.value) return
  try {
    const media = await fetchMediaById(client, form.value.mediaId)
    if (media) chosen(media)
  } catch {
    // The preview is a courtesy: without it the id stays and the name is shown generic.
  }
})
const licenses = IMAGE_LICENSES.map((l) => ({ value: l.value as string, label: l.label }))

function chosen(media: AdminMedia) {
  form.value.mediaId = media.id
  form.value.mediaName = media.original_filename
  preview.value = mediaUrl(media.storage_path)
}
function select(withImage: boolean) {
  form.value.withImage = withImage
  if (withImage && !form.value.mediaId) picking.value = true
}
</script>

<template>
  <section class="space-y-3" :aria-labelledby="modeId">
    <h3 :id="modeId" class="text-sm font-semibold">Imagen</h3>
    <div role="radiogroup" :aria-labelledby="modeId" class="grid gap-2">
      <label v-for="o in options" :key="String(o.value)" :class="['flex cursor-pointer items-start gap-2.5 rounded-lg border px-3 py-2.5 has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-adm-acc', form.withImage === o.value ? 'border-adm-acc bg-adm-acc-soft' : 'border-adm-line-strong']">
        <input type="radio" class="mt-1 accent-[var(--adm-acc)]" :name="modeId" :checked="form.withImage === o.value" @change="select(o.value)" />
        <span><span class="block text-sm font-medium">{{ o.label }}</span><span class="block text-xs text-adm-meta">{{ o.sub }}</span></span>
      </label>
    </div>
    <div v-if="form.withImage" class="space-y-3 rounded-lg border border-dashed border-adm-line-strong p-3" data-field="image">
      <div class="flex items-center gap-3">
        <img v-if="preview" :src="preview" alt="" width="64" height="48" class="h-12 w-16 flex-none rounded object-cover" />
        <span v-else class="grid h-12 w-16 flex-none place-items-center rounded bg-adm-subtle text-adm-muted" aria-hidden="true"><ImagePlus class="size-5" /></span>
        <p class="min-w-0 flex-1 truncate text-sm">{{ form.mediaName || (form.mediaId ? 'Imagen de Medios' : 'Ninguna elegida') }}</p>
        <button type="button" :class="admBtnGhost" @click="picking = true">{{ form.mediaId ? 'Cambiar' : 'Elegir de Medios' }}</button>
      </div>
      <p v-if="errors.image" class="text-xs text-adm-danger" role="alert">{{ errors.image }}</p>
      <div class="grid gap-3 sm:grid-cols-2">
        <AdminSelect v-model="form.imageLicense" label="Licencia" required :options="licenses" placeholder="Elige…" :error="errors.imageLicense" />
        <AdminTextField v-model="form.imageCredit" label="Crédito" name="imageCredit" required :max="200" placeholder="Foto: Nombre / Medio" :error="errors.imageCredit" />
      </div>
      <p class="text-xs text-adm-meta">Sin licencia y crédito no se puede publicar con imagen. El alt en español es obligatorio en Medios (D27).</p>
    </div>
    <AdminMediaPicker v-model:open="picking" title="Imagen de la noticia" @select="chosen" />
  </section>
</template>
