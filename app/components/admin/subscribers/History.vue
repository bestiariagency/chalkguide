<script setup lang="ts">
import { historyLines } from '~/utils/admin-subscriber-detail'
import type { SubscriberEvent } from '~/utils/admin-subscribers'

/** Timeline of `subscriber_consent_events`, newest first: what happened, when and who did it. It cannot be edited. */
const props = defineProps<{ events: readonly SubscriberEvent[] }>()
const lines = computed(() => historyLines(props.events))
const dot = { ok: 'bg-adm-st-pub', off: 'bg-adm-meta', none: 'bg-adm-line-strong' } as const
</script>

<template>
  <section aria-labelledby="sub-history-h">
    <h3 id="sub-history-h" class="mb-3 text-xs font-medium text-adm-meta">Historial <span class="font-normal">· no se puede editar</span></h3>
    <p v-if="!lines.length" class="text-adm-muted">Sin eventos.</p>
    <ol v-else>
      <li v-for="line in lines" :key="line.key" class="relative flex gap-2.5 pb-3 after:absolute after:top-3.5 after:bottom-0 after:left-[3.5px] after:w-px after:bg-adm-line last:after:hidden">
        <span :class="['mt-1.5 size-2 flex-none rounded-full', dot[line.tone]]" aria-hidden="true" />
        <span class="min-w-0">
          <span v-if="line.related" class="mr-1.5 rounded-sm bg-adm-acc-soft px-1.5 py-px text-[11px] font-medium text-adm-acc">Afines</span>{{ line.text }}
          <span class="block text-xs text-adm-muted"><span class="tabular-nums">{{ line.when }}</span> · {{ line.who }}</span>
        </span>
      </li>
    </ol>
  </section>
</template>
