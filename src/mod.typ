#let jeremy-gao = "Jeremy Gao"

#let html-renderer(c, ..args) = { c }
#let pdf-renderer(c, ..args) = { c }

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
#let footnote(c) = []
