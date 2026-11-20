#import "../mod.typ": *
#show: wstemplate.with(
  title: "2026 January to November Summary",
  description: "What did I do in 2026?",
  created: datetime(year: 2026, month: 11, day: 18),
  tags: (),
  author: jeremy-gao,
)

I found many people (and companies) making their (or their users') year-end summary early and I am
not missing this train.

If you miss the train I'm on, you will know that I am gone #footnote[I liked this song in choir.].

= Paiagram and paiagram.com

I #link(<paiagram-2025-summary>)[mentioned Paiagram] in my 2025 summary and framed it as "a
super-duper fun project" #footnote[Reference: my high school geography teacher.]. Welp, doesn't seem
like it's very fun now. I am a little bit burnt out, especially after seeing many so-called transit
games and substandard tools built with LLM agents. They don't have a taste, but they are quite fast
in mocking something.

I feel personally targeted while nobody is targeting me. Maybe it is because I am proud of my stuff.

That being said, I also used AI for some components... so I guess I shouldn't have this feeling? I
am doing computer science now (also first year), and I really don't know where this is going.

Enough of this bullshit. Paiagram is a transit visualizer I've been developing since November 2025.
It is hosted on https://paiagram.com, which also hosts Paiagram's documentation and other
interesting tools.

I completed most of Paiagram's features in early 2026 but I found that the architecture I used
doesn't work for Paiagram, so I started #link(label("src/posts/paiagram-1.typ"))[a major overhaul in
  June].

= Haita

#let ass-footnote = footnote[
  E.g. mdBook, sphinx, docusaurus, asciidoc, etc.. Markdown is really just a pseudostandard and
  pulling anything more than two binaries sounds too much for me (sphinx uses python, docusaurus
  requires node stuff).
]

#link("https://wensimehrp.github.io/haita")[Haita] is a pure-Typst documentation framework that I
developed specifically because I thought existing doc frameworks are all ass #ass-footnote. It was
my first serious Typst project, and there are _a lot_ of places that needs further polishing.

Typst's HTML export ecosystem was a piece of blank paper. HTML export was only added in 0.14, and
the `bundle` target, which allows exporting multiple pages in a single Typst project, was only added
in 0.15. This very site you're looking at right now is created using Typst's bundle export feature.

Both HTML export and `bundle` has not been stabilized yet, which also means Haita is unstable. In
addition, there are some features that I really wanted include but they were blocked because of
technical limitations of Typst. So there's still much space for improvements.

= Conclusion

What's gonna happen in 2027? Maybe I will complete my projects. And there are many minor projects
that I didn't include in this page. Still, I hope there is a way to move my focus to academic stuff
from my projects.#footnote[reference: my mom]
