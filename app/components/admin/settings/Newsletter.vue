<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import { changedBar } from '~/utils/editor-classes'
import type { SettingsForm } from '~/utils/admin-settings'

/**
 * Ajustes › Newsletter: capture-block texts and the legal text of the checkbox. Editing the consent
 * creates the next version (the database raises it on save; here only the notice).
 */
const props = defineProps<{ errors: Record<string, string>; changed: string[]; version: number; since: string | null; consentChanged: boolean }>()
const form = defineModel<SettingsForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
</script>

<template>
  <section id="newsletter" class="scroll-mt-6 border-t border-adm-line pt-8" aria-labelledby="h-newsletter">
    <h2 id="h-newsletter" class="text-base font-semibold">Newsletter</h2>
    <p class="mt-1 text-sm text-adm-meta">Textos del bloque de captación. El envío se hace en Brevo.</p>
    <div class="mt-4 space-y-4">
      <AdminLangPair legend="Título">
        <template #es><div :class="bar('newsletter_title_es')"><AdminTextField v-model="form.newsletter_title_es" name="newsletter_title_es" :changed="changed.includes('newsletter_title_es')" label="Título" lang="ES" :max="120" :error="errors.newsletter_title_es" /></div></template>
        <template #en><div :class="bar('newsletter_title_en')"><AdminTextField v-model="form.newsletter_title_en" name="newsletter_title_en" :changed="changed.includes('newsletter_title_en')" label="Título" lang="EN" :max="120" :error="errors.newsletter_title_en" /></div></template>
      </AdminLangPair>
      <AdminLangPair legend="Texto">
        <template #es><div :class="bar('newsletter_body_es')"><AdminTextArea v-model="form.newsletter_body_es" name="newsletter_body_es" :changed="changed.includes('newsletter_body_es')" label="Texto" lang="ES" :rows="2" :max="400" :error="errors.newsletter_body_es" /></div></template>
        <template #en><div :class="bar('newsletter_body_en')"><AdminTextArea v-model="form.newsletter_body_en" name="newsletter_body_en" :changed="changed.includes('newsletter_body_en')" label="Texto" lang="EN" :rows="2" :max="400" :error="errors.newsletter_body_en" /></div></template>
      </AdminLangPair>
      <div class="space-y-4 rounded-lg border border-adm-line p-4">
        <div class="flex flex-wrap items-center gap-2">
          <p class="text-sm font-medium">Texto legal de la casilla</p>
          <span :class="[admChip, 'bg-adm-subtle text-adm-meta']">Versión {{ version }}<template v-if="since"> · desde {{ adminDate(since) }}</template></span>
        </div>
        <AdminLangPair legend="Consentimiento">
          <template #es><div :class="bar('newsletter_consent_text_es')"><AdminTextArea v-model="form.newsletter_consent_text_es" name="newsletter_consent_text_es" :changed="changed.includes('newsletter_consent_text_es')" label="Consentimiento" lang="ES" required :rows="3" :max="2000" :error="errors.newsletter_consent_text_es" /></div></template>
          <template #en><div :class="bar('newsletter_consent_text_en')"><AdminTextArea v-model="form.newsletter_consent_text_en" name="newsletter_consent_text_en" :changed="changed.includes('newsletter_consent_text_en')" label="Consentimiento" lang="EN" :rows="3" :max="2000" placeholder="Si está vacío, /en muestra el texto en español" :error="errors.newsletter_consent_text_en" /></div></template>
        </AdminLangPair>
        <div v-if="consentChanged" class="flex items-start gap-2 rounded-md bg-adm-warn-soft px-3 py-2.5 text-sm text-adm-warn" role="status">
          <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
          <span>Si guardas este cambio se crea la <b>versión {{ version + 1 }}</b>. Las altas nuevas guardarán la v{{ version + 1 }}; las anteriores conservan la versión que aceptaron.</span>
        </div>
      </div>
    </div>
  </section>
</template>
