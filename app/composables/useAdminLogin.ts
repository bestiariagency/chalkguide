/** Login form state for /administrador/entrar: email + password (D2), then guide.is_admin(). */
export function useAdminLogin() {
  const route = useRoute()
  const { login } = useAdminAuth()

  const email = ref('')
  const password = ref('')
  const loading = ref(false)
  const failure = ref<AdminLoginFailure | null>(null)
  const emailError = ref('')
  const passwordError = ref('')

  const message = computed(() => (failure.value ? ADMIN_LOGIN_MESSAGES[failure.value] : ''))
  const next = computed(() => adminNextPath(route.query.next))

  async function submit() {
    if (loading.value) return
    emailError.value = email.value.trim() ? '' : 'Escribe tu email.'
    passwordError.value = password.value ? '' : 'Escribe tu contraseña.'
    if (emailError.value || passwordError.value) {
      failure.value = null
      return
    }
    loading.value = true
    failure.value = null
    try {
      const result = await login(email.value.trim(), password.value)
      if (result === 'ok') return await navigateTo(next.value, { replace: true })
      failure.value = 'no-access'
    } catch (error) {
      failure.value = adminLoginFailure(error)
    } finally {
      password.value = ''
      loading.value = false
    }
  }

  return { email, password, loading, failure, message, emailError, passwordError, submit }
}
