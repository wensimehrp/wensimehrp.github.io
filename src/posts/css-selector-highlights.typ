#import "../mod.typ": *
#show: wstemplate.with(
  title: "Highlighting Lyrics with CSS Selectors",
  description: "What's next?",
  created: datetime(year: 2026, month: 07, day: 15),
  author: jeremy-gao,
)

#let dict = (
  (
    ja: (
      (1, [はちみー]),
      (2, [はちみー]),
      (3, [はちみー]),
    ),
    zh: (
      (1, [蜂蜜]),
      (2, [蜂蜜]),
      (3, [蜂蜜]),
    ),
    en: (
      (1, [Honey]),
      (2, [Honey]),
      (3, [Honey]),
    ),
    ja-Latn: (
      (1, [Hachimī]),
      (2, [hachimī]),
      (3, [hachimī]),
    ),
  ),
  (
    ja: (
      (1, [はちみー]),
      (4, [を]),
      (2, [なめる]),
      (3, [と]),
    ),
    zh: (
      (3, [只要]),
      (2, [喝了]),
      (1, [蜂蜜特饮]),
      (3, [的话]),
    ),
    en: (
      (3, [If]),
      (0, [you]),
      (2, [drink]),
      (1, [the honey drink]),
    ),
    ja-Latn: (
      (1, [Hachimī]),
      (4, [o]),
      (2, [nameru]),
      (3, [to]),
    ),
  ),
  (
    ja: (
      (1, [あしがー]),
      (2, [あしがー]),
      (3, [あしがー]),
    ),
    zh: (
      (1, [脚步]),
      (2, [脚步]),
      (3, [脚步]),
    ),
    en: (
      (1, [Your steps]),
      (2, [your steps]),
      (3, [your steps]),
    ),
    ja-Latn: (
      (1, [Ashigā]),
      (2, [ashigā]),
      (3, [ashigā]),
    ),
  ),
  (
    ja: (
      (1, [はやくー]),
      (2, [なる]),
    ),
    zh: (
      (2, [就会]),
      (1, [变轻快]),
    ),
    en: (
      (2, [Will]),
      (1, [go faster]),
    ),
    ja-Latn: (
      (1, [Hayakū]),
      (2, [naru]),
    ),
  ),
)

#let max-words = 6;

#let typst-src = ```typ
#html.style(
  (
    for idx in range(6) {
      (".line:has(.word-" + str(idx) + ":hover) .word-" + str(idx),)
    }
  ).join(",\n")
    + " {
background-color: #ff05;
text-decoration-thickness: 5px;
}",
)

#let colours = (
  "decoration-[#00AEEF]", // C
  "decoration-[#EC008C]", // M
  "decoration-[#FCBA03]", // Y
  "decoration-black dark:decoration-[#FFF]", // K
)

#html.div(class: "mx-auto w-fit my-15",
  html.hgroup(
    html.h2(class: "mx-auto w-fit mb-1")[The Honey Drink Song]
    + html.p(class: "mx-auto w-fit font-sans", lang: "ja")[はちみーのうた]
  )
  + for line in dict {
  html.div(class: "line my-8", for (lang, words) in line {
    let words = for (idx, word) in words {
      let colour = colours.at(calc.rem(idx, colours.len()))
      (html.span(
        class:
          colour +
          " transition-all decoration-2 underline-offset-4 underline word-" +
          str(idx),
        lang: lang,
        word
      ),)
    }
    if lang in ("ja", "zh") {
      // C and J don't use spaces
      words.join(html.span(class: "inline-block w-1"))
    } else {
      // weird language. use spaces instead
      words.join(" ")
    }
    linebreak()
  })
})
```

#eval(typst-src.text, mode: "markup", scope: (dict: dict))

#let ref-link = "https://blog.xinshijiededa.men/css-hover-interlinear/"

I used CSS selectors in my #link("https://wensimehrp.github.io/tfvindex")[TFVIndex] site for highlighting companies
operating in a prefecture and companies' operation range. #link(ref-link)[This earlier blog post from OverflowCat] shows
that selectors can be used to implement multilingual translation highlighting. The song above is my implementation using
a different piece of text and build method.

#divider()

= Typst Source

#typst-src
