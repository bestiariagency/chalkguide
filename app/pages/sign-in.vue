<script setup lang="ts">
import { CircleAlert, Info } from 'lucide-vue-next'

/**
 * Sign in with Google (only to write opinions; the site is fully public). Prerendered: `next`
 * is read on the client. Signing in never subscribes to the newsletter (GDPR rule 8).
 */
const { t } = useI18n()
const route = useRoute()
const { isSignedIn, loginWithGoogle } = useAuth()

const next = computed(() => safeNextPath(route.query.next))
const loading = ref(false)
const failed = ref(false)

// Already signed in: nothing to do here, go back to where the user came from.
watch(isSignedIn, (signedIn) => signedIn && navigateTo(next.value), { immediate: true })

async function start() {
  loading.value = true
  failed.value = false
  try {
    await loginWithGoogle(next.value)
  } catch {
    failed.value = true
    loading.value = false
  }
}
</script>

<template>
  <PagePlaceholder :title="t('auth.title')" robots="noindex, nofollow">
    <div class="mt-4 max-w-measure">
      <p class="text-lead text-meta">{{ t('auth.body') }}</p>
      <p
        v-if="failed"
        class="mt-5 flex items-start gap-2 rounded-md border border-danger-text/60 bg-danger-muted p-3 text-body-sm"
        role="alert"
      >
        <CircleAlert :size="20" class="mt-0.5 shrink-0 text-danger-text" aria-hidden="true" />
        {{ t('auth.error') }}
      </p>
      <AuthGoogleButton class="mt-6 w-full sm:w-auto" :loading="loading" @click="start" />
      <p class="mt-4 flex gap-2 text-caption text-meta">
        <Info :size="16" class="mt-0.5 shrink-0" aria-hidden="true" />
        {{ t('reviews.signInHint') }}
      </p>
    </div>
  </PagePlaceholder>
</template>
