<script setup lang="ts">
import { ImageIcon } from 'lucide-vue-next'
import type { HeroSlot } from '~/services/admin/hero-photos'
import type { AdminMedia } from '~/utils/admin-media'

/** «Portada» block of the pages screen: the two photo-only cards of the home hero (D41). */
const { list, photos, busy, save } = useAdminHeroPhotos()
const mediaUrl = useMediaUrl()
const slots: HeroSlot[] = [1, 2]
const pickButtons = ref<HTMLButtonElement[]>([])
const picking = ref<HeroSlot | null>(null)
const pickerOpen = computed({ get: () => picking.value !== null, set: (value) => !value && (picking.value = null) })
const otherId = (slot: HeroSlot) => photos.value[slot === 1 ? 1 : 0]?.id
const exclude = computed(() => [picking.value && otherId(picking.value)].filter((id): id is string => !!id))

function pick(slot: HeroSlot) {
  if (busy.value === null) picking.value = slot
}

async function remove(slot: HeroSlot) {
  if (busy.value !== null) return
  await save(slot, null)
  await nextTick()
  pickButtons.value[slot - 1]?.focus()
}

function chosen(media: AdminMedia) {
  if (picking.value) void save(picking.value, media)
}
</script>

<template>
  <section aria-labelledby="hero-title" class="border-b border-adm-line px-4 py-5 md:px-6">
    <h2 id="hero-title" class="text-sm font-medium">Portada</h2>
    <p class="mt-1 text-xs text-adm-meta">Salen en el carrusel de la portada, sin texto ni enlace. Si dejas una vacía, simplemente no se muestra.</p>

    <div v-if="list.status.value === 'pending' && !list.data.value" class="mt-4 grid gap-4 sm:grid-cols-2" aria-busy="true" role="status">
      <span class="sr-only">Cargando fotos de la portada…</span>
      <span v-for="slot in slots" :key="slot" class="h-24 rounded-lg bg-adm-subtle motion-safe:animate-pulse" aria-hidden="true" />
    </div>
    <AdminStateBlock v-else-if="list.error.value" kind="error" title="No se han podido cargar las fotos de la portada" @retry="list.refresh()" />
    <ul v-else class="mt-4 grid gap-4 sm:grid-cols-2">
      <li v-for="slot in slots" :key="slot" :class="[admCard, 'flex items-center gap-3 p-3']">
        <NuxtImg v-if="photos[slot - 1]" :src="mediaUrl(photos[slot - 1]!.storage_path)" :alt="photos[slot - 1]!.alt_es ?? ''" width="160" height="160" class="size-20 shrink-0 rounded-md object-cover" :style="{ backgroundColor: photos[slot - 1]!.dominant_color ?? undefined }" />
        <span v-else class="grid size-20 shrink-0 place-items-center rounded-md border border-dashed border-adm-line-strong text-adm-muted"><ImageIcon class="size-5" aria-hidden="true" /></span>
        <div class="min-w-0 flex-1">
          <p class="text-[13px] font-medium">Foto {{ slot }}</p>
          <p class="truncate font-mono text-[11px] text-adm-meta">{{ photos[slot - 1]?.original_filename ?? 'Sin foto' }}</p>
          <div class="mt-2 flex flex-wrap gap-2">
            <button :ref="(el) => (pickButtons[slot - 1] = el as HTMLButtonElement)" type="button" :class="admBtnGhost" :aria-disabled="busy !== null || undefined" :aria-label="`${photos[slot - 1] ? 'Cambiar' : 'Elegir foto'} (foto ${slot})`" @click="pick(slot)">{{ photos[slot - 1] ? 'Cambiar' : 'Elegir foto' }}</button>
            <button v-if="photos[slot - 1]" type="button" :class="admBtnQuiet" :aria-disabled="busy !== null || undefined" :aria-label="`Quitar foto ${slot}`" @click="remove(slot)">Quitar</button>
          </div>
        </div>
      </li>
    </ul>

    <AdminMediaPicker v-model:open="pickerOpen" :title="`Elegir foto ${picking ?? ''}`" :exclude="exclude" @select="chosen" />
  </section>
</template>
