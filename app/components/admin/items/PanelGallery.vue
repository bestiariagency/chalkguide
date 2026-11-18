<script setup lang="ts">
import { Plus, TriangleAlert, X } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'
import type { ItemForm } from '~/utils/item-fields'

/** Galería: drag (or arrows / menu) to order; the first photo opens the carousel on the public page. */
const props = defineProps<{ changed: boolean; mediaOf: (id: string | null) => AdminMedia | null }>()
defineEmits<{ add: [] }>()
const form = defineModel<ItemForm>('form', { required: true })
const mediaUrl = useMediaUrl()
const gallery = computed({ get: () => form.value.gallery, set: (value: string[]) => (form.value.gallery = value) })
const nameOf = (id: string) => {
  const media = props.mediaOf(id)
  return media?.alt_es?.trim() || media?.original_filename || 'Foto'
}
const remove = (id: string) => (form.value.gallery = form.value.gallery.filter((g) => g !== id))
</script>

<template>
  <div :class="changedBar(changed)">
    <div class="flex items-end gap-3">
      <div>
        <h3 class="text-sm font-semibold">Galería</h3>
        <p class="mt-0.5 text-xs text-adm-meta">{{ gallery.length > 1 ? 'Arrastra para ordenar. ' : '' }}La primera es la que abre el carrusel de la ficha.</p>
      </div>
      <button type="button" :class="[admBtnGhost, 'ml-auto']" @click="$emit('add')"><Plus aria-hidden="true" />Añadir fotos</button>
    </div>
    <p v-if="!gallery.length" class="mt-3 rounded-lg border border-dashed border-adm-line-strong p-6 text-center text-sm text-adm-meta">Todavía no hay fotos en la galería.</p>
    <AdminSortableList v-else v-model:items="gallery" class="mt-3" :item-key="(id: string) => id" :item-label="nameOf" label="Fotos de la galería, ordenables">
      <template #item="{ item }">
        <div class="flex items-center gap-3">
          <NuxtImg v-if="mediaOf(item)" :src="mediaUrl(mediaOf(item)!.storage_path)" alt="" width="64" height="44" loading="lazy" class="h-11 w-16 flex-none rounded object-cover" :style="{ backgroundColor: mediaOf(item)?.dominant_color ?? undefined }" />
          <span v-else class="h-11 w-16 flex-none rounded bg-adm-subtle" aria-hidden="true" />
          <span class="min-w-0 flex-1 truncate text-sm">{{ nameOf(item) }}</span>
          <span v-if="item === form.cover_media_id" :class="[admChip, 'bg-adm-subtle text-adm-meta']">También es la portada</span>
          <span v-if="mediaOf(item) && !mediaOf(item)?.alt_es?.trim()" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><TriangleAlert aria-hidden="true" />Sin texto alternativo</span>
          <button type="button" :class="admIconBtn" :aria-label="`Quitar ${nameOf(item)} de la galería`" @click="remove(item)"><X aria-hidden="true" /></button>
        </div>
      </template>
    </AdminSortableList>
  </div>
</template>
