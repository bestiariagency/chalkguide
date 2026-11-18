<script setup lang="ts">
import { CircleAlert, Lock } from 'lucide-vue-next'

/**
 * /newsletter/preferencias (D66, README §14.4). Reached from the "Preferences" link of every
 * email with `?t=<token>`; no login. `ssr: false` (routeRules) so the token never goes through
 * the server render; the client reads it, removes it from the URL and never paints it.
 */
definePageMeta({ newsletterBlock: false })

const { t } = useI18n()
const { linkFor } = usePageLinks()
const { data: settings } = await useSiteSettings()
const { status, prefs, busy, flash, load, grantRelated, withdrawRelated, leaveNewsletter } =
  useConsentPreferences()

// The token may leave in the Referer of any link: the header (routeRules) does it, this repeats it.
useHead({ meta: [{ name: 'referrer', content: 'no-referrer' }] })

const title = computed(() => t(status.value === 'invalid' ? 'consent.prefs.invalidTitle' : 'consent.prefs.title'))
usePageSeo(() => ({ title: t('consent.prefs.seoTitle'), robots: 'noindex, nofollow' }))

const newsletterTone = { active: 'on', pending: 'wait', inactive: 'off' } as const
const relatedTone = { granted: 'on', pending: 'wait', none: 'off' } as const
const relatedText = computed(() => settings.value?.relatedConsentText ?? null)
const flashFor = (row: 'newsletter' | 'related') => (flash.value?.row === row ? flash.value : null)
</script>

<template>
  <PagePlaceholder display :title="title" :seo="false" :crumbs="[{ label: t('consent.prefs.title') }]">
    <div v-if="status === 'invalid'" role="status" class="mt-6 max-w-[720px]">
      <p class="max-w-[56ch] text-lead text-meta">{{ t('consent.prefs.invalidBody') }}</p>
      <div class="mt-8 flex flex-col gap-3 sm:flex-row">
        <UiButton :to="{ name: 'newsletter' }" variant="ghost">{{ t('consent.prefs.toNewsletter') }}</UiButton>
        <UiButton to="/" variant="ghost">{{ t('consent.prefs.toHome') }}</UiButton>
      </div>
    </div>
    <div v-else class="max-w-[820px]">
      <p class="mt-6 max-w-[56ch] text-lead text-meta">{{ t('consent.prefs.lead') }}</p>
      <p class="mt-3 text-note text-meta">{{ t('consent.prefs.noLogin') }}</p>

      <ul v-if="status === 'loading'" class="mt-10 space-y-5" aria-busy="true" :aria-label="t('consent.prefs.loading')">
        <li v-for="n in 2" :key="n" class="slab grid gap-4 bg-board p-5 md:grid-cols-[minmax(0,1fr)_auto] md:gap-6 md:p-7">
          <div>
            <UiSkeleton class="h-6 w-48" />
            <UiSkeleton class="mt-3 h-4 w-full max-w-[420px]" />
            <UiSkeleton class="mt-2 h-4 w-2/3 max-w-[300px]" />
          </div>
          <UiSkeleton class="h-11 w-full md:w-36" />
        </li>
      </ul>

      <div v-else-if="status === 'error'" role="alert" class="slab mt-10 bg-board p-5 md:p-7">
        <p class="flex items-start gap-1.5 text-body-lg text-danger-text">
          <CircleAlert :size="16" aria-hidden="true" class="mt-1.5 shrink-0" />
          <span>{{ t('consent.prefs.loadError') }}</span>
        </p>
        <UiButton variant="ghost" class="mt-5" @click="load">{{ t('common.retry') }}</UiButton>
      </div>

      <template v-else-if="prefs">
        <ul class="mt-10 space-y-5">
          <NewsletterPrefRow
            :title="t('consent.prefs.newsletter.title')"
            :tone="newsletterTone[prefs.newsletter]"
            :state-label="t(`consent.prefs.state.newsletter${prefs.newsletter === 'active' ? 'Active' : prefs.newsletter === 'pending' ? 'Pending' : 'Inactive'}`)"
            :flash="flashFor('newsletter')"
          >
            <template #body>{{ t(`consent.prefs.newsletter.${prefs.newsletter}Body`) }}</template>
            <template #action>
              <UiButton v-if="prefs.newsletter === 'inactive'" :to="{ name: 'newsletter' }" variant="ghost" class="w-full md:w-auto">
                {{ t('consent.prefs.newsletter.again') }}
              </UiButton>
              <UiButton
                v-else
                variant="ghost"
                class="w-full md:w-auto"
                :loading="busy === 'newsletter-off'"
                :disabled="!!busy && busy !== 'newsletter-off'"
                @click="leaveNewsletter"
              >
                {{ t(prefs.newsletter === 'pending' ? 'consent.prefs.newsletter.cancel' : 'consent.prefs.newsletter.leave') }}
              </UiButton>
            </template>
          </NewsletterPrefRow>

          <NewsletterPrefRow
            :title="t('consent.prefs.related.title')"
            :tone="relatedTone[prefs.related]"
            :state-label="t(`consent.prefs.state.related${prefs.related === 'granted' ? 'Granted' : prefs.related === 'pending' ? 'Pending' : 'None'}`)"
            :flash="flashFor('related')"
          >
            <template #body>
              <template v-if="prefs.related === 'granted'">{{ t('consent.prefs.related.grantedBody') }}</template>
              <template v-else-if="prefs.related === 'pending'">{{ t('consent.prefs.related.pendingBody') }}</template>
              <template v-else-if="prefs.canGrantRelated && relatedText">{{ t('consent.prefs.related.offerBody') }}</template>
              <template v-else-if="prefs.canGrantRelated">{{ t('consent.prefs.related.unavailableBody') }}</template>
              <template v-else>{{ t('consent.prefs.related.unconfirmedBody') }}</template>
            </template>
            <p
              v-if="prefs.related === 'none' && prefs.canGrantRelated && relatedText"
              id="related-pref-text"
              class="mt-3 max-w-[60ch] text-[17px] leading-normal"
              :lang="settings?.relatedConsentLocale"
            >
              «{{ relatedText }}»
            </p>
            <p
              v-else-if="prefs.related === 'none' && !prefs.canGrantRelated"
              id="related-pref-why"
              class="mt-3 flex items-start gap-1.5 text-body-sm text-meta"
            >
              <Lock :size="16" aria-hidden="true" class="mt-0.5 shrink-0" />
              <span>{{ t('consent.prefs.related.locked') }}</span>
            </p>
            <NewsletterConsentInfo />
            <template #action>
              <UiButton
                v-if="prefs.related !== 'none'"
                variant="ghost"
                class="w-full md:w-auto"
                :loading="busy === 'related-off'"
                :disabled="!!busy && busy !== 'related-off'"
                @click="withdrawRelated"
              >
                {{ t('consent.prefs.related.withdraw') }}
              </UiButton>
              <UiButton
                v-else
                variant="ghost"
                class="w-full md:w-auto"
                :aria-describedby="prefs.canGrantRelated ? (relatedText ? 'related-pref-text' : undefined) : 'related-pref-why'"
                :loading="busy === 'related-on'"
                :disabled="!prefs.canGrantRelated || !relatedText || (!!busy && busy !== 'related-on')"
                @click="grantRelated"
              >
                {{ t('consent.prefs.related.grant') }}
              </UiButton>
            </template>
          </NewsletterPrefRow>
        </ul>
        <p class="mt-8 max-w-[60ch] text-note text-meta">
          {{ t('consent.prefs.footer') }}
          <UiTextLink :to="{ name: 'privacy' }" v-bind="linkFor('privacy')">{{ t('newsletter.privacyLink') }}</UiTextLink>.
        </p>
      </template>
    </div>
  </PagePlaceholder>
</template>
