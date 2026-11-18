<script setup lang="ts">
import { changedBar } from '~/utils/editor-classes'
import { SOCIAL_NETWORKS, socialId, type SettingsForm } from '~/utils/admin-settings'

/** Ajustes › Redes y contacto: one URL per network (empty removes it) and the public contact email. */
const props = defineProps<{ errors: Record<string, string>; changed: string[] }>()
const form = defineModel<SettingsForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
</script>

<template>
  <section id="redes" class="scroll-mt-6 border-t border-adm-line pt-8" aria-labelledby="h-redes">
    <h2 id="h-redes" class="text-base font-semibold">Redes y contacto</h2>
    <p class="mt-1 text-sm text-adm-meta">Deja una red vacía para quitarla del sitio.</p>
    <div class="mt-4 grid gap-4 sm:grid-cols-2">
      <div v-for="n in SOCIAL_NETWORKS" :key="n.key" :class="bar(socialId(n.key))">
        <AdminTextField v-model="form.social[n.key]" :name="socialId(n.key)" :changed="changed.includes(socialId(n.key))" :label="n.label" type="url" inputmode="url" autocomplete="off" :placeholder="n.placeholder" :error="errors[socialId(n.key)]" />
      </div>
      <div :class="bar('contact_email')">
        <AdminTextField v-model="form.contact_email" name="contact_email" :changed="changed.includes('contact_email')" label="Email de contacto público" type="email" inputmode="email" autocomplete="off" placeholder="hola@…" help="Sale en el pie y en «Sobre mí»." :error="errors.contact_email" />
      </div>
    </div>
  </section>
</template>
