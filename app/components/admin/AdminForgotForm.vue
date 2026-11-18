<script setup lang="ts">
import { CircleCheck, Loader2 } from 'lucide-vue-next'

/** Recovery request: email → neutral confirmation (never says whether the account exists). */
const emit = defineEmits<{ back: []; sent: [] }>()
const { email, loading, sent, error, submit } = useAdminPasswordReset()
const form = ref<HTMLFormElement | null>(null)
// Focus lands on the email field when the form opens (and on the title once the link is sent).
onMounted(() => form.value?.querySelector('input')?.focus())
watch(sent, (value) => value && emit('sent'))
</script>

<template>
  <form ref="form" :class="[admCard, 'mt-6 space-y-4 p-5']" novalidate :aria-busy="loading" @submit.prevent="submit">
    <p v-if="sent" role="status" class="flex items-start gap-2.5 rounded-lg bg-adm-ok-soft px-3 py-2.5 text-[13px] leading-5">
      <CircleCheck class="mt-0.5 size-4 shrink-0 text-adm-ok" aria-hidden="true" />
      <span>{{ ADMIN_RESET_SENT }} Revisa también la carpeta de spam.</span>
    </p>
    <template v-else>
      <p class="text-[13px] text-adm-meta">Escribe tu email y te enviaremos un enlace para elegir una contraseña nueva.</p>
      <AdminTextField v-model="email" label="Email" type="email" autocomplete="username" inputmode="email" placeholder="nombre@dominio.com" :error="error" :readonly="loading" />
      <button type="submit" :class="[admBtnPrimary, 'w-full']" :aria-busy="loading" :aria-disabled="loading || undefined">
        <Loader2 v-if="loading" class="animate-adm-spin" aria-hidden="true" />
        {{ loading ? 'Enviando…' : 'Enviar el enlace' }}
      </button>
    </template>
    <button type="button" class="text-[13px] underline underline-offset-2 max-md:min-h-11" @click="$emit('back')">
      Volver a entrar
    </button>
  </form>
</template>
