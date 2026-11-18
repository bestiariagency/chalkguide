<script setup lang="ts">
/** Ajustes › Tu cuenta: masked email, change password, open sessions and "Cerrar las demás". Not part of the unsaved-changes bar. */
const account = useAdminAccount()
const { email, sessions, sessionsLoading, sessionsFailed, others, closing } = account
const changing = ref(false)
const row = 'flex flex-wrap items-center gap-3 p-4'
</script>

<template>
  <section id="cuenta" class="scroll-mt-6 border-t border-adm-line pt-8" aria-labelledby="h-cuenta">
    <h2 id="h-cuenta" class="text-base font-semibold">Tu cuenta</h2>
    <div :class="[admCard, 'mt-4 divide-y divide-adm-line text-sm']">
      <div :class="row">
        <div class="flex-1"><p class="font-medium">Email</p><p class="text-xs text-adm-meta">Con el que entras al panel.</p></div>
        <span v-if="email" class="font-mono text-xs" :aria-label="`Email enmascarado: ${maskEmail(email)}`">{{ maskEmail(email) }}</span>
        <span v-else class="text-xs text-adm-muted">—</span>
      </div>
      <div :class="row">
        <div class="flex-1"><p class="font-medium">Contraseña</p><p class="text-xs text-adm-meta">Elige una larga que no uses en otro sitio.</p></div>
        <button type="button" :class="admBtnGhost" @click="changing = true">Cambiar…<span class="sr-only"> contraseña</span></button>
      </div>
      <div :class="row">
        <div class="min-w-0 flex-1">
          <p class="font-medium">Sesiones abiertas</p>
          <p v-if="sessionsLoading" class="text-xs text-adm-meta" role="status">Cargando sesiones…</p>
          <p v-else-if="sessionsFailed" class="text-xs text-adm-danger" role="alert">
            No se han podido cargar las sesiones.
            <button type="button" class="font-medium underline underline-offset-2 max-md:min-h-11" @click="account.loadSessions()">Reintentar</button>
          </p>
          <ul v-else class="mt-1 space-y-0.5 text-xs text-adm-meta">
            <li v-for="(s, i) in sessions" :key="i">
              <span class="text-adm-fg">{{ deviceName(s.user_agent) }}</span>
              <template v-if="s.is_current"> · esta sesión</template>
              <template v-else> · última actividad: {{ relativeUpdated(s.last_active_at) }}</template>
            </li>
          </ul>
        </div>
        <button type="button" :class="admBtnGhost" :disabled="closing || sessionsLoading || sessionsFailed || !others" :aria-busy="closing" @click="account.closeOthers()">
          {{ closing ? 'Cerrando…' : 'Cerrar las demás' }}<span v-if="!closing" class="sr-only"> sesiones</span>
        </button>
      </div>
    </div>
    <AdminSettingsPassword v-model:open="changing" :submit="account.changePassword" />
  </section>
</template>
