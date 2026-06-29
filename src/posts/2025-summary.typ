#import "../mod.typ": *
#show: wstemplate.with(
  layout: "layout.webc",
  title: "2025 Summary",
  description: "What did I do in 2025???",
  created: datetime(year: 2026, month: 02, day: 26),
  tags: (),
  author: jeremy-gao,
)

Hmm, I didn't realize that it's almost March. I guess their theory is true then -- the older you are, the faster you
feel time flies. Time doesn't march so fast when I was in elementary school.

= WINS

I started working on #elink("https://github.com/wensimehrp/wins")[a station set] for OpenTTD in early 2025. WINS stand
for WINS Is Not (only) Stations -- a recursive acronym. It initially means something different, and halfway in
development I simply decided to reinterpret the full name.

The station set features a set of platform and yard tiles, and the development experience was an entire nightmare. Not
only because the GRF itself was a terrible format that puts constraints everywhere and forces you to look for
workarounds in ancient forums, but also because it's hard to draw station tiles themselves. I had a plan to draw out a
set of Japanese stations, including every perspective, and even with variations. It was just too hard to draw all of
them :-(

= NixOS

#elink("https://github.com/wensimehrp/nixos")[I started using NixOS in April]. There aren't a lot to talk about it.

= Paiagram-typst

I was a big fan in timetables, and I made #elink("https://github.com/wensimehrp/paiagram-typst")[a Typst plugin] to map
out the trains. The diagram I was making was essentially just a fancier d-t graph, so it wasn't that hard to process the
data. Something to note is that I used the WASM plugin interface in this project, and it is my first serious attempt on
using the Rust programming language.

= This Blog Site

Basically the stuff you are looking at right now.

= Translations

I did a bunch of translations, mostly for #elink("https://github.com/openttd/openttd")[OpenTTD], and the other
super-popular #elink("https://github.com/jgrennison/openttd-patches")[OpenTTD JGR Patchpack]. It is pretty fun to refine
all of those terminologies and criticize previous translators. Of course, I would also be criticized by someone else at
some point.

= Conjak

#elink("https://github.com/wensimehrp/conjak")[Supporting package] for converting between CJK dates and number formats.
This one also uses WASM.

= Other Minor Typst Projects

#elink("https://github.com/wensimehrp/eeaabb")[EEAABB] and #elink("https://github.com/wensimehrp/nexusrail")[NexusRail]

= Paiagram

The super-duper fun project I am doing right now. Take a look at the #elink(
  "https://github.com/wensimehrp/paiagram",
)[repository] -- it is going to be interesting.
