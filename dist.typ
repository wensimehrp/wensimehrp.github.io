#!/usr/bin/env bash
#let _ = ```sh
case "$1" in
  compile) typst compile --features bundle,html --format bundle $0 ;;
  watch)   typst watch   --features bundle,html --format bundle --pretty $0 ;;
  *)       echo "Unknown option: $1. Enter 'compile' or 'watch'"; exit 1 ;;
esac
exit 0
```
#import "@preview/typhoon:0.2.0"

// highlighting for gleam code
#show raw.where(lang: "gleam"): set raw(syntaxes: "Gleam.sublime-syntax")

#context [
  #asset(
    "styles.css",
    {
      ```css
      @import url('https://fonts.googleapis.com/css2?family=Libertinus+Serif+Display&family=Nunito:ital,wght@0,200..1000;1,200..1000&display=swap');

      :root {
          scroll-behavior: smooth;
      }

      @keyframes inline-flash {
          0% { background-color: transparent; }
          10% { background-color: rgba(253, 224, 71, 0.8); }
          100% { background-color: transparent; }
      }

      ```.text

      typhoon.tailwind-css(config: (
        preflight: (
          full: (
            font_family_sans: "Nunito",
          ),
        ),
      ))
    },
  )
]

#let basic(c, page-title: none) = {
  import html as h
  show h.elem: typhoon.update-elem
  h.html(lang: "en", {
    h.head({
      h.meta(charset: "utf-8")
      h.meta(name: "viewport", content: "width=device-width, initial-scale=1")
      h.link(rel: "stylesheet", href: "/styles.css")
      h.elem("script", attrs: (
        defer: "",
        src: "https://umami-theta-pink.vercel.app/script.js",
        data-website-id: "bbe83d2b-314a-4023-87e7-765f49b46a0c",
      ))
      h.title(page-title)
    })
    h.body(class: "bg-stone-100 dark:bg-zinc-800", {
      h.article(
        class: (
          "prose",
          "prose-stone",
          "prose-headings:font-[Libertinus_Serif_Display]",
          "dark:prose-invert",
          "prose-pre:border",
          "prose-pre:bg-transparent",
          "prose-pre:text-slate-800",
          // they only work with the exclamation point for some reason
          "dark:prose-pre:!bg-black",
          "dark:prose-pre:!border-transparent",
          "dark:prose-pre:!text-white",
          "prose-pre:rounded-none",
          "prose-a:decoration-1",
          "prose-a:hover:decoration-4",
          "prose-a:transition-all",
          "prose-a:underline-offset-4",
          "max-w-3xl",
          "mx-auto",
          "px-5",
          "my-20",
        ),
        c,
      )
    })
  })
}

#let posts = (
  (
    "src/posts/typst-transition.typ",
    "src/posts/paiagram-0.typ",
    "src/posts/paiagram-1.typ",
    "src/posts/2025-summary.typ",
    "src/posts/typst-animations.typ",
    "src/posts/building-websites-with-just-typst.typ",
    "src/posts/css-selector-highlights.typ",
    "src/posts/bad-typple.typ",
    "src/posts/typtex.typ",
    "src/posts/gleam-first-impressions.typ",
  )
    .map(path => (include path, path))
    .map(((content, path)) => (
      content.fields().children.at(1).value
        + (
          path: path,
          label: label(path),
        )
    ))
    .sorted(key: it => it.created)
    .rev()
)

#for post in posts [
  #document(
    post.path.replace("src/posts/", "posts/").replace(".typ", ".html"),
    basic(
      page-title: post.title,
      (post.html-renderer)(post.content),
    ),
  ) #post.label
]

#let format-link(post) = link(post.label, {
  post.title
  html.span(class: "ml-auto", post.created.display("[month repr:short]. [day], [year]"))
})

#document(
  "connections.html",
  basic(page-title: [Connections], {
    let connections = toml("connections.toml").connections
    title[Connections]
    for ent in connections {
      html.div(html.a(
        class: "mb-5 block no-underline hover:shadow-[0_0.25rem_0_0_gray] transition-shadow",
        href: ent.link,
        {
          heading(level: 2, ent.title)
          ent.description
        },
      ))
    }
  }),
) <connections>

#document("about.html", basic(
  page-title: [Connections],
  include "about.typ",
)) <about>

// for Atom feed
#let page-abs-links = state("__page-abs-links", (:))

#document(
  "index.html",
  basic(page-title: [The Gao Log])[
    #title[The Gao Log]
    #let urls = (
      ("https://wensimehrp.github.io/tfvindex", [TFVIndex Icon Site]),
      ("https://paiagram.com", [Paiagram]),
      ("https://wensimehrp.github.io/haita/", [Haita Documentation Framework]),
      (<connections>, [Connections]),
      (<about>, [About]),
      (<atom>, [Subscribe to my blog (atom.xml)]),
    )
    // update page-abs-links for generating RSS
    #for post in posts {
      show html.elem.where(tag: "a"): a => page-abs-links.update(links => (
        links + ((a.attrs.href): post)
      ))
      link(post.label)[]
    }
    #html.div(
      class: "[&_a]:flex [&_a]:no-underline [&_a]:hover:shadow-[0_0.25rem_0_0_gray] [&_a]:transition-shadow",
      {
        for url in urls {
          par(link(..url))
        }
        divider()
        [= Posts]
        for (idx, post) in posts.enumerate() {
          // this wraps to the last post for the very first post
          let prev-post = posts.at(idx - 1)
          if prev-post.created.year() != post.created.year() [
            == #post.created.year()
          ]
          par(format-link(post))
        }
      },
    )
  ],
)

#include "atom.typ"
