#!/usr/bin/env -S typst compile --features bundle,html --format bundle
#import "@preview/typhoon:0.1.2": _plugin

#let tailwind-classes = state("tailwind-classes", ())
#show html.elem: elem => {
  let classes = elem.fields().attrs.at("class", default: ())
  let classes = if type(classes) == str {
    classes.split(" ")
  } else {
    classes
  }
  tailwind-classes.update(it => {
    (it + classes).sorted().dedup()
  })
  elem
}

#context {
  asset(
    "styles.css",
    ```css
    :root {
        scroll-behavior: smooth;
    }
    ```.text
      + str(_plugin.generate(
        bytes(
          tailwind-classes.final().join(" ") + "",
        ),
        cbor.encode((
          preflight: (
            full: (
              font_family_sans: "Nunito",
            ),
          ),
        )),
      )),
  )
}

#let basic(c, page-title: none) = {
  import html: *
  html(lang: "en", {
    head({
      meta(charset: "utf-8")
      meta(name: "viewport", content: "width=device-width, initial-scale=1")
      link(rel: "stylesheet", href: "/styles.css")
      style(
        "@import url('https://fonts.googleapis.com/css2?family=Libertinus+Serif+Display&family=Nunito:ital,wght@0,200..1000;1,200..1000&display=swap');",
      )
      elem("script", attrs: (
        defer: "",
        src: "https://cloud.umami.is/script.js",
        data-website-id: "1e645081-beea-4836-bd66-ead28c2c1976",
      ))
      title(page-title)
    })
    body(class: "bg-stone-100 dark:bg-zinc-800", {
      article(
        class: (
          "prose",
          "prose-headings:font-[Libertinus_Serif_Display]",
          "dark:prose-invert",
          "max-w-3xl",
          "mx-auto",
          "px-5",
          "my-20",
          "prose-pre:bg-zinc-900",
          "prose-pre:rounded-none",
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
    "src/posts/2025-summary.typ",
    "src/posts/typst-animations.typ",
    "src/posts/typst-as-ssg.typ",
    "src/posts/bad-typple.typ",
    "src/posts/typtex.typ",
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
      (post.html-renderer.with(page-key: post.title))[
        #title(post.title)
        #post.content
      ],
    ),
  ) #post.label
]

#let format-link(post) = link(post.label, {
  post.title
  html.span(class: "ml-auto", post.created.display("[month repr:short]. [day], [year]"))
})

#document(
  "connections.html",
  basic(page-title: [Connections])[
    #title[Connections]
    #let connections = toml("connections.toml").connections
    #(
      connections
        .map(ent => html.div(
          class: "mb-5 [&_a]:block [&_a]:no-underline [&_a]:hover:shadow-[0_0.25rem_0_0_gray] [&_a]:transition-shadow",
          link(
            ent.link,
            {
              html.span(class: "block", heading(level: 2, ent.title))
              ent.description
            },
          ),
        ))
        .join()
    )
  ],
) <connections>

#document(
  "index.html",
  basic(page-title: [The Gao Log])[
    #title[The Gao Log]
    #let urls = (
      ("https://wensimehrp.github.io/tfvindex", [TFVIndex Icon Site]),
      ("https://paiagram.com", [Paiagram]),
      (<connections>, [Connections]),
    )
    #html.div(
      class: "[&_a]:flex [&_a]:no-underline [&_a]:hover:shadow-[0_0.25rem_0_0_gray] [&_a]:transition-shadow",
      (urls.map(it => link(..it)) + posts.map(format-link)).join(parbreak()),
    )
  ],
)
