/** Tells whether a horizontal scroller is scrolled away from its start/end (sticky-column edge shadows). */
export function useScrollEdges(el: Ref<HTMLElement | null | undefined>) {
  const fromStart = ref(false)
  const toEnd = ref(false)

  function update() {
    const node = el.value
    if (!node) return
    fromStart.value = node.scrollLeft > 1
    toEnd.value = node.scrollLeft + node.clientWidth < node.scrollWidth - 1
  }

  onMounted(() => {
    const node = el.value
    if (!node) return
    update()
    node.addEventListener('scroll', update, { passive: true })
    const observer = new ResizeObserver(update)
    observer.observe(node)
    if (node.firstElementChild) observer.observe(node.firstElementChild)
    onBeforeUnmount(() => {
      node.removeEventListener('scroll', update)
      observer.disconnect()
    })
  })

  return { fromStart, toEnd, update }
}
