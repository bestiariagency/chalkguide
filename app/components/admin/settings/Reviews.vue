<script setup lang="ts">
import { changedBar } from '~/utils/editor-classes'
import { SETTING_MIN_REVIEWS, SETTING_PREMOD, type SettingsForm } from '~/utils/admin-settings'

/** Ajustes › Opiniones: pre-moderation switch and the minimum reviews before the average shows. */
const props = defineProps<{ errors: Record<string, string>; changed: string[] }>()
const form = defineModel<SettingsForm>('form', { required: true })
const bar = (id: string) => changedBar(props.changed.includes(id))
</script>

<template>
  <section id="opiniones" class="scroll-mt-6 border-t border-adm-line pt-8" aria-labelledby="h-opiniones">
    <h2 id="h-opiniones" class="text-base font-semibold">Opiniones</h2>
    <div class="mt-4 space-y-4">
      <div :class="bar(SETTING_PREMOD)">
        <AdminSwitch
          v-model="form.user_reviews_premoderation"
          :name="SETTING_PREMOD"
          :changed="changed.includes(SETTING_PREMOD)"
          label="Revisar antes de publicar"
          help="Apagado: se publican al momento y tú ocultas las que haga falta. Encendido: esperan en «Pendientes» hasta que las apruebes."
        />
      </div>
      <div :class="['tabular-nums sm:w-64', bar(SETTING_MIN_REVIEWS)]">
        <AdminTextField
          v-model="form.min_user_reviews_for_average"
          :name="SETTING_MIN_REVIEWS"
          :changed="changed.includes(SETTING_MIN_REVIEWS)"
          label="Opiniones mínimas para mostrar la media"
          inputmode="numeric"
          :error="errors[SETTING_MIN_REVIEWS]"
          help="Con menos, la ficha muestra «Aún no hay suficientes opiniones (mínimo N)»."
        />
      </div>
    </div>
  </section>
</template>
