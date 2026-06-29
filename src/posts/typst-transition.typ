#import "../mod.typ": *
#show: wstemplate.with(
  layout: "layout.webc",
  title: "Transitioning to Typst",
  description: "Hey, are you one of the Typst dudes?",
  created: datetime(year: 2025, month: 09, day: 09),
  tags: ("Typst", "tools", "typesetting"),
  author: "Jeremy Gao",
)

I've been using typst for a while, even using it to generate my blog site (as you can see). It is a great tool, with a
typesetting quality that rivals LaTeX -- I cannot say if it is doing better than LaTeX, since I am never a LaTeXer, nor
do I think I will in the near future when I am (hopefully) in Uni. It's got scripting capabilities that are even better
than python's -- from a personal perspective, of course.#footnote[
  And look at this amazing footnote in typst! Eleventy already features a powerful markdown compiler that translate all
  of markdown's components to html. Typst, on the other hand, does not have that luxury, which means that I would have
  to manually create the mappings from typst elements (or I should say basic typesetting elements) to HTML elements.
  This footnote is created using a custom footnote mapper.
]

So the decision is to rewrite (at least some parts of) this site using Typst. Typst supports exporting HTML, as well as
rendering parts of the documents in SVG (via `html.frame`). Exporting to HTML is only a experimental feature, but it is
somewhat mature now for productive use. #footnote[From the *official* Typst documentation: _Typst's HTML export is
  currently under active development. The feature is still very incomplete and only available for experimentation behind
  a feature flag. Do not use this feature for production use cases._] People like Camiyori#footnote[AKA
  "Myriad-Dreamin"] and OverflowCat already created exciting services such as typst.ts, and astro-typst. Uwni's also
created their own blog with typst using their own extension. In fact, I was inspired by Uwni's blog, and I used the same
eleventy build system they used in their blog.

= Building the Blog

If you know me on X or other places, you'll probably notice that I have several posts about building blog sites, ranging
from simply shouting out the desire to build one to what contents to post on the site. So here it is.

This site (as you've probably already seen in the "about" page) is built using these stuff:

- Eleventy, for static stie generation, or SSG for short
- Tailwindcss for some styling
- Pagefind search utility
- WebC components for meta styling.

One feature of Typst is its fast compilation, and the near-instant preview that comes with this fast compilation. I
cannot make use of the preview feature provided by tinymist, but it is a rather small problem, as I basically have the
dev server running in the background when I am writing stuff.

In spite of typst html export being pretty useable at this state of development, it still lacks a bunch of features,
like footnotes and linking to labels (like `#link(<some-label>)`). Those could be, however, achieved by writing custom
counters and html elements. For example, this is the code of my custom implementation of the footnote system:

```typ
#let fn-state = state("fn", (1, ()))
#let footnote(c) = context {
  let n = fn-state.get().at(0)
  let href = "#fn" + str(n)
  let id = "fnref" + str(n)
  html.elem(
    "sup",
    attrs: (class: "footnotes-ref"),
    html.elem("a", attrs: (href: href, id: id), [\[#n\]]),
  )
  fn-state.update(it => {
    let (id, pc) = it
    (id + 1, pc + (c,))
  })
}
```

The `fn-state` state variable keeps in track of the number of footnotes and the content of them. Afterwards, I use this
piece of code to render the footnotes:

```typ
#context {
  let footnotes = fn-state.final().at(1)
  if footnotes.len() == 0 {
    return
  }
  html.elem("hr", attrs: (class: "footnotes-sep"))
  html.elem(
    "section",
    attrs: (class: "footnotes"),
    html.elem("ol", attrs: (class: "footnotes-list"))[
      #for (idx, fn) in footnotes.enumerate() {
        html.elem("li", attrs: (id: "fn" + str(idx + 1), class: "footnote-item"))[
          #let href = "#fnref" + str(idx + 1)
          #fn #html.elem("a", attrs: (href: href, class: "footnote-backref"))[↩︎]
        ]
      }
    ],
  )
}
```

The blog still has some pages based on markdown, and I kept them mostly because I am lazy to fix my own problems -- I
always assumed that I have more important stuff to do, and I can do it some time in the near future. Seeing the markdown
blue in my GitHub linguistic statistics isn't always a pleasure, and editing `.gitattributes` to try to hide that isn't
always the correct way to address that.

I've done some other experiments in typst, like my #link("/trips")[travel log] is entirely written using
typst.#footnote[
  Earlier versions of the same page are written in WebC. Surprisingly, the typst version is \~80 lines longer compared
  to the WebC version. However, the WebC version relied on metadata that is provided by eleventy, while the typst
  version supports directly reading from toml files in the data folder. Now that I've removed toml support, the trip
  data is no longer exposed to other pages, which could help sandboxing (I can't find a better word for it) pages.
]

= The Plugin

Typst files are compiled to HTML, and the compilation is triggered by eleventy. Basically, I wrote a eleventy plugin
that uses Camiyori's typst.ts utility to compile Typst files and expose the frontmatter#footnote[
  Similar to astro-typst's, but the eleventy version.
] info to meta templates, which can then use it to display e.g. the "WIP" info you might already saw in other pages.

This plugin is mostly based on Uwni's plugin that serves the same purpose. I did some slight modifications, and
simplified it to a minimum, reducing the PDF generation function as I don't really need PDFs for now.#footnote[
  I am writing `html.elem`s all over the place -- what should I do then??
]

= Conclusion

I have not tried adding images or formulas yet,#footnote[
  Here is a quick and simple test using `html.frame`:
  #html.frame($ integral x^3 dot ln x dif x $)
  Nevertheless, I still need to work on it to make it display properly under dark mode.
] and it would be hard to add them using Typst's current html export features. Yet, as a normal user of Typst, I would
definitely keep in track of its changes. While our honourable crew work on Typst, especially the HTML export feature, I
would work on this blog, and hopefully write some more articles about Typst and remove those "WIP" labels.
