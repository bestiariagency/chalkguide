<script setup lang="ts">
/**
 * Mobile menu (D42, §19.6 of docs/design/site/README.md): four dark pills rise, the items fade
 * and slide in, and the hero's rope runs down the left margin to the current section. Only
 * opacity and transform animate (compositor, no repaint or layout per frame). Below `lg` only;
 * the pages behind it are inert (see layouts/default.vue).
 */
const { t } = useI18n()
const route = useRoute()
const { isOpen, close } = useMobileMenu()
const { menuItems, ariaCurrent } = useSiteNav()

const panel = ref<HTMLElement | null>(null)
const nav = ref<HTMLElement | null>(null)
useSheetBehaviour(isOpen, panel, '[aria-controls="mobile-menu"]')
useCloseAtDesktop(isOpen)

// No current section (home): the rope rests on the first item, which is orange without aria-current.
const restIndex = computed(() =>
  Math.max(
    0,
    menuItems.value.findIndex((i) => ariaCurrent(i.name)),
  ),
)
const rope = useMenuRope({ isOpen, nav, restIndex, close })

// Focus goes to the close button, after useSheetBehaviour's own first-control focus (60 ms).
const AUTOFOCUS_DELAY_MS = 90
watch(isOpen, (open) => {
  if (open)
    setTimeout(
      () => panel.value?.querySelector<HTMLElement>('[data-autofocus]')?.focus(),
      AUTOFOCUS_DELAY_MS,
    )
})

const showNewsletterBlock = computed(() => route.meta.newsletterBlock !== false)
// Each pill starts a little later than the previous one, as in the mock.
const PILL_DELAYS = [
  'group-data-[open=true]:delay-[25ms]',
  'group-data-[open=true]:delay-0',
  'group-data-[open=true]:delay-[45ms]',
  'group-data-[open=true]:delay-[70ms]',
]
</script>

<template>
  <div
    id="mobile-menu"
    role="dialog"
    aria-modal="true"
    :aria-label="t('nav.menu.label')"
    class="chrome-dark group invisible fixed inset-0 z-50 overflow-hidden bg-transparent text-white transition-[visibility] delay-[320ms] duration-0 data-[open=true]:visible data-[open=true]:delay-0"
    :data-open="isOpen"
  >
    <div class="pointer-events-none absolute inset-0 grid grid-cols-4" aria-hidden="true">
      <i
        v-for="(delay, n) in PILL_DELAYS"
        :key="n"
        class="-mx-px block h-[128%] translate-y-full rounded-t-[12.5vw] bg-background transition-transform duration-[220ms] ease-[cubic-bezier(0.5,0,0.9,0.4)] group-data-[open=true]:-translate-y-[14%] group-data-[open=true]:duration-[380ms] group-data-[open=true]:ease-out motion-reduce:transition-none motion-reduce:group-data-[open=true]:transition-none"
        :class="delay"
      />
    </div>

    <div ref="panel" class="relative flex h-full flex-col">
      <div
        class="flex h-[calc(4rem+env(safe-area-inset-top))] flex-none items-center justify-between pt-[env(safe-area-inset-top)] pr-[max(16px,env(safe-area-inset-right))] pl-[max(16px,env(safe-area-inset-left))] opacity-0 transition-opacity duration-[120ms] group-data-[open=true]:opacity-100 group-data-[open=true]:delay-[120ms] group-data-[open=true]:duration-[180ms] motion-reduce:transition-none"
      >
        <NuxtLinkLocale
          to="/"
          :aria-label="t('brand.homeLabel')"
          class="flex min-h-11 items-center"
          @click="close"
        >
          <img
            src="/brand/logo-white.svg"
            alt=""
            width="2073"
            height="384"
            class="block h-[22px] w-auto"
          />
        </NuxtLinkLocale>
        <LayoutBurger data-autofocus :open="isOpen" :label="t('nav.menu.close')" @click="close" />
      </div>

      <nav
        ref="nav"
        :aria-label="t('nav.mainMobile')"
        class="relative flex min-h-0 flex-auto overflow-y-auto overscroll-contain py-2 pr-[max(16px,env(safe-area-inset-right))] pl-[calc(52px+env(safe-area-inset-left))]"
        @pointerleave="rope.rest"
        @scroll.passive="rope.measure"
      >
        <!-- CSS fallback: the braid is hero.css's gradient. The rail has a fixed height; the cord scales
             (scaleY, FLIP in useMenuRope) and the carabiner translates to the measured --y. -->
        <div
          aria-hidden="true"
          class="pointer-events-none absolute top-0 left-[calc(26px+env(safe-area-inset-left))] h-full w-0"
          :style="{ '--y': `${rope.y.value}px` }"
        >
          <i
            data-menu-cord
            class="hero-rope-cord absolute top-0 -left-0.5 block h-[calc(var(--y)-18px)] w-1 origin-top scale-y-0 rounded-xs transition-none group-data-[open=true]:scale-y-100 group-data-[open=true]:transition-transform group-data-[open=true]:delay-100 group-data-[open=true]:duration-[280ms] group-data-[open=true]:ease-out motion-reduce:scale-y-100 motion-reduce:transition-none motion-reduce:group-data-[open=true]:transition-none"
          />
          <svg
            viewBox="0 0 44 64"
            fill="none"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="absolute top-0 -left-[15px] h-11 w-[30px] translate-y-[calc(var(--y)-22px)] text-accent opacity-0 group-data-[open=true]:opacity-100 group-data-[open=true]:transition-[opacity,translate] group-data-[open=true]:delay-[250ms,0ms] group-data-[open=true]:duration-[150ms,280ms] group-data-[open=true]:ease-out motion-reduce:group-data-[open=true]:transition-none"
          >
            <path
              stroke="currentColor"
              stroke-width="3.8"
              d="M18 6h7c9 0 14 7 13 15l-3 28c-1 6-6 10-12 10h-3c-6 0-11-5-11-11V15c0-5 4-9 9-9Z"
            />
            <path stroke="var(--color-rope-shade)" stroke-width="3.8" d="m38 21-3 28" />
          </svg>
        </div>

        <ul class="my-auto grid w-full list-none gap-[clamp(8px,2.1svh,20px)] p-0">
          <li
            v-for="(item, i) in menuItems"
            :key="item.name"
            :style="{ '--i': i }"
            class="translate-y-3 opacity-0 transition-opacity duration-[120ms] group-data-[open=true]:translate-y-0 group-data-[open=true]:opacity-100 group-data-[open=true]:transition-[opacity,translate] group-data-[open=true]:duration-[200ms,260ms] group-data-[open=true]:ease-out group-data-[open=true]:delay-[calc(120ms+var(--i)*30ms)] motion-reduce:translate-y-0 motion-reduce:opacity-100 motion-reduce:group-data-[open=true]:transition-none"
          >
            <NuxtLinkLocale
              :to="{ name: item.name }"
              :aria-current="ariaCurrent(item.name)"
              data-menu-link
              :data-clipped="rope.clipped.value === i"
              class="group/link block rounded-xs py-1"
              @pointerenter="rope.clipTo(i)"
              @focus="rope.clipTo(i)"
              @click="rope.onLinkClick($event, i)"
            >
              <b
                class="block font-display text-[clamp(25px,8vw,46px)]/[1.04] font-bold tracking-[-0.02em] uppercase font-stretch-expanded transition-colors duration-200 group-data-[clipped=true]/link:text-accent"
              >
                {{ item.label }}
              </b>
              <span class="mt-[3px] block text-[15px]/[1.35] text-meta">{{
                item.description
              }}</span>
            </NuxtLinkLocale>
          </li>
        </ul>
      </nav>

      <div
        class="flex flex-none flex-wrap items-center justify-between gap-x-4 pt-2 pr-[max(16px,env(safe-area-inset-right))] pb-[calc(14px+env(safe-area-inset-bottom))] pl-[max(16px,env(safe-area-inset-left))] opacity-0 transition-opacity duration-[120ms] group-data-[open=true]:opacity-100 group-data-[open=true]:delay-[280ms] group-data-[open=true]:duration-200 motion-reduce:transition-none"
      >
        <a
          v-if="showNewsletterBlock"
          href="#newsletter"
          class="inline-flex min-h-11 items-center text-body text-white"
          @click="close"
        >
          <span class="link-underline">{{ t('nav.newsletter') }}</span>
        </a>
        <NuxtLinkLocale
          v-else
          :to="{ name: 'newsletter' }"
          class="inline-flex min-h-11 items-center text-body text-white"
        >
          <span class="link-underline">{{ t('nav.newsletter') }}</span>
        </NuxtLinkLocale>
        <LayoutLanguageSwitcher size="md" />
        <div class="basis-full">
          <LayoutSignOutButton class="-ml-2" />
        </div>
      </div>
    </div>
  </div>
</template>
