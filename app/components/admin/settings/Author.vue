<script setup lang="ts">
import { ArrowRight, Info } from 'lucide-vue-next'
import { STATS_FIELD } from '~/utils/admin-author-stats'
import type { AdminMedia } from '~/utils/admin-media'
import { SETTING_AUTHOR_PHOTO, type SettingsForm } from '~/utils/admin-settings'
import { changedBar } from '~/utils/editor-classes'

/**
 * Ajustes › Autor del sitio (D62, README §17.2): photo, name, role, «Sobre mí» phrase, short bio
 * (ES / EN) and «En números». Saved with the rest of Ajustes (`admin_update_settings`).
 */
const props = defineProps<{
  errors: Record<string, string>
  changed: string[]
  photo: AdminMedia | null
  calc: { gyms: number; shoes: number } | null
}>()
const emit = defineEmits<{ pick: [media: AdminMedia | null]; 'add-stat': []; 'remove-stat': [index: number] }>()
const form = defineModel<SettingsForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const empty = computed(() => !props.photo && !form.value.author_stats.length && Object.entries(form.value).every(([k, v]) => !k.startsWith('author_') || typeof v !== 'string' || !v.trim()))
</script>

<template>
  <section id="autor" class="scroll-mt-6 border-t border-adm-line pt-8" aria-labelledby="h-autor">
    <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
      <h2 id="h-autor" class="text-base font-semibold">Autor del sitio</h2>
      <NuxtLink :to="adminPath('autores')" class="ml-auto inline-flex items-center gap-1 text-sm text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11">Otros autores<ArrowRight class="size-3.5" aria-hidden="true" /></NuxtLink>
    </div>
    <p class="mt-1 text-sm text-adm-meta">Quien firma por defecto y sale en «Sobre mí». Los demás autores se gestionan en Autores.</p>
    <p v-if="empty" class="mt-4 flex gap-2 rounded-md bg-adm-subtle px-3 py-2.5 text-sm" role="note">
      <Info class="mt-0.5 size-4 flex-none text-adm-meta" aria-hidden="true" />Todo vacío hasta que cargues el contenido real. Mientras tanto, la firma sale sin foto y «En números» no se pinta. Nunca sale un «0».
    </p>
    <div class="mt-4 space-y-4">
      <div :class="bar(SETTING_AUTHOR_PHOTO)">
        <AdminAuthorsPhoto
          :media="photo"
          :name="form.author_name"
          shape="portrait"
          :field-name="SETTING_AUTHOR_PHOTO"
          :changed="changed.includes(SETTING_AUTHOR_PHOTO)"
          subtitle="Para tu firma y «Sobre mí». Mejor vertical (4:5): en la firma se recorta en círculo."
          help="Al guardar, la foto pasa a ser pública: sale en «Sobre mí» y en tu firma, aunque no esté en ningún artículo. Al quitarla, deja de salir en el sitio si no se usa en otra página; quien ya tenga el enlace al archivo aún puede abrirlo."
          empty-help="Sin foto: la firma sale sin círculo y «Sobre mí» con el titular a todo el ancho."
          :error="errors[SETTING_AUTHOR_PHOTO]"
          @pick="emit('pick', $event)"
        />
      </div>
      <div :class="['sm:w-1/2', bar('author_name')]">
        <AdminTextField v-model="form.author_name" name="author_name" :changed="changed.includes('author_name')" label="Nombre" :max="80" :error="errors.author_name" placeholder="Como firmas" help="Sale en la firma, en «Sobre mí» y como autor en los buscadores." />
      </div>
      <AdminLangPair legend="Rol">
        <template #es><div :class="bar('author_role_es')"><AdminTextField v-model="form.author_role_es" name="author_role_es" :changed="changed.includes('author_role_es')" label="Rol" lang="ES" :max="80" :error="errors.author_role_es" placeholder="Debajo del nombre" /></div></template>
        <template #en><div :class="bar('author_role_en')"><AdminTextField v-model="form.author_role_en" name="author_role_en" :changed="changed.includes('author_role_en')" label="Rol" lang="EN" :max="80" :error="errors.author_role_en" placeholder="Opcional" /></div></template>
      </AdminLangPair>
      <AdminLangPair legend="Frase de «Sobre mí»">
        <template #es><div :class="bar('author_lede_es')"><AdminTextArea v-model="form.author_lede_es" name="author_lede_es" :changed="changed.includes('author_lede_es')" label="Frase de «Sobre mí»" lang="ES" :rows="3" :max="120" :error="errors.author_lede_es" placeholder="En primera persona. Es el titular de la página." help="Es el titular grande de «Sobre mí»." /></div></template>
        <template #en><div :class="bar('author_lede_en')"><AdminTextArea v-model="form.author_lede_en" name="author_lede_en" :changed="changed.includes('author_lede_en')" label="Frase de «Sobre mí»" lang="EN" :rows="3" :max="120" :error="errors.author_lede_en" placeholder="Opcional" /></div></template>
      </AdminLangPair>
      <AdminLangPair legend="Bio corta">
        <template #es><div :class="bar('author_bio_es')"><AdminTextArea v-model="form.author_bio_es" name="author_bio_es" :changed="changed.includes('author_bio_es')" label="Bio corta" lang="ES" :rows="3" :max="160" :error="errors.author_bio_es" placeholder="Dos frases para el final de cada artículo" help="Va en la firma del final del artículo." /></div></template>
        <template #en><div :class="bar('author_bio_en')"><AdminTextArea v-model="form.author_bio_en" name="author_bio_en" :changed="changed.includes('author_bio_en')" label="Bio corta" lang="EN" :rows="3" :max="160" :error="errors.author_bio_en" placeholder="Opcional" help="Si está vacía, en /en la firma sale sin bio." /></div></template>
      </AdminLangPair>
      <AdminSettingsAuthorStats v-model:rows="form.author_stats" :errors="errors" :changed="changed.includes(STATS_FIELD)" :calc="calc" @add="emit('add-stat')" @remove="emit('remove-stat', $event)" />
      <AdminSettingsAuthorPreview :form="form" :photo="photo" :calc="calc" />
    </div>
  </section>
</template>
