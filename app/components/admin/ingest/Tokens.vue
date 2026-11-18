<script setup lang="ts">
import { KeyRound, Plus, Shield } from 'lucide-vue-next'
import { MAX_ACTIVE_TOKENS, type AdminToken } from '~/utils/admin-ingest'

/**
 * Tokens of the routine (README §19.4, J1–J7): scope banner, list (name, state, **last 4 characters**, created, last use, expiry)
 * and Revocar…. The panel never knows more than `hint`: the plain token only exists in the creation dialog.
 */
defineProps<{ tokens: readonly AdminToken[]; canCreate: boolean; busy: boolean }>()
const emit = defineEmits<{ create: []; revoke: [token: AdminToken] }>()
const CHIPS = {
  active: { label: 'Activo', cls: 'bg-adm-st-pub-bg text-adm-st-pub' },
  expired: { label: 'Caducado', cls: 'bg-adm-subtle text-adm-meta' },
  revoked: { label: 'Revocado', cls: 'bg-transparent text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line' },
} as const
const line = (t: AdminToken) =>
  [
    `creado el ${adminDate(t.createdAt)}`,
    t.lastUsedAt ? `último uso: ${runLabel(t.lastUsedAt)}` : 'sin usar',
    t.status === 'revoked' && t.revokedAt ? `revocado el ${adminDate(t.revokedAt)}` : t.status === 'expired' ? `caducó el ${adminDate(t.expiresAt)}` : `caduca el ${adminDate(t.expiresAt)}`,
  ].join(' · ')
</script>

<template>
  <div class="max-w-4xl space-y-4 px-4 py-4 md:px-6">
    <AdminBanner :icon="Shield">El token deja a la rutina <b class="font-medium">solo crear borradores</b>, con topes. Guardamos su huella (SHA-256), nunca el token. Caduca a los 30 días como máximo. Máximo {{ MAX_ACTIVE_TOKENS }} activos, para poder rotar sin cortar: crea el nuevo, pégalo en la rutina y revoca el anterior.</AdminBanner>
    <div class="flex items-center gap-3">
      <h2 class="text-sm font-semibold">Tokens</h2>
      <p v-if="!canCreate" class="text-xs text-adm-meta">Ya hay {{ MAX_ACTIVE_TOKENS }} activos: revoca uno para crear otro.</p>
      <button type="button" :class="[admBtnPrimary, 'ml-auto']" :disabled="!canCreate || busy" @click="emit('create')"><Plus aria-hidden="true" />Crear token</button>
    </div>
    <AdminStateBlock v-if="!tokens.length" kind="empty" :icon="KeyRound" title="Todavía no hay tokens" description="La rutina necesita uno para escribir borradores. Crea el primero." />
    <ul v-else class="divide-y divide-adm-line rounded-lg border border-adm-line" aria-label="Tokens de la rutina">
      <li v-for="t in tokens" :key="t.id" :class="['flex flex-wrap items-center gap-x-4 gap-y-2 p-3 sm:px-4', t.status !== 'active' && 'text-adm-meta']">
        <div class="min-w-0 flex-1">
          <p :class="['flex items-center gap-2 text-sm font-medium', t.status === 'active' && 'text-adm-fg']">{{ t.label }} <span :class="[admChip, CHIPS[t.status].cls]">{{ CHIPS[t.status].label }}</span></p>
          <p class="mt-0.5 text-xs"><span class="font-mono">cgi_…{{ t.hint }}</span> · {{ line(t) }}</p>
        </div>
        <button v-if="t.status === 'active'" type="button" :class="admBtnDangerGhost" :disabled="busy" @click="emit('revoke', t)">Revocar…</button>
      </li>
    </ul>
  </div>
</template>
