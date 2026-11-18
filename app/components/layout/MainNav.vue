<script setup lang="ts">
/**
 * Desktop navigation: seven flat links, an orange line that follows the hovered link (and rests on
 * the current section or, on the home, the section in view) and a preview card on hover/focus.
 * `useNavSpring` drives the line and the card; the links stay the accessible route.
 */
const props = withDefaults(
  defineProps<{
    /** The compact bar sits tighter and has the line closer to the edge. */
    compact?: boolean
    /** Route name of the home section in view (compact bar only). */
    spy?: string | null
  }>(),
  { compact: false, spy: null },
)

const { menuItems, ariaCurrent } = useSiteNav()
const { cards, load } = useNavPreview()
const root = ref<HTMLElement | null>(null)
const spyIndex = computed(() => {
  const index = props.spy ? menuItems.value.findIndex((item) => item.name === props.spy) : -1
  return index < 0 ? null : index
})
useNavSpring(root, { spy: spyIndex, cards, onUse: load })
</script>

<template>
  <div ref="root" class="relative">
    <ul class="flex gap-5 xl:gap-8 text-body-sm">
      <li v-for="(item, i) in menuItems" :key="item.name">
        <NuxtLinkLocale
          :to="{ name: item.name }"
          :aria-current="ariaCurrent(item.name)"
          :data-nav-link="item.name"
          :data-spy="spyIndex === i || undefined"
          class="relative block px-0.5 whitespace-nowrap after:absolute after:inset-x-[-5px] after:inset-y-[-4px] text-prose transition-colors duration-[180ms] not-aria-[current]:hover:text-white aria-[current]:text-accent not-aria-[current]:data-[near]:text-white not-aria-[current]:data-[spy]:text-white"
          :class="compact ? 'pt-1.5 pb-[9px]' : 'pt-2.5 pb-3'"
        >
          {{ item.label }}
        </NuxtLinkLocale>
      </li>
    </ul>
    <i
      data-nav-ind
      aria-hidden="true"
      class="pointer-events-none absolute left-0 h-0.5 w-[100px] origin-left rounded-[1px] bg-accent opacity-0 transition-opacity duration-200 data-[on]:opacity-100"
      :class="compact ? 'bottom-px' : 'bottom-1'"
    />
    <LayoutNavPreviewCard :cards="cards" />
  </div>
</template>
