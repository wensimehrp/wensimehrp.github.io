#import "../mod.typ": *
#show: wstemplate.with(
  title: "Paiagram 1: World Design",
  description: "Immutable data structures.",
  created: datetime(year: 2026, month: 11, day: 10),
  tags: ("rust", "paiagram"),
  author: jeremy-gao,
)

_This post is part of the series of dev diaries about Paiagram, an application for creating and
visualizing transport timetables. Visit #elink("https://paiagram.com") to try out the app!_

All editors have a "world", which is the centralized storage of the current editing state. A text
editor's world would be the current text edit buffer. For Paiagram, it is the trips, routes, nodes,
and intervals that construct the transit network.

The most difficult part during the development of Paiagram was designing a world model that
satisfies all of the following:

- Fast
- Lightweight, even when I need to use it across multiple threads
- Can be (de)serialized via serde
- Supports undo and redo
- Supports extensions.
- Multiuser collaboration.

These are the reasons why I used immutable data structures. Before discussing immutable data
structures, I want to first talk about the command--source pattern, and why I eventually abandoned
it.

= Command and Conquer

Inside the editor, the user may perform some actions, maybe revert them, and do some other stuff.
Thus, we can make each action, such as shifting the departure time of a trip, a command that changes
the world.

Traditional models, such as the one #link("https://doc.qt.io/qt-6/qundocommand.html")[used by Qt],
don't produce counter commands, instead they have `undo` and `redo` on a single command. Thinking
their approach was stupid, I started with the following instead:

```rust
enum Command {
    AddTrain(..),
    RemoveTrain(..),
    ShiftTripTime(..),
}

impl Command {
    fn act(self, world: World) -> Result<Command, E> {
        // in this case E is some generic error type
        use Command::*;
        match self {
            AddTrain(..) => Ok(RemoveTrain(..)),
            RemoveTrain(..) => Ok(AddTrain(..)),
            ShiftTripTime(..) => Ok(ShiftTripTime(..)),
        }
    }
}
```

Each command produces a countercommand that does the exact opposite when being committed, and that
countercommand would be pushed into an undo stack. The command pattern works particularly well, and
doesn't require an extra `undo` method. But applications grow and get complicated every; manually
wiring each command to a counter command introduces _a lot_ of bugs. There are more drawbacks to
commands in general:

- It is easy to lose cached states, and the countercommand must store cached data accordingly.
- Some command variant might be huge. Though this could be solved by wrapping the variant in a Box.
- Changing the internal representation of one command meaning rewriting the mapping logic and
  changing another command's internals. A lot of the logic is already available somewhere else in
  the codebase, and the command system is just duplicating them.

Undos aren't the only reason why I eventually choese imbl. I wrote an overcomplicated implementation
for my world model before that.

= Persistent Keys

_TODO_

Summary:

- twitter snowflakes (https://en.wikipedia.org/wiki/Snowflake_ID), Also Paiagram should lwk
- switch to
  https://github.com/mastodon/mastodon/blob/5e796dc6f85b37c8378fe01cfd8ac23222c89eea/lib/mastodon/snowflake.rb
  in the future.

= SoAs Are Not That Convenient

I set "performance" as one of the main goals for the world model. At a first glance, the _SoA_
paradigm, which stands for _structure of arrays_, seemed like a good choice.


The most common way to store some data is _array of structures_, or AoS for short. It is the reverse
of _structure of arrays_. The idea of AoS is to store the data inside a big vector, and each
datum#footnote[Do we even use this word?] would be a structure containing some fields:

```rust
struct MyDatum {
    foo: f64,           // 8 bytes
    bar: bool,          // 1 bytes
    baz: Vec<BlaBlaBla> // Vec itself is 24 bytes on a 64-bit machine
}

/// The storage for all MyDatum
struct Data(Vec<MyDatum>);
```

Because of alignments and other issues, the overall size of MyDatum would bigger than 8 bytes + 1
byte + 24 bytes = 33 bytes. On my machine, Rust would insert 7 extra bytes and make it 40 bytes in
total. #footnote[
  See https://en.wikipedia.org/wiki/Data_structure_alignment for more details
]

SoA reverses this design. Instead of storing _structures_ in _arrays_, SoA instead stores _arrays_
in _structures_:

```rust
struct Data {
    foo: Vec<f64>,
    bar: Vec<bool>,
    baz: Vec<BlaBlaBla>,
}
```

Each piece of data is stored directly against each other in RAM, which leaves no space for padding.
In addition, this pattern is also particularly well for procedures that operate only on one field.

Structure of arrays (and to an extent, the Entity--Component--System paradigm), is best when the app
frequently accesses homogenous data and processes them in batches. While this is true for many types
of games, as they tend to share similar components accross different entities, each entity in
Paiagram carries its _unique set_ of data, and the components of different types of entities are
barely shareable.

There are more pitfalls to SoA.

In the #link(<paiagram-0-with-bevy>)[previous blog post], I said that I will use Bevy because it is
"the magic trick that makes everything run faster." I removed Bevy six months later because of these
reasons:

- Bevy's entities are not ordered in memory.
- Each query to the ECS requires a lot of `.unwrap()`s to get the underlying data type, or at least
  early returns. _Their type also can't be guaranteed by the Type system since each piece of data
  (trip, station, route, notes, etc.) share the same Key type (Entity)_. #footnote[
    I tried using #link(
      "https://docs.rs/moonshine-core/latest/moonshine_core/#-moonshine-kind",
    )[`moonshine-kind`] to wrap around my entities, but it was an extremely erroneous approach.
  ]
- Undo/Redo becomes tedious as it is impossible to insert an old Entity into the World.
- It is a game engine, not a library. Bevy introduces hidden bloat.

#let bevy-ftn = footnote[
  #let aba = link("https://en.wikipedia.org/wiki/ABA_problem")[ABA problem]
  #let bevy-ent = link("https://docs.rs/bevy_ecs/0.20.1/src/bevy_ecs/entity/mod.rs.html#424")[The
    `Entity` type in Bevy]
  Bevy's internal design is more complicated than what I've covered here. Inside Bevy, different
  entities with the same set types of components are grouped into the same _archetype_; the
  underlying storage for each component can be either an #link(
    "https://docs.rs/bevy/latest/bevy/prelude/derive.Component.html",
  )[array or a hash map]; #bevy-ent is composed of `EntityIndex` and `EntityGeneration` to prevent
  the #aba. since I've only used Bevy for three months, I can't make any guarantees that what I have
  here is 100% accurate. You may chcek out https://bevy.org for more information on the engine's
  internal design.
]

SoA only works well with direct numerical indices, i.e. `usize`, `u32`, and `u64`. This is a not an
issue for Bevy and its ECS, since it's possible to directly query the components attached to an
entity by indexing the ECS world using `Entity` #bevy-ftn.

_TODO_

Summary:
- We have persistent keys but because entities want to solve the aba problem we can't insert an old
  key into the world to do undo and redo
- also makes slotmap unusable
- cheesecake?
- 2141 Granville St, Vancouver, BC V6H 3E9

= Immutable Data Structures

_TODO_

Summary:
- Sharing data between threads
- Feels like a little deterministic GC
- Saving history is now extremely easy as we only need to swap a few pointers
- In the future each undo and redo will be implemented as (World, World) to match multiuser collab

= One Year of Paiagram

I created the first commit on Nov. 4, 2025 PT.

_TODO_

Summary:
- Paiagram 0.5: Side Quests (separate post)
  - Haita, Typst HTML, Cloudflare pages, multithreading in web browser
- A lot of new features
- Learned a lot of stuff
