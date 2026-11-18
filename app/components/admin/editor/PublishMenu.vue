<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { ChevronDown, EyeOff, FileMinus, FilePen, GitCompareArrows, Link2, Undo2, Upload } from 'lucide-vue-next'

/**
 * Split publication button (design: articulo-editor "pubMore"). Left: the main action ("Publicar
 * cambios" in violet when the article is live, "Publicar" / "Publicar ahora" in ink otherwise).
 * Right ▾: Reka menu with only the entries that apply to the state: view/discard changes (live with
 * changes), "Volver a borrador" (scheduled, not live yet), copy the preview link (always) and
 * "Despublicar…" (live).
 */
const props = defineProps<{
  live: boolean
  changes: number
  scheduled?: boolean
  busy: boolean
  /** Mobile bottom bar: fills the width and the menu opens upwards. */
  block?: boolean
  /** No preview page (gyms): hides "Copiar enlace de vista previa". */
  noPreview?: boolean
  /** Text of the take-offline entry (default "Despublicar…"). */
  unpublishLabel?: string
  /** Why "Despublicar" is not available (legal pages): the entry shows disabled with this reason. */
  unpublishDisabled?: string
  /** Nothing to publish yet (empty page): the main button of a not-published item is disabled. */
  blocked?: boolean
}>()
defineEmits<{ primary: []; changes: []; discard: []; copy: []; unpublish: []; draft: [] }>()

const item = `${admMenuItem} cursor-pointer`
const tone = computed(() => (props.live ? (props.changes > 0 ? admBtnRev : admBtnGhost) : admBtnPrimary))
const label = computed(() => (props.live ? 'Publicar cambios' : props.scheduled ? 'Publicar ahora' : 'Publicar'))
/** "Ocultar" (gyms) gets the eye-off icon; "Despublicar" keeps the file icon. */
const unpublishIcon = computed(() => (props.unpublishLabel?.startsWith('Ocultar') ? EyeOff : FileMinus))
const hasChanges = computed(() => props.live && props.changes > 0)
</script>

<template>
  <div class="inline-flex" :class="block && 'min-w-0 flex-1'">
    <button type="button" :class="[tone, 'rounded-r-none!', block && 'min-w-0 flex-1']" :disabled="busy || (live && !changes) || (!live && blocked)" @click="$emit('primary')">
      <Upload class="max-sm:hidden" aria-hidden="true" /><span class="truncate">{{ label }}</span>
    </button>
    <DropdownMenuRoot>
      <DropdownMenuTrigger :class="[tone, 'w-8 rounded-l-none! border-l border-current/25 px-0 max-md:w-11']" aria-label="Más opciones de publicación" :disabled="busy">
        <ChevronDown aria-hidden="true" />
      </DropdownMenuTrigger>
      <DropdownMenuPortal>
        <DropdownMenuContent :side="block ? 'top' : 'bottom'" align="end" :side-offset="4" :class="[admPopover, 'admin w-60 font-sans']">
          <template v-if="hasChanges">
            <DropdownMenuItem :class="item" @select="$emit('changes')">
              <GitCompareArrows class="!text-adm-st-rev" aria-hidden="true" />{{ changes === 1 ? 'Ver el cambio' : `Ver los ${changes} cambios` }}
            </DropdownMenuItem>
            <DropdownMenuItem :class="item" @select="$emit('discard')"><Undo2 aria-hidden="true" />Descartar cambios…</DropdownMenuItem>
            <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
          </template>
          <template v-if="scheduled && !live">
            <DropdownMenuItem :class="item" @select="$emit('draft')"><FilePen aria-hidden="true" />Volver a borrador</DropdownMenuItem>
            <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
          </template>
          <template v-if="!noPreview">
            <DropdownMenuItem :class="item" @select="$emit('copy')"><Link2 aria-hidden="true" />Copiar enlace de vista previa</DropdownMenuItem>
          </template>
          <template v-if="live">
            <DropdownMenuSeparator v-if="!noPreview" class="my-1 h-px bg-adm-line" />
            <DropdownMenuItem v-if="unpublishDisabled" :class="[item, 'h-auto! items-start py-2 data-[disabled]:opacity-55']" disabled>
              <component :is="unpublishIcon" class="mt-0.5" aria-hidden="true" /><span>{{ unpublishLabel ?? 'Despublicar' }}<span class="block text-xs text-adm-meta">{{ unpublishDisabled }}</span></span>
            </DropdownMenuItem>
            <DropdownMenuItem v-else :class="item" @select="$emit('unpublish')"><component :is="unpublishIcon" aria-hidden="true" />{{ unpublishLabel ?? 'Despublicar…' }}</DropdownMenuItem>
          </template>
        </DropdownMenuContent>
      </DropdownMenuPortal>
    </DropdownMenuRoot>
  </div>
</template>
