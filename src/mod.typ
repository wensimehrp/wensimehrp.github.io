#let jeremy-gao = "Jeremy Gao"

#let html-renderer(c, page-key: none, ..args) = {
  let page-key = if page-key == none { args.title } else { page-key }
  let footnote-tracker = state("__footnote-tracker-" + page-key, ())
  show footnote: it => context {
    let ftn-len = footnote-tracker.get().len()
    let source-label = label(page-key + "-source-label-" + str(ftn-len))
    let target-label = label(page-key + "-target-label-" + str(ftn-len))
    [
      #html.sup(class: "target:animate-[inline-flash_1s_ease-out_forwards] rounded-sm", {
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
  // phew; the main part
  html.header(class: "mb-5", {
    title(args.title)
    html.div(class: "flex gap-2", {
      html.address(class: "author", args.author)
      html.span(class: "select-none")[·]
      html.time(
        datetime: args.created,
        args.created.display("[month repr:short]. [day], [year]"),
      )
    })
  })
  c
  // now back to footnotes
  context {
    let footnotes = footnote-tracker.final()
    if footnotes.len() == 0 { return }
    html.section(aria-labelledby: "footnote-label", {
      divider()
      html.h2(id: "footnote-label", class: "sr-only")[Footnotes]
      html.ol(class: "[&>li]:target:animate-[inline-flash_1s_ease-out_forwards] [&>li]:rounded-sm", for (
        idx,
        ftn,
      ) in footnotes.enumerate() [
        #html.li({
          {
            show html.elem.where(tag: "a"): set html.elem(attrs: (
              aria-label: "Back to reference " + str(idx + 1),
              role: "doc-backlink",
              class: "no-underline hover:underline mr-4",
              style: "user-select: none; margin-right: 0.25rem",
            ))
            link(ftn.source)[↑]
          }
          [ ]
          ftn.content
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
  html-renderer: html-renderer.with(..args),
  ..args.named(),
  content: c,
))

#let elink(..args) = link(..args)

#let LaTeX = html.span[
  L
  #html.span(
    class: "font-semibold",
    style: (
      font-size: "0.75em",
      vertical-align: "0.25em",
      margin-left: "-0.7em",
      margin-right: "-0.4em",
      line-height: "1ex",
      text-transform: "uppercase",
    )
      .pairs()
      .map(((k, v)) => k + ": " + v)
      .join(";"),
  )[a]
  T
  #html.span(
    style: (
      vertical-align: "-0.25em",
      margin-left: "-0.4em",
      margin-right: "-0.25em",
      line-height: "1ex",
      text-transform: "uppercase",
    )
      .pairs()
      .map(((k, v)) => k + ": " + v)
      .join(";"),
  )[e]
  X
]
