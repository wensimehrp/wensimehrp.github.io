#import "../mod.typ": *
#show: wstemplate.with(
  title: "Paiagram 0: Foundations",
  description: "What technologies I used in the app.",
  created: datetime(year: 2025, month: 12, day: 14),
  tags: ("egui", "rust", "paiagram"),
  author: jeremy-gao,
)

_This post is part of the series of dev diaries about Paiagram, an application for creating and visualizing transport
timetables. Visit #elink("https://paiagram.com") to try out the app!_

= A Personal Story

A few who are like me that constantly tracks my online activities might notice that #elink(
  "https://github.com/WenSimEHRP/Paiagram",
)[WenSimEHRP/Paiagram] isn't accessible. This is because I renamed it to paiagram-typst, for I want to use Paiagram as
the name of my first app. It's not quite the same as my previous timetable diagram typst plugin: it's a timetable editor
that allows the user to inspect and edit train timetables, and can run on both the web and desktop.#footnote[
  The WenSimEHRP/Paiagram is private by the time you're reading this line, but I would make it public once I completed
  most of the development. And if you want to see the source code right now, you can take a look at #elink(
    "https://wensimehrp.github.io/Paiagram",
  )[the site] to see the source code -- it's AGPL v3.0, anyways, which means that I cannot really put it online without
  showing the code.]

It's not an easy job to develop an application, especially if the app is targeting both the web and desktop. Each
platform has its unique problems. On iOS you might be blocked by some weird apple APIs that forces you to allocate
memory differently, and on the web you might have trouble setting up the canvas. The web version's performance might be
worse, while on native, you don't have to worry about performance too much, because every single piece of code is
compiled to machine language, unlike WebAssembly, which runs inside a sandboxed runtime and may incur additional
overhead depending on the browser.#footnote[The `wasmi` runtime only does interpretation.]

A more natural question to ask is: why would you write this application in the first place? The answer to this is: I've
been wanting to write this app since I graduated from grade school. I knew that train diagrams are important tools in
transportation, especially train transportation, and I was also a massive lover of train and economic simulation games
(like Chris Sawyer's Locomotion and OpenTTD), hence I wanted to use a tool that can correctly schedule trains, tell them
where to go at the right time, while being easy to use. The only tools I could use were #elink(
  "https://web.archive.org/web/20240909024820/http://take-okm.a.la9.jp/oudia/index.html",
)[OuDia], #elink("https://github.com/lifanxi/train-graph")[ETRC], #elink(
  "https://github.com/CDK6182CHR/train_graph",
)[pyETRC], and a bit later, #elink("https://github.com/CDK6182CHR/qETRC")[qETRC].#footnote[Both qETRC and pyETRC are
  developed by #elink(
    "https://github.com/cdk6182chr",
  )[x.e.p.]. They are not official successors of ETRC.]. I was too dumb to install a JDK for ETRC, and I couldn't read
OuDia's Japanese interface, so I tried py and qETRC and -- I didn't know if it is because I was too stupid or both apps
were poorly designed -- I just couldn't get the hang of them.

Now after COVID, after Trudeau, after CrowdStrike and Cloudflare's crashes, I started to make my own using modern
technologies -- Rust, Bevy, and egui. It's my first serious application, and probably not my last one.

And let's talk about the technologies.

= Why Web?

Because it is the most accessible. Anyone with a Chromium or Firefox new enough to run a bunch of GL can run this app.
The user can chose whichever version they prefer, the web version for maximum flexibility or the desktop version for the
best performance.

This introduces a set of problems unique to the web. The first obvious question is: how to even make a web app? You
would need an interface to display stuff, and something that can do the calculations. I didn't want to rent a server,
and it's also not practical for a designing tool for each user operation is sent to the server and the server rerenders
the html and sends it back to the user. The answer here is to use the JavaScript canvas, and write some code to draw
onto the canvas.

Most programming languages supports the web, and #elink("https://rust-lang.org/")[Rust] supports it best#footnote[Of
  course, not including JS/TS here.]. The #elink(
  "https://doc.rust-lang.org/rustc/platform-support/wasm32-unknown-unknown.html",
)[`wasm32-unknown-unknown`] target supports compiling to WebAssembly seamlessly, and crates like #elink(
  "https://github.com/wasm-bindgen/wasm-bindgen",
)[`wasm-bindgen`] massively simplifies the process of creating JavaScript bindings for the Rust WASM binary. There are
other features that are mentioned repetitively, like memory safety and performance guarantees. I already wrote several
typst plugins using rust. Inherently, I continued with Rust.

Rust's strength not only stops at web, memory safety, and performance. It also has a diverse ecosystem and one of the
best package managers: Cargo. There is no need to memorize ten CMake flags then realizing that you also have to install
compiled binaries for the next program would use it. All you have to do is `cargo run` and, with the right libraries
installed, your program just automatically runs.

We have a language now, but what can we draw on the canvas?

= Starting with egui

Lots of applications only target native platforms, those are, Windows, MacOS, and maybe Linux.#footnote[Following the
  canonical order.] Lots of UI technologies only target native platforms, or only has partial or minimal web support. A
lot of popular UI toolkits fall into this category, including GTK, FLTK, and WxWidgets.#footnote[You shouldn't count
  react and similar frameworks because they require a browser.] Luckily, there are some fast UI frameworks that works
well for my case, including Dear ImGui, Qt, Flutter, Iced, and egui. I picked egui from the list, because it is the one
of the fastest to develop, has a modern look, and doesn't introduce the multi-language hassle.

#elink("https://github.com/emilk/egui")[egui] is an immediate mode UI, which means that the entire UI gets rerendered
each frame. It sounds like a lot of computing job to do, but in my case, I am designing an app that contains a lot of
graphs, this problem is negligible, as the ui needs to be repainted every frame anyways. Immediate mode simplifies the
design process a lot, as there is no UI state to explicitly maintain at every single step, and performing an action is
as simple as `if ui.button(...).clicked() {}`, with no need to write callbacks at all -- what else could be simpler than
that? It does come with some caveats though, like not being able to automatically detect a font when rendering CJK text
and creating significant lag when the interface is extremely complicated, but most of those problems have workarounds,
and such problems are not common anyways.

= Bevy and Bevy ECS

We're finally onto ECS, the magic trick that makes everything run faster. I used #elink(
  "https://github.com/bevyengine/bevy",
)[Bevy's ECS engine] in my application.

ECS stands for entity, component, and system. An entity is an object with an ID, which could carry components. A
component is data related to a topic. A system is a set of rules that would modify components in runtime, and in bevy's
case, a system is just a normal Rust function. The same components are contiguously stored in the same array, which
helps performance since small pieces of data stored contiguously are extremely cache-friendly. In contrast, traditional
OOP oftentimes scatter objects in memory, which hurts data locality.

Bevy also provides a plugin interface for easy adding and removing functions. For Paiagram's case, each component in the
model, vehicles, intervals, are added as plugins, for better modularity. This modular design allows me to better handle
each component separately, and helps debugging.

Paiagram only uses Bevy's ECS, since I don't need the entirety of Bevy. I initially started using the `bevy_egui`
plugin, but then I noticed that 1. it lacks IME support and 2. its rendering quality is bad. So I switched to using
egui's native option, eframe, and manually updated the ECS world from the UI's update function.

= The End

This post only covers the foundations of Paiagram: the motivation, platforms, and technologies. It doesn't cover any
features, internal representations, or any code -- those are for next time. Paiagram is something that I wanted to build
for years, long before I knew what Rust, WebAssembly, and ECS are. The tools have changed,#footnote[There's no
  timekeeping in real life: #elink(
    "https://www.openttd.org/news/2024/03/23/timekeeping",
  )] yet my goals remained the same. This post is just a starting point.

If you're here for screenshots, no. There aren't any in the post.
