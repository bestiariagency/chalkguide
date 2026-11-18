<script setup lang="ts">
import { LogOut } from 'lucide-vue-next'

/** Discreet sign-out, only rendered once the browser session is known (cached HTML has none). */
defineProps<{ iconOnly?: boolean }>()

const { t } = useI18n()
const { isSignedIn, logout } = useAuth()
const toast = useToast()
const pending = ref(false)

async function onClick() {
  if (pending.value) return
  pending.value = true
  try {
    await logout()
    toast.info(t('auth.signedOut'))
  } catch {
    toast.error(t('auth.signOutError'))
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <button
    v-if="isSignedIn"
    type="button"
    :aria-busy="pending || undefined"
    :aria-label="iconOnly ? t('auth.signOut') : undefined"
    :title="iconOnly ? t('auth.signOut') : undefined"
    class="inline-flex min-h-11 items-center gap-1.5 rounded-md text-body-sm whitespace-nowrap text-meta transition-colors duration-200 hover:text-foreground aria-busy:cursor-progress"
    :class="iconOnly ? 'min-w-11 justify-center' : 'px-2'"
    @click="onClick"
  >
    <LogOut :size="iconOnly ? 18 : 16" aria-hidden="true" />
    <template v-if="!iconOnly">{{ t('auth.signOut') }}</template>
  </button>
</template>
