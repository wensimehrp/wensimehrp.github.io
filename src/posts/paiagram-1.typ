#import "../mod.typ": *
#show: wstemplate.with(
  title: "Paiagram 1: World Design",
  description: "Immutable data structures.",
  created: datetime(year: 2026, month: 11, day: 15),
  tags: ("rust", "paiagram"),
  author: jeremy-gao,
)

_This post is part of the series of dev diaries about Paiagram, an application for creating and
visualizing transport timetables. Visit #elink("https://paiagram.com") to try out the app!_

All editors have a "world", which is the centralized storage of the current editing state. A text
editor's world would be the current text edit buffer. For Paiagram, it is the trips, routes, nodes,
and intervals that construct the transit network. The most difficult part during the development of
Paiagram was designing a world model that satisfies all the following:

- is fast
- is lightweight, even when I need to use it across multiple threads
- can be (de)serialized via serde
- supports undo and redo
- supports extensions.
- can be used for multiuser collaboration.

These are the reasons why I used immutable data structures. Before discussing immutable data
structures, I want to first talk about few design patterns that I tried in Paiagram, and why I
eventually abandoned them.

= Command and Conquer

The user may perform some actions in the editor, maybe revert them, and do some other stuff. Thus,
we can make each action a command that changes the world, such as shifting the departure time of a
trip.

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

Because of alignments and other issues, the overall size of MyDatum would be bigger than 8 bytes + 1
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

= Persistent Keys

Let's say we have a world. The world has some data. For the sake of convenience, it's better to let
the user take a _reference_ to the data instead of giving the user the data themselves. Thus, we can
use some IDs to reference the data.

But how to design the ID?

Let's start with a strictly incremental counter. In this way, we would have a central registry that
stores how many keys we have issued so far, and we can request a new key each time we want to insert
something. However, multiple clients will race against each other simply to generate new keys, which
leads to significant lags.#footnote[
  This isn't really a problem when there's only one client, and we can use `AtomicUsize` instead.
]

Another way is to simply use the name of something, say the name of a train trip "ICE 999" or
"G6666". But names change, and relying on something that would change often causes desyncs.

Summary:

- twitter snowflakes (https://en.wikipedia.org/wiki/Snowflake_ID), Also Paiagram should lwk switch
  to
  https://github.com/mastodon/mastodon/blob/5e796dc6f85b37c8378fe01cfd8ac23222c89eea/lib/mastodon/snowflake.rb
  in the future.


= OrdMap

#let imbl-ftn = footnote[See more details at https://docs.rs/imbl]

Immutable data structures are data structures which can be copied and modified efficiently without
altering the original #imbl-ftn. The simplist example of an immutable data structure might be a cons
list:

#html.div(class: "mx-auto w-fit")[_IMAGE TODO, I will draw it myself_]

In reailty, the computer won't know when to clear each node, so each node carries a resources
release reference: a counter. The counter shows how many datums#footnote[This is getting weirder.]
still holds a reference to the cons node. When the counter reaches 0, the computer frees up the
memory occupied by the node. Of course, a cons list is not enough for Paiagram.

#let complexity-ftn = footnote[Like Rust's `std::collections::BTreeMap`, most operations on `OrdMap`
  is $O(log n)$. However, most operations on `imbl`'s `HashMap` is not $O(1)$, instead they are also
  $O(log n)$ as they are implemented using trees.
]

Paiagram uses the `OrdMap` type from the crate `imbl`, which is implemented using a B+Tree. `OrdMap`
and `imbl`'s `HashMap` both provide some generic key--value storage #complexity-ftn; sometimes
accessing values stored in a `HashMap` is faster than `OrdMap`, but key--value pairs stored in
OrdMap are always ordered (hence the name #strong[Ord]Map), and this behaviour is more predictable
than `HashMap`'s hashes. Additionally, because our IDs start with timestamps, all key--value pairs
stored in the map are also sorted based on their creation time.

Using such data structures makes some function signatures extremely simple: instead of having to
take a reference (immutable or mutable), any APIs that need to interact with the world can simply
_consume_ the world and take the ownership:

```rust
// before
fn expensive_calc(world: &mut World) {
    // oh... I can't send this to another thread unless I clone it or wrap it in Arc
}

// after
fn expensive_calc(world: World) {
    // This is better; we still have to call .clone() somewhere,
    // but it is cheap as everything is shared!
}
```

It feels like a little deterministic garbage collector #emoji.face.beam.

= Trunk

`OrdMap` is thread safe. This means different procedures running on different threads can logically
own their distinct copy of the world, while still sharing data and saving RAM.

TODO: thread blah blah blah

The `diff` API#footnote[https://docs.rs/imbl/latest/imbl/struct.GenericOrdMap.html#method.diff]
returns an iterator that outputs the difference between two `OrdMap`s. Normally, doing so would walk
through each pair in both maps#footnote[See the #link(
    "https://doc.rust-lang.org/stable/std/collections/struct.BTreeSet.html#method.symmetric_difference",
  )[implementation] of ```rust BTreeSet::symmetric_difference``` in the Rust standard library.].
However, if two `OrdMap`s already share most of their contents, the iterator can simply compare the
pointers of their subtrees; if two subtrees have the same address, their contents must be the same.

Summary:
- Merging world state must be done on the main thread, which can be expensive sometimes
- Saving history is now extremely easy as we only need to swap a few pointers
- In the future each undo and redo will be implemented as (World, World) to match multiuser collab

= One Year of Paiagram

I created the first commit on Nov. 4, 2025 PT.#footnote[When we had Pacific Standard Time and
  Mountain Standard Time]

_TODO_

Summary:
- Paiagram 0.5: Side Quests (separate post)
  - Haita, Typst HTML, Cloudflare pages, multithreading in web browser
- A lot of new features
- Learned a lot of stuff
