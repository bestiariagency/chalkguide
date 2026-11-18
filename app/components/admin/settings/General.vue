<script setup lang="ts">
import { changedBar } from '~/utils/editor-classes'
import type { SettingsForm } from '~/utils/admin-settings'

/** Ajustes › General: site name, tagline and footer text (ES / EN). */
const props = defineProps<{ errors: Record<string, string>; changed: string[] }>()
const form = defineModel<SettingsForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
</script>

<template>
  <section id="general" class="scroll-mt-6" aria-labelledby="h-general">
    <h2 id="h-general" class="text-base font-semibold">General</h2>
    <div class="mt-4 space-y-4">
      <div :class="['sm:w-1/2', bar('site_name')]">
        <AdminTextField v-model="form.site_name" name="site_name" :changed="changed.includes('site_name')" label="Nombre del sitio" required :max="80" :error="errors.site_name" />
      </div>
      <AdminLangPair legend="Lema">
        <template #es><div :class="bar('tagline_es')"><AdminTextField v-model="form.tagline_es" name="tagline_es" :changed="changed.includes('tagline_es')" label="Lema" lang="ES" :max="200" :error="errors.tagline_es" /></div></template>
        <template #en><div :class="bar('tagline_en')"><AdminTextField v-model="form.tagline_en" name="tagline_en" :changed="changed.includes('tagline_en')" label="Lema" lang="EN" :max="200" :error="errors.tagline_en" /></div></template>
      </AdminLangPair>
      <AdminLangPair legend="Texto del pie">
        <template #es><div :class="bar('footer_text_es')"><AdminTextArea v-model="form.footer_text_es" name="footer_text_es" :changed="changed.includes('footer_text_es')" label="Texto del pie" lang="ES" :rows="2" :max="300" :error="errors.footer_text_es" /></div></template>
        <template #en><div :class="bar('footer_text_en')"><AdminTextArea v-model="form.footer_text_en" name="footer_text_en" :changed="changed.includes('footer_text_en')" label="Texto del pie" lang="EN" :rows="2" :max="300" :error="errors.footer_text_en" /></div></template>
      </AdminLangPair>
    </div>
  </section>
</template>
