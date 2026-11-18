<script setup lang="ts">
import { aboutBoxes } from '~/utils/admin-author-stats'
import type { AdminMedia } from '~/utils/admin-media'
import type { SettingsForm } from '~/utils/admin-settings'

/** «Así se ve» (README §17.2): approximate preview of the signature and of «Sobre mí», ES / EN. */
const props = defineProps<{ form: SettingsForm; photo: AdminMedia | null; calc: { gyms: number; shoes: number } | null }>()
const view = ref<'firma' | 'sobre'>('firma')
const lang = ref<'es' | 'en'>('es')
const mediaUrl = useMediaUrl()
const text = (es: string, en: string) => (lang.value === 'en' ? en : es).trim()
const role = computed(() => text(props.form.author_role_es, props.form.author_role_en))
const bio = computed(() => text(props.form.author_bio_es, props.form.author_bio_en))
const lede = computed(() => text(props.form.author_lede_es, props.form.author_lede_en))
const name = computed(() => props.form.author_name.trim())
const boxes = computed(() => aboutBoxes(props.form.author_stats, lang.value, props.calc))
</script>

<template>
  <section :class="[admCard, 'p-4']" aria-labelledby="h-prev">
    <div class="flex flex-wrap items-center gap-2">
      <h3 id="h-prev" class="text-sm font-semibold">Así se ve</h3>
      <AdminSegmented v-model="view" class="ml-auto" label="Vista previa" :options="[{ value: 'firma', label: 'Firma' }, { value: 'sobre', label: 'Sobre mí' }]" />
      <AdminSegmented v-model="lang" label="Idioma de la vista previa" :options="[{ value: 'es', label: 'ES' }, { value: 'en', label: 'EN' }]" />
    </div>
    <div v-if="view === 'firma'" class="mt-4 flex items-start gap-4">
      <AdminAuthorsAvatar v-if="photo" :media="photo" :name="name" size="lg" />
      <div class="min-w-0">
        <p class="font-semibold">{{ name || 'Tu nombre' }}</p>
        <p v-if="role" class="text-sm text-adm-meta">{{ role }}</p>
        <p v-if="bio" class="mt-2 max-w-[56ch] text-sm break-words">{{ bio }}</p>
        <p class="mt-2 flex gap-4 text-sm"><span class="underline underline-offset-2">Sobre mí</span><span class="underline underline-offset-2">Cómo trabajo</span></p>
      </div>
    </div>
    <div v-else class="mt-4 rounded-md bg-zinc-900 p-5 text-white">
      <div class="flex items-start gap-5">
        <p class="max-w-[20ch] flex-1 text-2xl leading-8 font-semibold break-words">{{ lede || 'Tu frase de «Sobre mí»' }}</p>
        <NuxtImg v-if="photo" :src="mediaUrl(photo.storage_path)" alt="" width="80" height="96" loading="lazy" class="h-24 w-20 flex-none rounded object-cover" />
      </div>
      <ul v-if="boxes.length" class="mt-5 grid grid-cols-2 gap-2 sm:grid-cols-4">
        <li v-for="box in boxes" :key="box.label" class="rounded border border-white/25 px-3 py-2"><span class="font-mono text-lg tabular-nums">{{ box.value }}</span><span class="block text-xs opacity-80">{{ box.label }}</span></li>
      </ul>
    </div>
    <p class="mt-3 text-xs text-adm-meta">Vista aproximada: la real usa la tipografía y los colores del sitio.</p>
  </section>
</template>
