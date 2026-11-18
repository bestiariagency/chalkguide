<script setup lang="ts">
import { Eye, EyeOff, Info } from 'lucide-vue-next'
import { criterionEffect, pluralItems, type AdminCriterion, type CriterionUsage } from '~/utils/admin-criteria'

/** "Estado" block of the edit drawer: badge, effect, the two counts, lock by formula and activate / deactivate. */
const props = defineProps<{ criterion: AdminCriterion; usage: CriterionUsage; busy: boolean }>()
const emit = defineEmits<{ deactivate: []; reactivate: [] }>()
const uid = useId()
const locked = computed(() => props.criterion.used_in_formula)
const lockText = computed(() => criterionEffect(props.criterion)?.lock ?? 'Entra en la fórmula de un índice: no se puede desactivar mientras la use.')
</script>

<template>
  <section class="border-t border-adm-line pt-4" aria-labelledby="crit-state-h">
    <h3 id="crit-state-h" class="text-sm font-semibold">Estado</h3>
    <div class="mt-2 flex items-start gap-3">
      <span v-if="criterion.is_active" :class="[admChip, 'mt-0.5 bg-adm-st-pub-bg text-adm-st-pub']"><span class="size-1.5 flex-none rounded-full bg-current" aria-hidden="true" />Activo</span>
      <span v-else :class="[admChip, 'mt-0.5 bg-adm-subtle text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line']">Inactivo</span>
      <p class="flex-1 text-sm text-adm-meta">{{ criterion.is_active ? 'Se puntúa y cuenta en medias e índices.' : 'No se puntúa ni cuenta. Tus notas se conservan; las de lectores también, salvo que reenvíen su opinión mientras esté inactivo.' }}</p>
    </div>
    <dl class="mt-3 grid grid-cols-2 gap-2 text-sm">
      <div :class="[admCard, 'px-3 py-2']"><dt class="text-xs text-adm-meta">Tus notas</dt><dd class="font-medium tabular-nums">{{ usage.author_items ? pluralItems(usage.author_items) : 'Ninguna' }}</dd></div>
      <div :class="[admCard, 'px-3 py-2']"><dt class="text-xs text-adm-meta">Notas de lectores</dt><dd class="font-medium tabular-nums">{{ usage.user_reviews || 'Ninguna' }}</dd></div>
    </dl>
    <p v-if="locked" :id="`lock-${uid}`" class="mt-3 flex items-start gap-2 rounded-lg bg-adm-subtle px-3 py-2 text-[13px] leading-5">
      <Info class="mt-0.5 size-4 flex-none text-adm-info" aria-hidden="true" />{{ lockText }}
    </p>
    <div class="mt-3 flex flex-wrap gap-2">
      <button v-if="criterion.is_active" type="button" :class="admBtnGhost" :disabled="locked || busy" :aria-describedby="locked ? `lock-${uid}` : undefined" @click="emit('deactivate')">
        <EyeOff aria-hidden="true" />Desactivar…
      </button>
      <button v-else type="button" :class="admBtnGhost" :disabled="busy" @click="emit('reactivate')"><Eye aria-hidden="true" />Reactivar</button>
    </div>
  </section>
</template>
