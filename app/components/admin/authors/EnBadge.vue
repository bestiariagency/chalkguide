<script setup lang="ts">
import { enStatus } from '~/utils/admin-authors'

/** «EN» chip of a signature: complete (role and bio in English), partial or none. Text for screen readers; never colour alone. */
const props = defineProps<{ role: string | null | undefined; bio: string | null | undefined }>()
const status = computed(() => enStatus(props.role, props.bio))
const tone = { full: 'border-adm-st-pub/45 text-adm-st-pub', part: 'border-adm-warn/45 text-adm-warn', none: 'border-dashed border-adm-line-strong text-adm-muted line-through' }
</script>

<template>
  <span :class="['inline-grid h-[18px] flex-none place-items-center rounded-[3px] border px-1 font-mono text-[11px] font-medium', tone[status.state]]" :title="status.text">
    EN<span class="sr-only">: {{ status.text }}</span>
  </span>
</template>
