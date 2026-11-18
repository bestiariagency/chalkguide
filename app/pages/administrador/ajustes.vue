<script setup lang="ts">
/**
 * Settings (F6.17, docs/design/admin/ajustes.html): General, SEO por defecto, Redes y contacto,
 * Newsletter, Opiniones and Tu cuenta. Saved at once (no draft) from the "cambios sin guardar" bar.
 * Autor del sitio (D62): photo, texts and «En números» of the site author; the other authors live in Editorial › Autores.
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Ajustes')

const settings = useAdminSettings()
const { form, loaded, og, authorPhoto, errors, changed, busy, conflict, theirs } = settings
const loading = computed(() => settings.data.status.value === 'pending' && !loaded.value)
const showSkeleton = useDelayedFlag(loading, 300)
const failed = computed(() => !!settings.data.error.value && !loaded.value)

const SECTIONS = [
  { id: 'general', label: 'General' },
  { id: 'autor', label: 'Autor del sitio' },
  { id: 'seo', label: 'SEO por defecto' },
  { id: 'redes', label: 'Redes y contacto' },
  { id: 'newsletter', label: 'Newsletter' },
  { id: 'opiniones', label: 'Opiniones' },
  { id: 'cuenta', label: 'Tu cuenta' },
]
const current = useAdminSectionSpy(SECTIONS.map((s) => s.id))
</script>

<template>
  <div>
    <AdminPageBar title="Ajustes" />

    <div class="gap-10 px-4 py-6 pb-32 md:px-6 lg:grid lg:grid-cols-[180px_minmax(0,760px)]">
      <AdminSettingsNav :sections="SECTIONS" :current="current" />
      <div class="min-w-0 space-y-10">
        <AdminSettingsConflict v-if="conflict" :sections="conflict" :theirs="theirs" :busy="busy" :view="settings.viewTheirs" @mine="settings.keepMine()" />

        <AdminStateBlock v-if="failed" kind="error" @retry="settings.reload()" />
        <AdminSettingsSkeleton v-else-if="loading || !form || !loaded" :visible="showSkeleton" />
        <template v-else>
          <AdminSettingsGeneral v-model:form="form" :errors="errors" :changed="changed" />
          <AdminSettingsAuthor
            v-model:form="form"
            :errors="errors"
            :changed="changed"
            :photo="authorPhoto"
            :calc="loaded.calc"
            @pick="settings.selectAuthorPhoto"
            @add-stat="settings.addStat()"
            @remove-stat="settings.removeStat($event)"
          />
          <AdminSettingsSeo v-model:form="form" :errors="errors" :changed="changed" :og="og" @pick="settings.selectOg" />
          <AdminSettingsSocial v-model:form="form" :errors="errors" :changed="changed" />
          <AdminSettingsNewsletter
            v-model:form="form"
            :errors="errors"
            :changed="changed"
            :version="loaded.consent.version"
            :since="loaded.consent.validFrom"
            :consent-changed="settings.consentChanged.value"
          />
          <AdminSettingsReviews v-model:form="form" :errors="errors" :changed="changed" />
        </template>
        <AdminSettingsAccount />
      </div>
    </div>

    <AdminSettingsSaveBar v-if="settings.dirty.value" :count="changed.length" :busy="busy" @save="settings.save()" @discard="settings.discard()" />
  </div>
</template>
