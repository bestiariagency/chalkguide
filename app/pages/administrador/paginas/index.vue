<script setup lang="ts">
import { Lock } from 'lucide-vue-next'
import type { AdminPageRow, PageDef } from '~/utils/admin-pages'
import { pageErrorMessage } from '~/utils/admin-pages'

/**
 * `/administrador/paginas` (F6.13, D34): the five fixed pages of the site. No create, duplicate or
 * delete (the keys are closed). Editing happens in `paginas/[key]`.
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Páginas')

const pages = useAdminPages()
const { list, rows } = pages
type Dialog = { kind: 'discard' | 'unpublish'; def: PageDef; row: AdminPageRow }
const dialog = ref<Dialog>()
const open = computed({ get: () => !!dialog.value, set: (value) => { if (!value) dialog.value = undefined } })
const errorCode = computed(() => (list.error.value as { code?: string } | null)?.code)

async function confirm() {
  const current = dialog.value
  if (!current) return
  const done = await (current.kind === 'discard' ? pages.discard(current.def, current.row) : pages.unpublish(current.def, current.row))
  if (done) dialog.value = undefined
}
</script>

<template>
  <section aria-labelledby="pages-title">
    <AdminPageBar title="Páginas" title-id="pages-title">
      <template #meta>
        <span :class="[admChip, 'ml-1 hidden bg-adm-subtle text-adm-meta md:inline-flex']" title="Las crea el sistema; no se añaden ni se borran"><Lock aria-hidden="true" />5 páginas fijas del sitio</span>
      </template>
    </AdminPageBar>

    <AdminPagesHeroPhotos />

    <AdminPagesSkeleton v-if="list.status.value === 'pending' && !list.data.value" />
    <AdminStateBlock v-else-if="list.error.value" kind="error" title="No se han podido cargar las páginas" :description="pageErrorMessage(list.error.value)" :code="errorCode" @retry="list.refresh()" />
    <AdminPagesList v-else :rows="rows" :unpublished-legal="pages.unpublishedLegal.value" @discard="(def, row) => (dialog = { kind: 'discard', def, row })" @unpublish="(def, row) => (dialog = { kind: 'unpublish', def, row })" />

    <AdminConfirmDelete
      v-model:open="open"
      level="simple"
      :title="dialog?.kind === 'discard' ? `¿Descartar los cambios de «${dialog.def.label}»?` : `¿Despublicar «${dialog?.def.label ?? ''}»?`"
      :description="dialog?.kind === 'discard' ? 'La página vuelve a la versión publicada. Lo que se ve en el sitio no cambia.' : `${dialog?.def.routeEs} mostrará «Esta página aún no está publicada» y dejará de salir en buscadores; ${dialog?.def.routeEn} dará error 404. El texto no se borra: vuelve a borrador y puedes publicarlo otra vez.`"
      :confirm-label="dialog?.kind === 'discard' ? 'Descartar cambios' : 'Despublicar'"
      :busy="pages.busy.value"
      @confirm="confirm"
    />
  </section>
</template>
