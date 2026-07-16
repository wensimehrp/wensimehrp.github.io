// atom feed generation
#import "@preview/exemel:0.1.0": *

#let me = atom-author(
  "Jeremy Gao",
  email: "wensimehrp@gmail.com",
  uri: "https://wensimehrp.github.io/about",
)

#let make-post((path, content)) = {
  let time = datetime(
    year: content.created.year(),
    month: content.created.month(),
    day: content.created.day(),
    hour: 0,
    minute: 0,
    second: 0,
  )
  atom-post(
    content.title,
    link: "https://wensimehrp.github.io/" + path,
    id: atom-site-id(
      authority: "wensimehrp.github.io",
      time: datetime(year: 2026, month: 7, day: 16),
      identifier: path,
    ),
    updated: time,
    published: time,
    summary: content.description,
    content: none,
    authors: (me,),
    categories: (),
  )
}

#context [
  #asset("atom.xml", {
    let posts = state("__page-abs-links").final().pairs().map(make-post)
    atom-encode(
      title: "The Gao Log",
      subtitle: "Gather and Observe",
      site-link: "https://wensimehrp.github.io",
      id: atom-site-id(
        authority: "wensimehrp.github.io",
        time: datetime(year: 2026, month: 7, day: 16),
      ),
      updated: datetime(year: 2026, month: 7, day: 3, hour: 14, minute: 30, second: 0),
      authors: (me,),
      posts: posts,
    )
  }) <atom>]
