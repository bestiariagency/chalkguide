export type AdminRecoveryStep = 'checking' | 'form' | 'invalid' | 'no-access'

/** /administrador/restablecer: validates the recovery link, sets the new password, checks is_admin(). */
export function useAdminRecovery() {
  const { hasRecoverySession, setNewPassword } = useAdminAuth()
  const step = ref<AdminRecoveryStep>('checking')
  const password = ref('')
  const confirm = ref('')
  const loading = ref(false)
  const error = ref('')

  const passwordError = computed(() =>
    password.value && password.value.length < ADMIN_PASSWORD_MIN
      ? `Usa al menos ${ADMIN_PASSWORD_MIN} caracteres.`
      : '',
  )
  const confirmError = computed(() => (confirm.value && confirm.value !== password.value ? 'Las contraseñas no coinciden.' : ''))

  onMounted(async () => {
    if (hasAuthLinkError(window.location.search, window.location.hash)) {
      step.value = 'invalid'
      return
    }
    step.value = (await hasRecoverySession()) ? 'form' : 'invalid'
  })

  async function submit() {
    if (loading.value) return
    if (password.value.length < ADMIN_PASSWORD_MIN || confirm.value !== password.value) {
      error.value = passwordError.value || confirmError.value || 'Escribe la contraseña nueva dos veces.'
      return
    }
    loading.value = true
    error.value = ''
    try {
      const result = await setNewPassword(password.value)
      if (result === 'ok') return await navigateTo(ADMIN_BASE, { replace: true })
      step.value = 'no-access'
    } catch (failure) {
      const info = adminPasswordFailure(failure)
      if (info.expired) step.value = 'invalid'
      else error.value = info.message
    } finally {
      password.value = ''
      confirm.value = ''
      loading.value = false
    }
  }

  return { step, password, confirm, loading, error, passwordError, confirmError, submit }
}
