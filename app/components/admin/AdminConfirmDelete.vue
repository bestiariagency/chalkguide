<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next'

/**
 * Delete confirmation in the 4 levels of the design system (alertdialog, initial focus on Cancel):
 * - `simple`: consequence + red button.
 * - `in-use`: blocked; lists where the item is used (`usages`) and offers an alternative.
 * - `reassign`: pick where dependants go (`targets`) before deleting; `confirm` carries the choice.
 * - `irreversible`: type `expected` (e.g. the email) to enable the button (RGPD erasure).
 * `confirm` is emitted with the reassign target or typed text; the parent closes it when done.
 */
const props = withDefaults(
  defineProps<{
    level: 'simple' | 'in-use' | 'reassign' | 'irreversible'
    title: string
    description?: string
    confirmLabel?: string
    busy?: boolean
    stacked?: boolean
    usages?: AdminUsage[]
    /** in-use: label of the reversible alternative (e.g. "Reemplazar archivo en su lugar"). */
    alternativeLabel?: string
    targets?: AdminOption[]
    targetLabel?: string
    targetHelp?: string
    /** irreversible: text to type. */
    expected?: string
    expectedLabel?: string
  }>(),
  { confirmLabel: 'Eliminar', usages: () => [], targets: () => [], description: undefined, alternativeLabel: undefined, targetLabel: undefined, targetHelp: undefined, expected: undefined, expectedLabel: undefined },
)
const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ confirm: [value?: string]; alternative: [] }>()

const target = ref<string | undefined>()
const typed = ref('')
watch(open, (value) => {
  if (value) {
    typed.value = ''
    target.value = props.targets.find((t) => !t.disabled)?.value
  }
})

const blocked = computed(() => props.level === 'in-use')
const canConfirm = computed(() => {
  if (props.busy) return false
  if (props.level === 'reassign') return !!target.value
  if (props.level === 'irreversible') return typed.value.trim().toLowerCase() === (props.expected ?? '').trim().toLowerCase()
  return true
})

function confirm() {
  if (!canConfirm.value) return
  emit('confirm', props.level === 'reassign' ? target.value : props.level === 'irreversible' ? typed.value : undefined)
}
const typedId = `typed-${useId()}`
</script>

<template>
  <AdminModal v-model:open="open" alert :stacked="stacked" :title="title" :description="description" :busy="busy">
    <template v-if="level !== 'simple'" #default>
      <ul v-if="blocked" class="divide-y divide-adm-line rounded-lg border border-adm-line text-sm" aria-label="Dónde está en uso">
        <li v-for="usage in usages" :key="usage.label" class="flex min-h-10 items-center gap-2 px-3 py-1">
          <span class="min-w-0 flex-1 truncate">{{ usage.label }}</span>
          <span v-if="usage.where" class="text-xs text-adm-meta">{{ usage.where }}</span>
          <NuxtLink v-if="usage.href" :to="usage.href" class="text-xs underline underline-offset-2">
            Abrir<span class="sr-only">: {{ usage.label }}</span>
          </NuxtLink>
        </li>
      </ul>
      <AdminSelect
        v-else-if="level === 'reassign'"
        v-model="target"
        :label="targetLabel ?? 'Mover a'"
        :help="targetHelp"
        :options="targets"
        required
      />
      <div v-else>
        <label :for="typedId" :class="admLabel">{{ expectedLabel ?? 'Escribe el texto para confirmar' }}</label>
        <input
          :id="typedId"
          v-model="typed"
          :class="[admInput, 'font-mono']"
          :placeholder="expected"
          autocomplete="off"
          spellcheck="false"
          @keydown.enter.prevent="confirm"
        />
      </div>
    </template>
    <template #footer>
      <template v-if="blocked">
        <button v-if="alternativeLabel" type="button" :class="admBtnGhost" @click="emit('alternative')">
          {{ alternativeLabel }}
        </button>
        <button type="button" :class="admBtnPrimary" data-autofocus @click="open = false">Entendido</button>
      </template>
      <template v-else>
        <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
        <button type="button" :class="admBtnDanger" :disabled="!canConfirm" :aria-busy="busy || undefined" @click="confirm">
          <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />
          {{ confirmLabel }}
        </button>
      </template>
    </template>
  </AdminModal>
</template>
