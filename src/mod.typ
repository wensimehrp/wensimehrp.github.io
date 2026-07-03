#let jeremy-gao = "Jeremy Gao"

#let html-renderer(c, page-key: none, ..args) = {
  let footnote-tracker = state("__footnote-tracker-" + page-key, ())
  show footnote: it => context {
    let ftn-len = footnote-tracker.get().len()
    let source-label = label(page-key + "-source-label-" + str(ftn-len))
    let target-label = label(page-key + "-target-label-" + str(ftn-len))
    [
      #super(link(target-label, str(ftn-len + 1))) #source-label
    ]
    footnote-tracker.update(arr => (
      arr
        + (
          (
            source: source-label,
            target: target-label,
            content: it.body,
          ),
        )
    ))
  }
  c
  context {
    let footnotes = footnote-tracker.final()
    if footnotes.len() == 0 { return }
    divider()
    let items = footnotes.map(ftn => enum.item[
      #ftn.content #ftn.target
      #html.span(class: "*:no-underline ml-4 hover:underline", link(ftn.source)[↑])
    ])
    enum(..items)
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
