#let jeremy-gao = "Jeremy Gao"

#let html-renderer(c, page-key: none, ..args) = {
  let footnote-tracker = state("__footnote-tracker-" + page-key, ())
  show footnote: it => context {
    let ftn-len = footnote-tracker.get().len()
    let source-label = label(page-key + "-source-label-" + str(ftn-len))
    let target-label = label(page-key + "-target-label-" + str(ftn-len))
    [
      #super({
        show html.elem.where(tag: "a"): set html.elem(attrs: (
          role: "doc-noteref",
          aria-describedby: "footnote-label",
          aria-label: "Footnote " + str(ftn-len + 1),
          class: "no-underline hover:underline",
        ))
        link(target-label, str(ftn-len + 1))
      }) #source-label
    ]
    let new-label = (
      source: source-label,
      target: target-label,
      content: it.body,
    )
    footnote-tracker.update(arr => arr + (new-label,))
  }
  c
  context {
    let footnotes = footnote-tracker.final()
    if footnotes.len() == 0 { return }
    html.aside(aria-labelledby: "footnote-label", {
      divider()
      html.h2(id: "footnote-label", class: "sr-only")[Footnotes]
      html.ol(for (idx, ftn) in footnotes.enumerate() [
        #html.li({
          ftn.content
          show html.elem.where(tag: "a"): set html.elem(attrs: (
            aria-label: "Back to reference " + str(idx + 1),
            role: "doc-backlink",
            class: "no-underline hover:underline ml-4 select-none",
          ))
          link(ftn.source)[↑]
        }) #ftn.target
      ])
    })
  }
}

#let pdf-renderer(c, page-key: none, ..args) = { c }

#let wstemplate(
  c,
  html-renderer: html-renderer,
  pdf-renderer: pdf-renderer,
  ..args,
) = metadata((
  html-renderer: html-renderer,
  ..args.named(),
  content: c,
))

#let elink(..args) = link(..args)
