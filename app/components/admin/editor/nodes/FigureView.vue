<script setup lang="ts">
import { RadioGroupItem, RadioGroupRoot } from 'reka-ui'
import { Trash2 } from 'lucide-vue-next'
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/vue-3'
import { FIGURE_WIDTH_LABELS, canBleed } from '~/utils/article-figure'
import type { AdminMedia } from '~/utils/admin-media'
import { FIGURE_WIDTHS, isFigureWidth } from '~~/shared/lib/sanitize/constants'

/**
 * Editor view of an image with caption: width control above, the photo, then caption and credit
 * fields. The alt text is not editable here: it comes from Media (a missing one is flagged).
 */
const props = defineProps<NodeViewProps>()
const id = useId()
const bleedOk = computed(() => canBleed(props.node.attrs.width as number | null, props.node.attrs.height as number | null))
const mode = computed(() => String(props.node.attrs.widthMode))

function setWidth(value: unknown) {
  if (isFigureWidth(value)) props.updateAttributes({ widthMode: value })
}
const pickerOpen = ref(false)
const mediaUrl = useMediaUrl()
/** Swaps the photo and keeps caption, credit and width (bleed falls back to wide if the new one is not landscape). */
function replaceImage(item: AdminMedia) {
  const keepBleed = mode.value !== 'bleed' || canBleed(item.width, item.height)
  props.updateAttributes({
    src: mediaUrl(item.storage_path),
    alt: item.alt_es ?? '',
    mediaId: item.id,
    width: item.width,
    height: item.height,
    ...(keepBleed ? {} : { widthMode: 'wide' }),
  })
}
const field = (name: 'caption' | 'credit', event: Event) => props.updateAttributes({ [name]: (event.target as HTMLInputElement).value })
</script>

<template>
  <NodeViewWrapper as="figure" contenteditable="false" class="group/fig my-6" :class="selected && 'rounded-md outline-2 outline-offset-4 outline-adm-acc'">
    <div class="mb-2 flex flex-wrap items-center gap-2 opacity-0 transition-opacity motion-reduce:transition-none group-focus-within/fig:opacity-100 group-hover/fig:opacity-100" :class="selected && 'opacity-100'">
      <span :id="`${id}-w`" class="text-xs text-adm-meta">Ancho</span>
      <RadioGroupRoot :model-value="mode" :aria-labelledby="`${id}-w`" orientation="horizontal" class="inline-flex gap-0.5 rounded-md border border-adm-line-strong bg-adm-elev p-0.5" :disabled="!editor.isEditable" @update:model-value="setWidth">
        <RadioGroupItem
          v-for="width in FIGURE_WIDTHS"
          :key="width"
          :value="width"
          :disabled="width === 'bleed' && !bleedOk"
          :title="width === 'bleed' && !bleedOk ? 'Solo fotos apaisadas de 1.600 px o más' : undefined"
          class="inline-flex h-7 items-center rounded px-2.5 text-[13px] font-medium text-adm-meta transition-colors motion-reduce:transition-none hover:bg-adm-subtle hover:text-adm-fg focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-adm-acc disabled:cursor-not-allowed disabled:opacity-45 data-[state=checked]:bg-adm-primary data-[state=checked]:text-adm-on-primary max-md:h-11 max-md:min-w-11"
        >
          {{ FIGURE_WIDTH_LABELS[width] }}
        </RadioGroupItem>
      </RadioGroupRoot>
      <button v-if="editor.isEditable" type="button" class="ml-auto inline-flex h-7 items-center rounded-md border border-adm-line-strong px-2.5 text-[13px] font-medium text-adm-fg hover:bg-adm-subtle focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-adm-acc max-md:h-11" @click="pickerOpen = true">Cambiar</button>
      <button v-if="editor.isEditable" type="button" :class="[admIconBtn]" aria-label="Quitar la imagen" @click="props.deleteNode()"><Trash2 aria-hidden="true" /></button>
    </div>
    <p v-if="!bleedOk" class="mb-2 text-xs text-adm-meta">«A sangre» desactivada: solo fotos apaisadas de 1.600 px o más.</p>
    <img :src="String(node.attrs.src)" :alt="String(node.attrs.alt ?? '')" data-drag-handle class="block h-auto w-full rounded-md" />
    <p v-if="!node.attrs.alt" class="mt-1 text-xs text-adm-warn-icon" role="note">Esta foto no tiene texto alternativo en Medios. Añádelo allí.</p>
    <div class="mt-2 grid gap-2 sm:grid-cols-[minmax(0,1fr)_200px]">
      <div>
        <label :for="`${id}-c`" class="mb-1 block text-xs font-medium text-adm-fg">Pie de foto</label>
        <input :id="`${id}-c`" :value="String(node.attrs.caption ?? '')" type="text" maxlength="200" :readonly="!editor.isEditable" :class="admInput" @input="field('caption', $event)" />
      </div>
      <div>
        <label :for="`${id}-k`" class="mb-1 block text-xs font-medium text-adm-fg">Crédito</label>
        <input :id="`${id}-k`" :value="String(node.attrs.credit ?? '')" type="text" maxlength="80" placeholder="Foto: nombre" :readonly="!editor.isEditable" :class="admInput" @input="field('credit', $event)" />
      </div>
    </div>
    <AdminMediaPicker v-model:open="pickerOpen" title="Cambiar imagen" @select="replaceImage" />
  </NodeViewWrapper>
</template>
