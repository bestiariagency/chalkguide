<script setup lang="ts">
/** Change-password modal of "Tu cuenta". `submit` returns an error text, or '' when it worked (the modal closes). */
const props = defineProps<{ submit: (password: string) => Promise<string> }>()
const open = defineModel<boolean>('open', { default: false })
const password = ref('')
const confirm = ref('')
const error = ref('')
const busy = ref(false)

const passwordError = computed(() => (password.value && password.value.length < ADMIN_PASSWORD_MIN ? `Usa al menos ${ADMIN_PASSWORD_MIN} caracteres.` : ''))
const confirmError = computed(() => (confirm.value && confirm.value !== password.value ? 'Las contraseñas no coinciden.' : ''))
watch(open, (value) => {
  if (value) password.value = confirm.value = error.value = ''
})

async function send() {
  if (busy.value) return
  if (password.value.length < ADMIN_PASSWORD_MIN || confirm.value !== password.value) {
    error.value = passwordError.value || confirmError.value || 'Escribe la contraseña nueva dos veces.'
    return
  }
  busy.value = true
  error.value = await props.submit(password.value)
  busy.value = false
  if (!error.value) open.value = false
}
</script>

<template>
  <AdminModal v-model:open="open" title="Cambiar contraseña" description="Se aplica al momento. Las demás sesiones siguen abiertas." :busy="busy">
    <form id="settings-password" class="space-y-4" @submit.prevent="send">
      <div data-autofocus>
        <AdminPasswordField v-model="password" label="Contraseña nueva" autocomplete="new-password" required :help="`Mínimo ${ADMIN_PASSWORD_MIN} caracteres.`" :error="passwordError" />
      </div>
      <AdminPasswordField v-model="confirm" label="Repite la contraseña nueva" autocomplete="new-password" required :error="confirmError" />
      <p v-if="error" class="text-sm text-adm-danger" role="alert">{{ error }}</p>
    </form>
    <template #footer>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="submit" form="settings-password" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy">{{ busy ? 'Cambiando…' : 'Cambiar contraseña' }}</button>
    </template>
  </AdminModal>
</template>
