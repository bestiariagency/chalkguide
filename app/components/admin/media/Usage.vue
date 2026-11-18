<script setup lang="ts">
import { usageIcon } from '~/utils/admin-media-usage'
import { usageToAdmin, type MediaUsageRow } from '~/utils/admin-media-library'

/** "Dónde se usa": every place that points to the file, with a link to edit it. */
defineProps<{ rows: readonly MediaUsageRow[]; status: 'idle' | 'pending' | 'error' }>()
</script>

<template>
  <section aria-labelledby="h-uso">
    <h3 id="h-uso" class="flex items-center gap-2 text-sm font-semibold">
      Dónde se usa
      <span v-if="status === 'idle'" class="rounded-full bg-adm-subtle px-1.5 text-xs font-medium tabular-nums">{{ rows.length }}</span>
    </h3>
    <p v-if="status === 'pending'" class="mt-2 text-sm text-adm-meta" role="status">Comprobando usos…</p>
    <p v-else-if="status === 'error'" class="mt-2 text-sm text-adm-danger" role="alert">No se ha podido comprobar dónde se usa. No se podrá eliminar hasta saberlo.</p>
    <p v-else-if="!rows.length" class="mt-2 text-sm text-adm-meta">Todavía no se usa en ningún sitio.</p>
    <ul v-else class="mt-2 divide-y divide-adm-line rounded-lg border border-adm-line text-sm">
      <li v-for="u in rows" :key="`${u.owner_table}-${u.owner_id}-${u.role}`" class="flex min-h-10 items-center gap-2 px-3 py-1 max-md:min-h-11">
        <component :is="usageIcon(u)" class="size-4 flex-none text-adm-muted" aria-hidden="true" />
        <template v-for="a in [usageToAdmin(u)]" :key="a.label">
          <NuxtLink v-if="a.href" :to="a.href" class="min-w-0 flex-1 truncate underline decoration-adm-line-strong underline-offset-2 hover:decoration-current focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-adm-acc">{{ a.label }}</NuxtLink>
          <span v-else class="min-w-0 flex-1 truncate">{{ a.label }}</span>
          <span class="text-xs text-adm-meta">{{ a.where }}</span>
        </template>
      </li>
    </ul>
  </section>
</template>
