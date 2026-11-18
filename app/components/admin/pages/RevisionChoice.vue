<script setup lang="ts">
import type { PageRevision } from '~/services/admin/page-drafts'

/**
 * "Última actualización" choice when publishing a legal page: today's date (recommended) or keep the
 * previous one (only for typos, and only if there is one). The date is never typed by hand.
 */
defineProps<{ today: string; previous: string | null; hint?: string }>()
const model = defineModel<PageRevision>({ default: 'today' })
const name = `revision-${useId()}`
const choice = 'flex min-h-8 cursor-pointer items-start gap-2 has-[:disabled]:cursor-not-allowed has-[:disabled]:opacity-60 max-md:min-h-11'
</script>

<template>
  <fieldset class="rounded-lg border border-adm-line p-3 text-sm">
    <legend class="px-1 text-xs font-medium">Última actualización</legend>
    <label :class="choice">
      <input v-model="model" type="radio" value="today" :name="name" class="mt-1 accent-adm-acc" />
      <span>Hoy, {{ today }}<span class="block text-xs text-adm-meta">{{ hint ?? 'Recomendado: el texto ha cambiado.' }}</span></span>
    </label>
    <label :class="[choice, 'mt-2']">
      <input v-model="model" type="radio" value="keep" :name="name" class="mt-1 accent-adm-acc" :disabled="!previous" />
      <span>Mantener la fecha anterior<span class="block text-xs text-adm-meta">{{ previous ? `Sigue siendo ${previous}. Solo para erratas.` : 'Solo para erratas. Ahora no hay fecha anterior que mantener.' }}</span></span>
    </label>
  </fieldset>
</template>
