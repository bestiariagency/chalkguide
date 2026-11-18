<script setup lang="ts">
import { BadgeCheck } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'
import type { ItemForm } from '~/utils/item-fields'
import type { ItemErrors } from '~/utils/item-patch'
import type { ItemInfo } from '~/utils/item-spec'

/** General: name, URL, summary, cover, featured, source and verification date. */
const props = defineProps<{
  info: ItemInfo
  errors: ItemErrors
  changed: string[]
  live: boolean
  publishedSlug: string
  slugTaken: boolean
  slugSuggestion: string
  cover: AdminMedia | null
  busy?: boolean
}>()
defineEmits<{ cover: []; 'remove-cover': []; verify: [date: string] }>()
const form = defineModel<ItemForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const verifyHelp = `${useId()}-verify-help`
const today = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Madrid' })
</script>

<template>
  <div>
    <AdminItemsSection>
      <div class="grid gap-4 sm:grid-cols-2">
        <div :class="bar('name')"><AdminTextField v-model="form.name" label="Nombre" required :error="errors.name" :max="120" autocomplete="off" /></div>
        <div :class="bar('slug')">
          <AdminSlugField
            v-model="form.slug"
            :prefix="`${info.publicPath}/`"
            source-noun="nombre"
            :source="form.name"
            :taken="slugTaken"
            :suggestion="slugTaken ? slugSuggestion : undefined"
            :available="!!form.slug && !slugTaken && !errors.slug"
            :error="errors.slug"
            :published="live"
            :original="publishedSlug || undefined"
          />
        </div>
      </div>
      <div class="grid gap-4 lg:grid-cols-2">
        <div :class="bar('summary_es')"><AdminTextArea v-model="form.summary_es" label="Resumen" lang="ES" :rows="3" :max="400" :error="errors.summary_es" /></div>
        <div :class="bar('summary_en')"><AdminTextArea v-model="form.summary_en" label="Resumen" lang="EN" :rows="3" :max="400" :error="errors.summary_en" help="Si lo dejas vacío, la ficha no sale en inglés." /></div>
      </div>
      <AdminItemsMediaField label="Portada" required :media="cover" :changed="changed.includes('cover_media_id')" @change="$emit('cover')" @remove="$emit('remove-cover')" />
      <div :class="bar('is_featured')"><AdminSwitch v-model="form.is_featured" label="Destacada" :help="info.featuredHelp" /></div>
    </AdminItemsSection>

    <AdminItemsSection title="Fuente y verificación" description="Se muestra en la ficha como «verificado el …». Pasados 6 meses sale el aviso «puede haber cambiado».">
      <div class="grid gap-4 sm:grid-cols-2">
        <div :class="bar('source')"><AdminTextField v-model="form.source" label="Fuente" :max="200" placeholder="Visita y web oficial" /></div>
        <div :class="bar('source_url')"><AdminTextField v-model="form.source_url" label="URL de la fuente" type="url" inputmode="url" :error="errors.source_url" placeholder="https://…" /></div>
      </div>
      <div class="flex flex-wrap items-end gap-3">
        <div :class="['w-44', bar('verified_at')]"><AdminTextField v-model="form.verified_at" label="Datos verificados el" type="date" /></div>
        <button type="button" :class="admBtnGhost" :disabled="busy" :aria-describedby="live ? verifyHelp : undefined" @click="$emit('verify', today())"><BadgeCheck aria-hidden="true" />Verificar hoy</button>
      </div>
      <p v-if="live" :id="verifyHelp" class="-mt-1 text-xs text-adm-meta">En fichas publicadas se guarda al momento, sin pasar por el borrador.</p>
    </AdminItemsSection>
  </div>
</template>
