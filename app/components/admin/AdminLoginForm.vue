<script setup lang="ts">
import { CircleAlert, Loader2, ShieldX } from 'lucide-vue-next'

defineEmits<{ forgot: [] }>()
const { email, password, loading, failure, message, emailError, passwordError, submit } = useAdminLogin()

const form = ref<HTMLFormElement | null>(null)
const banner = ref<HTMLElement | null>(null)
// Empty submit: focus goes to the first field with an error.
watch([emailError, passwordError], async ([mail, pass]) => {
  if (!mail && !pass) return
  await nextTick()
  form.value?.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus()
})
// Focus goes to the banner so the message is read and the keyboard keeps its place.
watch(failure, async (value) => {
  if (!value) return
  await nextTick()
  banner.value?.focus()
})
</script>

<template>
  <form ref="form" :class="[admCard, 'mt-6 space-y-4 p-5']" novalidate :aria-busy="loading" @submit.prevent="submit">
    <div
      v-if="failure"
      ref="banner"
      tabindex="-1"
      role="alert"
      :class="[
        'flex items-start gap-2.5 rounded-lg px-3 py-2.5 text-[13px] leading-5 text-adm-fg',
        failure === 'no-access' ? 'bg-adm-warn-soft' : 'bg-adm-danger-soft',
      ]"
    >
      <ShieldX v-if="failure === 'no-access'" class="mt-0.5 size-4 shrink-0 text-adm-warn-icon" aria-hidden="true" />
      <CircleAlert v-else class="mt-0.5 size-4 shrink-0 text-adm-danger" aria-hidden="true" />
      <span>{{ message }}</span>
    </div>

    <AdminTextField
      v-model="email"
      label="Email"
      type="email"
      name="email"
      autocomplete="username"
      inputmode="email"
      placeholder="nombre@dominio.com"
      :error="emailError"
      :readonly="loading"
    />
    <AdminPasswordField v-model="password" label="Contraseña" :error="passwordError" :readonly="loading" />

    <button type="button" class="text-[13px] underline underline-offset-2 max-md:min-h-11" @click="$emit('forgot')">
      ¿Has olvidado la contraseña?
    </button>

    <button type="submit" :class="[admBtnPrimary, 'w-full']" :aria-busy="loading" :aria-disabled="loading || undefined">
      <Loader2 v-if="loading" class="animate-adm-spin" aria-hidden="true" />
      {{ loading ? 'Entrando…' : 'Entrar' }}
    </button>
  </form>
</template>
