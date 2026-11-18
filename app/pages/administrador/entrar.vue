<script setup lang="ts">
/** Panel login (docs/design/admin/login.html). SPA, Spanish only, outside the panel layout. */
definePageMeta({ layout: false, i18n: false })
useAdminHead('Entrar')
const route = useRoute()
const forgot = ref(route.query.recuperar === '1')
const title = ref<HTMLElement | null>(null)
const focusTitle = () => nextTick(() => title.value?.focus())
</script>

<template>
  <div class="admin min-h-dvh bg-adm-side font-sans text-[14px] leading-[22px] text-adm-fg antialiased">
    <main id="contenido" class="grid min-h-dvh place-items-center px-4 py-10">
      <div class="w-full max-w-[380px]">
        <img src="/brand/logo-dark.svg" alt="ChalkGuide" class="h-[18px] w-auto" width="128" height="18" />
        <h1 ref="title" tabindex="-1" class="mt-8 outline-none text-xl leading-7 font-semibold tracking-tight">
          {{ forgot ? 'Recuperar la contraseña' : 'Entrar al panel' }}
        </h1>
        <p class="mt-1 text-[13px] text-adm-meta">Solo para quien edita ChalkGuide.</p>
        <AdminForgotForm v-if="forgot" @back="((forgot = false), focusTitle())" @sent="focusTitle" />
        <AdminLoginForm v-else @forgot="forgot = true" />
        <p class="mt-4 text-xs text-adm-meta">
          ¿Buscabas la guía?
          <a href="/" class="underline underline-offset-2 hover:text-adm-fg">Ir al sitio</a>
        </p>
      </div>
    </main>
  </div>
</template>
