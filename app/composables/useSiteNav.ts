import type { LocalizedRouteName } from '~~/i18n/localized-routes'

export interface NavItem {
  name: LocalizedRouteName
  label: string
  description?: string
}

/**
 * Public navigation: `menuItems` is the flat list of six (desktop nav and mobile menu, same order);
 * `guides` feeds the footer. A new guide category (ropes, harnesses…) is one more entry in both.
 */
export function useSiteNav() {
  const { t } = useI18n()
  const getRouteBaseName = useRouteBaseName()
  const route = useRoute()

  const guides = computed<NavItem[]>(() => [
    {
      name: 'climbing-gyms',
      label: t('nav.gyms'),
      description: t('nav.gymsDescriptionGeneric'),
    },
    {
      name: 'climbing-shoe-resoling',
      label: t('nav.resoling'),
      description: t('nav.resolingDescription'),
    },
    { name: 'climbing-shoes', label: t('nav.shoes'), description: t('nav.shoesDescription') },
  ])

  /** Flat list in display order, with the short labels of the mobile menu (D42). */
  const menuItems = computed<NavItem[]>(() => [
    { name: 'climbing-gyms', label: t('nav.gyms'), description: t('nav.gymsDescriptionGeneric') },
    { name: 'climbing-shoes', label: t('nav.shoes'), description: t('nav.shoesDescription') },
    {
      name: 'climbing-shoe-resoling',
      label: t('nav.menu.resolingShort'),
      description: t('nav.resolingDescription'),
    },
    { name: 'blog', label: t('nav.blog'), description: t('nav.menu.blogDescription') },
    { name: 'news', label: t('nav.news'), description: t('nav.menu.newsDescription') },
    { name: 'events', label: t('nav.events'), description: t('nav.menu.eventsDescription') },
  ])

  const currentName = computed(() => String(getRouteBaseName(route) ?? ''))

  /** 'page' on the exact page, 'true' inside its section (e.g. an article under Blog). */
  function ariaCurrent(name: string): 'page' | 'true' | undefined {
    if (currentName.value === name) return 'page'
    if (currentName.value.startsWith(`${name}-`)) return 'true'
    return undefined
  }

  return { guides, menuItems, ariaCurrent }
}
