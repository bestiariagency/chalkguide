<script setup lang="ts">
import { Info } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'
import type { ItemForm } from '~/utils/item-fields'
import type { ItemErrors } from '~/utils/item-patch'
import type { ItemInfo } from '~/utils/item-spec'

/** SEO: titles and descriptions (empty = generated from name and summary), share image, noindex. */
const props = defineProps<{ info: ItemInfo; errors: ItemErrors; changed: string[]; og: AdminMedia | null }>()
defineEmits<{ og: []; 'remove-og': [] }>()
const form = defineModel<ItemForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
</script>

<template>
  <div class="space-y-4">
    <p class="flex gap-2 rounded-lg bg-adm-subtle px-3 py-2 text-[13px]" role="note">
      <Info class="mt-0.5 size-4 flex-none text-adm-info" aria-hidden="true" />
      <span>Si lo dejas vacío se genera del nombre y el resumen: «{{ info.seoTitleEs(form.name || 'Nombre') }} | ChalkGuide».</span>
    </p>
    <div class="grid gap-4 lg:grid-cols-2">
      <div :class="bar('seo_title_es')"><AdminTextField v-model="form.seo_title_es" label="Título SEO" lang="ES" seo="title" :placeholder="info.seoTitleEs(form.name || 'Nombre')" :error="errors.seo_title_es" /></div>
      <div :class="bar('seo_title_en')"><AdminTextField v-model="form.seo_title_en" label="Título SEO" lang="EN" seo="title" :placeholder="info.seoTitleEn(form.name || 'Name')" :error="errors.seo_title_en" /></div>
      <div :class="bar('seo_description_es')"><AdminTextArea v-model="form.seo_description_es" label="Descripción" lang="ES" seo="description" :rows="2" placeholder="Se usa el resumen" :error="errors.seo_description_es" /></div>
      <div :class="bar('seo_description_en')"><AdminTextArea v-model="form.seo_description_en" label="Descripción" lang="EN" seo="description" :rows="2" placeholder="Se usa el resumen" :error="errors.seo_description_en" /></div>
    </div>
    <AdminItemsMediaField label="Imagen para compartir" :media="og" :changed="changed.includes('og_media_id')" help="Si no eliges ninguna se usa la portada." @change="$emit('og')" @remove="$emit('remove-og')" />
    <div :class="bar('noindex')"><AdminSwitch v-model="form.noindex" label="No indexar" help="Los buscadores no la listarán." /></div>
  </div>
</template>
