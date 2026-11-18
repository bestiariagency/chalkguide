<script setup lang="ts">
import { ImageIcon } from 'lucide-vue-next'
import { changedBar } from '~/utils/editor-classes'
import { SETTING_OG, type SettingsForm } from '~/utils/admin-settings'
import type { AdminMedia } from '~/utils/admin-media'

/** Ajustes › SEO por defecto: title/description (ES / EN) and the default OG image (picked from Medios). */
const props = defineProps<{ errors: Record<string, string>; changed: string[]; og: AdminMedia | null }>()
const emit = defineEmits<{ pick: [media: AdminMedia | null] }>()
const form = defineModel<SettingsForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const mediaUrl = useMediaUrl()
const picking = ref(false)
</script>

<template>
  <section id="seo" class="scroll-mt-6 border-t border-adm-line pt-8" aria-labelledby="h-seo">
    <h2 id="h-seo" class="text-base font-semibold">SEO por defecto</h2>
    <p class="mt-1 text-sm text-adm-meta">Se usan cuando una página no tiene los suyos.</p>
    <div class="mt-4 space-y-4">
      <AdminLangPair legend="Título">
        <template #es><div :class="bar('default_seo_title_es')"><AdminTextField v-model="form.default_seo_title_es" name="default_seo_title_es" :changed="changed.includes('default_seo_title_es')" label="Título" lang="ES" seo="title" :error="errors.default_seo_title_es" /></div></template>
        <template #en><div :class="bar('default_seo_title_en')"><AdminTextField v-model="form.default_seo_title_en" name="default_seo_title_en" :changed="changed.includes('default_seo_title_en')" label="Título" lang="EN" seo="title" :error="errors.default_seo_title_en" /></div></template>
      </AdminLangPair>
      <AdminLangPair legend="Descripción">
        <template #es><div :class="bar('default_seo_description_es')"><AdminTextArea v-model="form.default_seo_description_es" name="default_seo_description_es" :changed="changed.includes('default_seo_description_es')" label="Descripción" lang="ES" seo="description" :error="errors.default_seo_description_es" /></div></template>
        <template #en><div :class="bar('default_seo_description_en')"><AdminTextArea v-model="form.default_seo_description_en" name="default_seo_description_en" :changed="changed.includes('default_seo_description_en')" label="Descripción" lang="EN" seo="description" placeholder="Opcional" :error="errors.default_seo_description_en" /></div></template>
      </AdminLangPair>
      <div :class="bar(SETTING_OG)">
        <p id="og-label" class="mb-1.5 flex items-center gap-1.5 text-xs font-medium text-adm-fg">Imagen para redes (OG)<span v-if="changed.includes(SETTING_OG)" class="text-[11px] font-medium text-adm-st-rev">Sin guardar</span></p>
        <div class="flex items-center gap-3">
          <NuxtImg
            v-if="og"
            :src="mediaUrl(og.storage_path)"
            :alt="og.alt_es ?? ''"
            width="128"
            height="67"
            loading="lazy"
            class="h-[67px] w-32 flex-none rounded-md border border-adm-line object-cover"
            :style="{ backgroundColor: og.dominant_color ?? undefined }"
          />
          <span v-else class="grid h-[67px] w-32 flex-none place-items-center rounded-md border border-dashed border-adm-line-strong bg-adm-subtle text-adm-muted"><ImageIcon class="size-5" aria-hidden="true" /></span>
          <div class="min-w-0 text-xs text-adm-meta">
            <p v-if="og" class="truncate font-mono text-adm-fg">{{ og.original_filename }}</p>
            <p v-if="og?.width && og?.height">{{ og.width }} × {{ og.height }} px</p>
            <p v-else-if="!og">Sin imagen: las páginas sin foto propia se comparten sin imagen.</p>
            <p>Recomendado: 1200 × 630 px</p>
            <div class="mt-2 flex flex-wrap gap-2">
              <button type="button" :name="SETTING_OG" aria-describedby="og-label" :class="admBtnGhost" @click="picking = true">{{ og ? 'Cambiar' : 'Elegir imagen' }}</button>
              <button v-if="og" type="button" :class="admBtnQuiet" @click="emit('pick', null)">Quitar<span class="sr-only"> imagen para redes</span></button>
            </div>
          </div>
        </div>
        <p v-if="errors[SETTING_OG]" class="mt-1.5 text-xs leading-4 text-adm-danger" role="alert">{{ errors[SETTING_OG] }}</p>
      </div>
    </div>
    <AdminMediaPicker v-model:open="picking" title="Imagen para redes" @select="emit('pick', $event)" />
  </section>
</template>
