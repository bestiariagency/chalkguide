<script setup lang="ts">
import { CircleAlert, Loader2, ShieldX } from 'lucide-vue-next'

/**
 * Password recovery landing (public page: the link brings a recovery session, not an admin one).
 * Sets the new password and then checks guide.is_admin(). SPA, Spanish only, noindex.
 */
definePageMeta({ layout: false, i18n: false })
useAdminHead('Nueva contraseña')
const { step, password, confirm, loading, error, passwordError, confirmError, submit } = useAdminRecovery()
</script>

<template>
  <div class="admin min-h-dvh bg-adm-side font-sans text-[14px] leading-[22px] text-adm-fg antialiased">
    <main id="contenido" class="grid min-h-dvh place-items-center px-4 py-10">
      <div class="w-full max-w-[380px]">
        <img src="/brand/logo-dark.svg" alt="ChalkGuide" class="h-[18px] w-auto" width="128" height="18" />
        <h1 class="mt-8 text-xl leading-7 font-semibold tracking-tight">
          {{ step === 'invalid' ? 'El enlace ha caducado' : 'Elige una contraseña nueva' }}
        </h1>

        <p v-if="step === 'checking'" class="mt-6 flex items-center gap-2 text-[13px] text-adm-meta" role="status">
          <Loader2 class="size-4 animate-adm-spin" aria-hidden="true" />Comprobando el enlace…
        </p>

        <div v-else-if="step === 'invalid'" :class="[admCard, 'mt-6 space-y-4 p-5']" role="alert">
          <p class="flex items-start gap-2.5 text-[13px] leading-5">
            <CircleAlert class="mt-0.5 size-4 shrink-0 text-adm-danger" aria-hidden="true" />
            <span>Este enlace ha caducado o ya se ha usado. Pide uno nuevo con tu email.</span>
          </p>
          <NuxtLink :to="`${ADMIN_LOGIN}?recuperar=1`" :class="[admBtnPrimary, 'w-full']">Pedir un enlace nuevo</NuxtLink>
        </div>

        <div v-else-if="step === 'no-access'" :class="[admCard, 'mt-6 space-y-4 p-5']" role="alert">
          <p class="flex items-start gap-2.5 text-[13px] leading-5">
            <ShieldX class="mt-0.5 size-4 shrink-0 text-adm-warn-icon" aria-hidden="true" />
            <span>{{ ADMIN_LOGIN_MESSAGES['no-access'] }}</span>
          </p>
          <a href="/" :class="[admBtnGhost, 'w-full']">Ir al sitio</a>
        </div>

        <form v-else :class="[admCard, 'mt-6 space-y-4 p-5']" novalidate :aria-busy="loading" @submit.prevent="submit">
          <p v-if="error" role="alert" class="flex items-start gap-2.5 rounded-lg bg-adm-danger-soft px-3 py-2.5 text-[13px] leading-5">
            <CircleAlert class="mt-0.5 size-4 shrink-0 text-adm-danger" aria-hidden="true" />
            <span>{{ error }}</span>
          </p>
          <AdminPasswordField v-model="password" label="Contraseña nueva" autocomplete="new-password" :help="`Mínimo ${ADMIN_PASSWORD_MIN} caracteres.`" :error="passwordError" :readonly="loading" required />
          <AdminPasswordField v-model="confirm" label="Repite la contraseña" autocomplete="new-password" :error="confirmError" :readonly="loading" required />
          <button type="submit" :class="[admBtnPrimary, 'w-full']" :aria-busy="loading" :aria-disabled="loading || undefined">
            <Loader2 v-if="loading" class="animate-adm-spin" aria-hidden="true" />
            {{ loading ? 'Guardando…' : 'Guardar la contraseña' }}
          </button>
        </form>
      </div>
    </main>
  </div>
</template>
