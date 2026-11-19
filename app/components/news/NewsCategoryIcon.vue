<script setup lang="ts">
import { Landmark, Leaf, Mountain, Newspaper, Shield, Trophy, Users } from 'lucide-vue-next'
import type { Component } from 'vue'
import IconClimbingShoe from '~/components/ui/IconClimbingShoe.vue'
import IconHold from '~/components/ui/IconHold.vue'
import type { NewsCategoryKey } from '~/utils/news-categories'

/**
 * Stroke icon of a news category (README §18.14). Always decorative: it sits next to the written name, so it carries
 * `aria-hidden` and no title. The colour is inherited (`currentColor`).
 */
const props = withDefaults(defineProps<{ slug: string | null | undefined; size?: number | string; strokeWidth?: number | string }>(), {
  size: 16,
  strokeWidth: 1.75,
})
const ICONS: Record<NewsCategoryKey, Component> = {
  competicion: Trophy,
  'roca-vias': Mountain,
  material: IconClimbingShoe,
  rocodromos: IconHold,
  seguridad: Shield,
  'acceso-entorno': Leaf,
  federaciones: Landmark,
  comunidad: Users,
  none: Newspaper,
}
const icon = computed(() => ICONS[newsCategoryKey(props.slug)])
</script>

<template>
  <component :is="icon" :size="size" :stroke-width="strokeWidth" aria-hidden="true" focusable="false" class="shrink-0" />
</template>
