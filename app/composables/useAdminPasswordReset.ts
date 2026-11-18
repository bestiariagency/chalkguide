/** "¿Has olvidado la contraseña?" on the login: asks for the email and always answers neutrally. */
export function useAdminPasswordReset() {
  const { sendResetLink } = useAdminAuth()
  const email = ref('')
  const loading = ref(false)
  const sent = ref(false)
  const error = ref('')

  async function submit() {
    if (loading.value) return
    const value = email.value.trim()
    if (!/^\S+@\S+\.\S+$/.test(value)) {
      error.value = 'Escribe un email válido.'
      return
    }
    loading.value = true
    error.value = ''
    try {
      await sendResetLink(value)
      sent.value = true
    } catch (failure) {
      if (adminResetFailure(failure) === 'rate-limit') {
        error.value = 'Demasiados intentos. Prueba de nuevo en unos minutos.'
      } else {
        // Same answer whether or not the account exists (and for transient errors on our side).
        sent.value = true
      }
    } finally {
      loading.value = false
    }
  }

  return { email, loading, sent, error, submit }
}
