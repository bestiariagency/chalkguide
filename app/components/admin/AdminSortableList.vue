<script setup lang="ts" generic="T">
import { ArrowDown, ArrowUp, EllipsisVertical, GripVertical } from 'lucide-vue-next'
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuTrigger } from 'reka-ui'

/**
 * Drag-and-drop sortable list (categories, criteria, gallery). Accessible without a pointer: focus
 * the handle, Space lifts, arrows move, Space drops, Esc cancels (announced). The "…" menu offers
 * Move up / Move down (also the touch alternative). `reorder` fires once per committed change; the
 * parent saves (and reports errors with a toast). Item content goes in the `item` slot.
 */
const props = defineProps<{
  itemKey: (item: T) => string
  itemLabel: (item: T) => string
  /** Accessible name of the list. */
  label: string
  /** Extra classes for the whole row (`li`), e.g. to tint the selected one. */
  itemClass?: (item: T) => string | false | undefined
}>()
const items = defineModel<T[]>('items', { required: true })
const emit = defineEmits<{ reorder: [items: T[], moved: { key: string; from: number; to: number }] }>()

const { lifted, dragging, drop, announcement, moveBy, onHandleKey, dragStart, dragOver, dragEnd, indexOf } = useAdminSortable<T>({
  items,
  itemKey: props.itemKey,
  itemLabel: props.itemLabel,
  onCommit: (next, moved) => emit('reorder', next, moved),
})
const dragReady = ref<string | null>(null)
</script>

<template>
  <div>
    <ul :aria-label="label" class="divide-y divide-adm-line rounded-lg border border-adm-line bg-adm-elev">
      <li
        v-for="(item, index) in items"
        :key="itemKey(item)"
        :draggable="dragReady === itemKey(item)"
        :class="[
          itemClass?.(item),
          'flex min-h-12 items-center gap-1 px-2 py-1 transition-transform duration-150 motion-reduce:transition-none',
          dragging === itemKey(item) && 'opacity-35',
          lifted === itemKey(item) && 'relative z-[5] rounded-lg bg-adm-elev shadow-adm-drag outline-2 -outline-offset-2 outline-adm-acc',
          drop?.key === itemKey(item) && (drop.after ? 'shadow-[inset_0_-2px_0_var(--adm-acc)]' : 'shadow-[inset_0_2px_0_var(--adm-acc)]'),
        ]"
        @dragstart="dragStart(itemKey(item), $event)"
        @dragover="dragOver(itemKey(item), $event)"
        @drop.prevent="dragEnd(true)"
        @dragend="dragEnd(false); dragReady = null"
      >
        <button
          type="button"
          :class="['grid size-8 flex-none cursor-grab touch-none place-items-center rounded text-adm-muted hover:bg-adm-subtle hover:text-adm-fg max-md:size-11', lifted === itemKey(item) && 'cursor-grabbing text-adm-fg']"
          :aria-label="`Reordenar ${itemLabel(item)}, posición ${index + 1} de ${items.length}`"
          :aria-pressed="lifted === itemKey(item)"
          aria-roledescription="elemento ordenable"
          @keydown="onHandleKey($event, itemKey(item))"
          @pointerdown="dragReady = itemKey(item)"
          @pointerup="dragReady = null"
        >
          <GripVertical class="size-4" aria-hidden="true" />
        </button>
        <div class="min-w-0 flex-1"><slot name="item" :item="item" :index="index" /></div>
        <DropdownMenuRoot>
          <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Mover ${itemLabel(item)}`">
            <EllipsisVertical aria-hidden="true" />
          </DropdownMenuTrigger>
          <DropdownMenuPortal>
            <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin font-sans']">
              <DropdownMenuItem :class="[admMenuItem, 'cursor-pointer data-[disabled]:opacity-45']" :disabled="indexOf(itemKey(item)) === 0" @select="moveBy(itemKey(item), -1)">
                <ArrowUp aria-hidden="true" />Mover arriba
              </DropdownMenuItem>
              <DropdownMenuItem :class="[admMenuItem, 'cursor-pointer data-[disabled]:opacity-45']" :disabled="indexOf(itemKey(item)) === items.length - 1" @select="moveBy(itemKey(item), 1)">
                <ArrowDown aria-hidden="true" />Mover abajo
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenuPortal>
        </DropdownMenuRoot>
      </li>
    </ul>
    <p class="sr-only" role="status" aria-live="assertive">{{ announcement }}</p>
  </div>
</template>
