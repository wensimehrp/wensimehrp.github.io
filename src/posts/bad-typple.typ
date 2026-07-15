#import "../mod.typ": *
#show: wstemplate.with(
  title: "Bad Typple",
  description: "Bad Apple with Typst",
  created: datetime(year: 2025, month: 09, day: 21),
  tags: ("Typst",),
  author: jeremy-gao,
)

#elink("https://github.com/WenSimEHRP/bad-typple").

#context if target() == "html" {
  html.elem("iframe", attrs: (
    src: "//player.bilibili.com/player.html?isOutside=true&bvid=BV1MnncznEbc",
    scrolling: "no",
    border: "0",
    frameborder: "no",
    framespacing: "0",
    allowfullscreen: "true",
    class: "w-full aspect-video bg-black",
    loading: "lazy",
  ))
} else [
  The video is available at #elink("https://www.bilibili.com/video/BV1MnncznEbc").
]
