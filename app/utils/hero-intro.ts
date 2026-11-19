/** Cookie with the grid/list choice of /noticias (set only when the person presses the switch). */
export const NEWS_VIEW_COOKIE = 'cg_news_view'

/** sessionStorage flag of the home intro; also read by the inline head script (nuxt.config.ts). */
export const HERO_INTRO_KEY = 'cg-hero-intro'

/** Attribute useHeroIntro sets on <html> once it has taken over the intro (read by the head script). */
export const HERO_INTRO_MOUNTED_ATTR = 'data-intro-mounted'
/** Without hydration (blocked or failed chunks) the intro gives up after this long. */
export const HERO_INTRO_FAILSAFE_MS = 3000

/**
 * Inline head script (nuxt.config.ts): marks `js`, copies the /noticias view cookie to `data-news-view`, decides the intro before first paint (home only,
 * once per session, never with reduced motion) and, until the app takes over, covers two cases the
 * Vue code cannot: a failsafe that removes `has-intro` after 3 s if hydration never happened, and the
 * skip gesture (pointer / key) working before hydration.
 */
export function heroIntroHeadScript(): string {
  return (
    `(function(){var d=document.documentElement;d.classList.add('js');try{` +
    // /noticias view (§18.6): the cookie becomes an attribute on <html> before paint; the CSS knows both forms.
    `var m=document.cookie.match(/(?:^|; )${NEWS_VIEW_COOKIE}=(grid|list)(?:;|$)/);if(m)d.setAttribute('data-news-view',m[1]);` +
    `if(!matchMedia('(prefers-reduced-motion: reduce)').matches&&/^\\/(en\\/?)?$/.test(location.pathname)&&!sessionStorage.getItem('${HERO_INTRO_KEY}')){` +
    `d.classList.add('has-intro');` +
    `var skip=function(){if(d.hasAttribute('${HERO_INTRO_MOUNTED_ATTR}'))return;` +
    `d.classList.remove('has-intro');try{sessionStorage.setItem('${HERO_INTRO_KEY}','1')}catch(e){}};` +
    `addEventListener('pointerdown',skip,{once:true});addEventListener('keydown',skip,{once:true});` +
    `setTimeout(function(){if(!d.hasAttribute('${HERO_INTRO_MOUNTED_ATTR}'))d.classList.remove('has-intro')},${HERO_INTRO_FAILSAFE_MS})` +
    `}}catch(e){}})()`
  )
}
