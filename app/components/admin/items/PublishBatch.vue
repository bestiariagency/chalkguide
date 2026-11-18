<script setup lang="ts">
import { CircleCheck, EyeOff, GitBranch, OctagonAlert } from 'lucide-vue-next'
import type { AdminItemRow } from '~/utils/admin-items'
import { blockerList } from '~/utils/admin-import-texts'
import type { PublishPlan } from '~/utils/admin-publish-batch'
import type { ItemInfo } from '~/utils/item-spec'

/**
 * "Publicar N {tipo}" (README §13.7): blocks and warns. Groups: blocked, hidden (never in a batch), ready, published with
 * changes (their draft is applied without the diff, D23) and a line about transparency.
 */
const props = defineProps<{ info: ItemInfo; plan: PublishPlan; selected: number; busy: boolean }>()
defineEmits<{ confirm: [] }>()
const open = defineModel<boolean>('open', { required: true })
const n = computed(() => props.plan.ready.length + props.plan.changes.length)
const transparency = computed(() =>
  props.info.category === 'shoe'
    ? 'Las cedidas por la marca y las que tienen enlace de afiliado se marcan siempre en la ficha.'
    : 'Las visitas invitadas se marcan siempre en la ficha.',
)
const href = (row: AdminItemRow) => adminPath(`${props.info.route}/${row.id}`)
</script>

<template>
  <AdminModal v-model:open="open" :title="n === 0 ? 'Nada que publicar' : `Publicar ${n} ${n === 1 ? info.noun : info.nouns}`" size="lg" :busy="busy">
    <p v-if="n === 0" class="mb-3 text-[13px] text-adm-meta">
      Ninguna de las fichas elegidas se puede publicar ahora: están publicadas sin cambios, ocultas o con algo que lo bloquea.
    </p>
    <p v-else class="mb-3 text-[13px] text-adm-meta">
      Has elegido {{ selected }}: se {{ n === 1 ? 'publica 1' : `publican ${n}` }}. {{ n === 1 ? 'Se verá' : 'Se verán' }} en el sitio al momento.
      <template v-if="plan.live.length"> {{ plan.live.length }} ya {{ plan.live.length === 1 ? 'está publicada sin cambios y no entra' : 'están publicadas sin cambios y no entran' }}.</template>
    </p>
    <div class="grid gap-3">
      <section v-if="plan.blocked.length" class="rounded-lg bg-adm-danger-soft p-3 text-[13px]" role="alert">
        <p class="flex items-center gap-1.5 font-medium"><OctagonAlert class="size-4" aria-hidden="true" />No se publican: algo lo bloquea ({{ plan.blocked.length }})</p>
        <ul class="mt-1.5 grid gap-1">
          <li v-for="item in plan.blocked" :key="item.row.id" class="flex flex-wrap items-baseline gap-x-2">
            <b class="font-medium">{{ item.row.name || 'Sin nombre' }}</b><span class="text-adm-meta">falta {{ blockerList(item.blockers).join('; ') }}</span>
            <NuxtLink :to="href(item.row)" class="ml-auto text-adm-acc hover:underline" target="_blank">Abrir<span class="sr-only"> {{ item.row.name }} (pestaña nueva)</span></NuxtLink>
          </li>
        </ul>
      </section>
      <section v-if="plan.hidden.length" class="rounded-lg bg-adm-subtle p-3 text-[13px]">
        <p class="flex items-center gap-1.5 font-medium"><EyeOff class="size-4" aria-hidden="true" />Las ocultas no se publican en lote ({{ plan.hidden.length }})</p>
        <p class="mt-0.5 text-adm-meta">{{ plan.hidden.length === 1 ? 'La ocultaste tú: si quieres que vuelva, publícala desde su ficha.' : 'Las ocultaste tú: si quieres que vuelvan, publícalas desde su ficha.' }}</p>
        <ul class="mt-1.5 grid gap-1"><li v-for="row in plan.hidden" :key="row.id"><NuxtLink :to="href(row)" class="hover:underline" target="_blank">{{ row.name || 'Sin nombre' }}<span class="sr-only"> (pestaña nueva)</span></NuxtLink></li></ul>
      </section>
      <section v-if="plan.ready.length" class="rounded-lg border border-adm-line p-3 text-[13px]">
        <p class="flex items-center gap-1.5 font-medium"><CircleCheck class="size-4 text-adm-ok" aria-hidden="true" />{{ plan.ready.length }} {{ plan.ready.length === 1 ? 'lista' : 'listas' }}: nada bloquea su publicación</p>
        <ul class="mt-1.5 grid max-h-48 gap-1 overflow-y-auto"><li v-for="row in plan.ready" :key="row.id">{{ row.name || 'Sin nombre' }}</li></ul>
      </section>
      <section v-if="plan.changes.length" class="rounded-lg border border-adm-st-rev-line p-3 text-[13px]">
        <p class="flex items-center gap-1.5 font-medium"><GitBranch class="size-4 text-adm-st-rev" aria-hidden="true" />{{ plan.changes.length }} {{ plan.changes.length === 1 ? 'publicada con cambios' : 'publicadas con cambios' }}</p>
        <p class="mt-0.5 text-adm-meta">{{ plan.changes.length === 1
          ? 'Se publican sus cambios sin revisarlos y el borrador se descarta sin dejar copia. Si otra edición ha chocado con ellos, no se toca y te avisamos: publícala desde su ficha.'
          : 'Se publican sus cambios sin revisarlos uno a uno y los borradores se descartan sin dejar copia. Si otra edición ha chocado con alguna, esa no se toca y te avisamos: publícala desde su ficha.' }}</p>
        <ul class="mt-1.5 grid max-h-48 gap-1 overflow-y-auto"><li v-for="row in plan.changes" :key="row.id"><NuxtLink :to="href(row)" class="text-adm-st-rev hover:underline" target="_blank">{{ row.name || 'Sin nombre' }}<span class="sr-only"> (pestaña nueva)</span></NuxtLink></li></ul>
      </section>
      <p v-if="n > 0" class="text-xs text-adm-meta">{{ transparency }}</p>
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">{{ n === 0 ? 'Cerrar' : 'Seguir revisando' }}</button>
      <button v-if="n > 0" type="button" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined" @click="$emit('confirm')">{{ busy ? 'Publicando…' : `Publicar ${n} ${n === 1 ? info.noun : info.nouns}` }}</button>
    </template>
  </AdminModal>
</template>
