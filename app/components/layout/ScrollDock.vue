<script setup lang="ts">
/**
 * Scroll dock (D43, adjusted by D45): one orange piece. The isotype always links home; from lg the word
 * Newsletter next to it links to #newsletter (or the newsletter page). Below lg only the isotype,
 * top left; the way to the letter is the menu and the closing block. Appears once the masthead is out of view.
 * From lg, while the bar is hidden it sits top centre with a soft shadow; while the bar is visible
 * it slides to the page's left edge (the bar's empty column) without shadow. Left/translate/scale
 * transitions with overshoot as in docs/design/site/pages/home-nav-desktop.html; reduced motion:
 * no travel. Hidden while the mobile menu is open, from the moment #newsletter reaches the screen
 * (and through the footer), and on /newsletter*, where it would link to the page you are on.
 * D51: below lg it also steps aside while scrolling down inside an article body.
 */
const props = defineProps<{ visible: boolean; barVisible: boolean }>()
const { t } = useI18n()
const route = useRoute()
const getBaseName = useRouteBaseName()
const { isOpen: menuOpen } = useMobileMenu()
const reachedNewsletter = useNewsletterReached()
const onNewsletterPage = computed(() => String(getBaseName(route) ?? '').startsWith('newsletter'))
// D51: on small screens an article body hides it while scrolling down (see useDockReadingHide).
const hiddenForReading = useDockHiddenForReading()
const on = computed(
  () =>
    props.visible &&
    !menuOpen.value &&
    !reachedNewsletter.value &&
    !onNewsletterPage.value &&
    !hiddenForReading.value,
)
// Same rule as MobileMenu: the #newsletter block when the page has it, else the newsletter page.
const showNewsletterBlock = computed(() => route.meta.newsletterBlock !== false)

// Literal strings: Tailwind only generates classes it can read in the source.
// Off: above its place, a bit smaller, unreachable (visibility waits for the fade-out). Below lg it
// already sits on the left edge, so it never travels from the centre.
const OFF =
  'invisible left-1/2 -translate-x-1/2 -translate-y-[18px] scale-[.92] opacity-0 max-lg:left-4 md:max-lg:left-6 max-lg:translate-x-0 [transition:left_620ms_cubic-bezier(.3,1.28,.5,1),translate_620ms_cubic-bezier(.3,1.28,.5,1),scale_620ms_cubic-bezier(.3,1.28,.5,1),box-shadow_300ms,opacity_220ms,visibility_0s_linear_220ms]'
// On, bar hidden: top centre with a soft shadow.
const ON =
  'data-[on]:visible data-[on]:translate-y-0 data-[on]:scale-100 data-[on]:opacity-100 data-[on]:shadow-[0_8px_24px_-10px_rgb(0_0_0/.55)] data-[on]:[transition:left_620ms_cubic-bezier(.3,1.28,.5,1),translate_620ms_cubic-bezier(.3,1.28,.5,1),scale_620ms_cubic-bezier(.3,1.28,.5,1),box-shadow_300ms,opacity_220ms,visibility_0s]'
// On, bar visible: slides to the page's left edge (container padding included), no shadow.
const BESIDE_BAR =
  'data-[on]:data-[bar]:left-[max(1rem,calc(50%-var(--container-page)/2+1rem))] md:data-[on]:data-[bar]:left-[max(1.5rem,calc(50%-var(--container-page)/2+1.5rem))] data-[on]:data-[bar]:translate-x-0 data-[on]:data-[bar]:shadow-none'
// Below lg the dock stays on the left edge whatever the bar does.
const COMPACT = 'max-lg:data-[on]:left-4 md:max-lg:data-[on]:left-6 max-lg:data-[on]:translate-x-0'
const REDUCED =
  'motion-reduce:[transition:opacity_100ms,visibility_0s] motion-reduce:data-[on]:[transition:opacity_100ms,visibility_0s]'
// 44 px touch target around the 40 px piece: the hit area grows, not the piece.
const HIT = 'relative after:absolute after:-inset-0.5 after:content-[""]'
const WORD = 'h-10 items-center rounded-[11px] pr-4 text-body-sm font-medium whitespace-nowrap max-lg:hidden lg:flex'
</script>

<template>
  <div
    class="fixed top-2 z-[41] h-10 rounded-[11px]"
    :class="[OFF, ON, BESIDE_BAR, COMPACT, REDUCED]"
    :data-on="on || undefined"
    :data-bar="barVisible || undefined"
    :inert="!on || undefined"
  >
    <!-- Own element: the hover scale must not inherit the root's 620 ms overshoot. -->
    <div
      class="chrome-dark flex h-10 rounded-[11px] bg-accent-fill text-white transition-transform duration-200 ease-out motion-safe:hover:scale-[1.04]"
    >
      <NuxtLinkLocale to="/" :aria-label="t('brand.homeLabel')" class="block size-10 shrink-0 rounded-[11px]" :class="HIT">
        <img src="/brand/iso-chalk-white.svg" alt="" width="40" height="40" class="block size-full" />
      </NuxtLinkLocale>
      <a v-if="showNewsletterBlock" href="#newsletter" :aria-label="t('newsletter.goTo')" :class="[WORD, HIT]">
        {{ t('nav.newsletter') }}
      </a>
      <NuxtLinkLocale v-else :to="{ name: 'newsletter' }" :aria-label="t('newsletter.goTo')" :class="[WORD, HIT]">
        {{ t('nav.newsletter') }}
      </NuxtLinkLocale>
    </div>
  </div>
</template>
