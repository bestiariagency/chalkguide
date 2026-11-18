/** Id of the section (of `ids`) that is currently at the top of the viewport; drives the sticky index. */
export function useAdminSectionSpy(ids: readonly string[]) {
  const current = ref(ids[0] ?? '')
  function update() {
    let found = ids[0] ?? ''
    for (const id of ids) {
      const el = document.getElementById(id)
      if (el && el.getBoundingClientRect().top < 120) found = id
    }
    current.value = found
  }
  onMounted(() => {
    window.addEventListener('scroll', update, { passive: true })
    update()
  })
  onBeforeUnmount(() => window.removeEventListener('scroll', update))
  return current
}
