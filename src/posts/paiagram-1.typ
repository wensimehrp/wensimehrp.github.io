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
editor's world would be the current text edit buffer. Paiagram's world is the trips, routes, nodes,
and intervals that construct the transit network. The most difficult part during the development of
Paiagram was designing a world model that satisfies all the following:

- is fast
- is lightweight, even when I need to use it across multiple threads
- can be (de)serialized via serde
- supports undo and redo
- supports extensions.
- supports multiuser collaboration.

These are the reasons why I used immutable data structures. Before discussing them, I want to first
talk about few design patterns that I tried in Paiagram, and why I eventually abandoned them.

= SoAs Are Not That Convenient

I set "high performance" as one of the main goals for the world model. At a first glance, the _SoA_
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
total #footnote[Data alignment is more complicated than what I've covered here. For more details,
  check out #link("https://en.wikipedia.org/wiki/Data_structure_alignment")[this article] on
  Wikipedia.].

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
frequently accesses homogeneous data and processes them in batches. While this is true for many
types of games, as they tend to share similar components across different entities, each entity in
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
  ]. This leads to multiple type-check passes and they are annoying.
- Undo/Redo becomes tedious as it is impossible to insert an old Entity into the World.
- It is a game engine, not a library. Bevy introduces much hidden bloat.

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

Although I removed Bevy, I still like the SoA structure mainly because of its _theoretical_
benefits. I ended up with this:

```rust
struct TripCollection {
    indexes: HashMap<TripKey, usize>,
    names: Vec<String>,
    schedules: Vec<TripSchedule>,
    service_classes: Vec<Option<ServiceClassKey>>,
    // ...
}
```

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
leads to significant lags #footnote[
  This isn't really a problem when there's only one client, and we can use `AtomicUsize` instead.
].

Another way is to simply use the name of something, say the name of a train trip "ICE 999" or
"G6666". But names change, and relying on something that would change often causes desyncs.

The solution is to use an ID that can be generated based on resources that are available in each
client, instead of some centralized authority. I chose the combination of timestamp + client order +
local counter over random entropy (e.g. UUID v4) because it provides some practical benefits:

- Keys can be ordered based on their timestamp.
- It does not rely on a local random number generator.

This way, there would be 65k available IDs for each centisecond. The downside is that if the client
ran out of IDs for this centisecond, it would have to wait for the next centisecond -- which is not
a problem for our scale at all!#footnote[
  To be frank, using a timestamp actually introduces more problems. A client's internal timestamp
  might leap backwards, which means it might collide with an existing ID. I haven't ran into such
  problems yet, and they are quite rare in general. Yet, they are definitely more common than RNG
  collisions.
]. In fact, this is the exact method Twitter #footnote[I like the word Twitter, becasue it portrays
  the saying 树林子大了什么鸟都有.] used to generate #link(
  "https://en.wikipedia.org/wiki/Snowflake_ID",
)[unique IDs] for their posts.

= Command and Conquer

The user may perform some actions in the editor, maybe revert them, and do some other stuff. Thus,
we can make each action a command that changes the world, such as shifting the departure time of a
trip.

Traditional models, such as the one #link("https://doc.qt.io/qt-6/qundocommand.html")[used by Qt],
require `undo` and `redo` on every command. My initial idea was to map each command to a
countercommand. For example, the countercommand of `AddTrain` would be `RemoveTrain`, and the
countercommand of `ShiftTripTime` would be itself. This way, instead of writing `undo` and `redo`,
we can simply only have `act` on a command:

```rust
enum Command {
    AddTrain(..),
    RemoveTrain(..),
    ShiftTripTime(..),
    // A macro that contains many commands
    // In reailty it is better to use Box<[Command]> to avoid accident pushes
    Macro(Vec<Command>)
}

impl Command {
    // `act` consumes the command and modifies the world.
    // in this case E is some generic error type
    fn act(self, world: &mut World) -> Result<Command, E> {
        use Command::*;
        match self {
            // The reverse of adding a train is removing a train
            AddTrain(..)      => Ok(RemoveTrain(..)),
            // The reverse of removing a train is adding a train
            RemoveTrain(..)   => Ok(AddTrain(..)),
            // The reverse of shifting a trip's time is still shifting a
            // trip's time... but negative. Of course there are overflow stuff,
            // but we don't care about them. Let it be a bug and stay.
            ShiftTripTime(..) => Ok(ShiftTripTime(..)),
            // big brother
            Macro(inner)      => Ok(
                // this code doesn't work,
                // but it basically walks over each command in the macro,
                // recursively applies each command to the world,
                // collects them,
                // and reverses the order of each command in the macro.
                inner.into_iter()
                    .map(|cmd| cmd.act(world))
                    .rev()
                    .collect::<Vec<_>>()
            )
        }
    }
}
```

The command pattern works particularly well, and doesn't require an extra `undo` method, and any
extra components can simply take a reference to the world and return a single `Command`, thanks to
the `Command::Macro` variant. The app then produces a countercommand when committing a command, and
that countercommand would be pushed into an undo stack.

But Paiagram grows and gets complicated; manually wiring each command to a countercommand introduces
_a lot_ of bugs. There are more drawbacks to commands in general:

- The countercommand must store cached data accordingly, which sometimes leads to interesting
  results. For example, removing a station might result in a giant macro that includes one
  `InsertStation` and fifty `InsertTrip`s.
- Some command variant might be huge. Though this could be solved by wrapping the variant in a `Box`
  smart pointer. Commands don't need to be fast anyways.
- Changing the internal representation of one command meaning rewriting the mapping logic and
  changing another command's internals. A lot of the logic is already available somewhere else in
  the codebase, and the command system is just duplicating them.

So, could there be a way to account all edits without having to list each edit individually?

= Immutable Data Structures

#let imbl-ftn = footnote[See more details at https://docs.rs/imbl]

I found immutable data structures the solution to undo and redos.

Immutable data structures are data structures which can be copied and modified efficiently without
altering the original #imbl-ftn. The simplest example of an immutable data structure might be a cons
list:

#html.div(class: "mx-auto w-fit")[_IMAGE TODO, I will draw it myself_]

But before we talk about how this is useful, we'll have to take a short detour to...

== Ownership and Borrowing

... Ownership, which is Rust bros' favourite #footnote[So this _is_ a Rust course eh?].

Ownership is a bit of a complicated topic, and #link(
  "https://doc.rust-lang.org/book/ch04-01-what-is-ownership.html",
)[the official documentation] has a more precise explanation for it. To be concise, a variable may
own or borrow a piece of data, and it is usually easier to work with _owned_ data instead of
_borrowed_ data, as owned data tend have less lifetime issues. A full ownership of a variable on a
data usually implies the following:

- The context/variable that owns the data can _read_ the data.
- The context/variable that owns the data can _mutate_ the data.
- The context/variable that owns the data can _transfer the ownership_, which includes destroying
  the data.

And we can use the duck test on immutable data structures. Paiagram uses `OrdMap` (which will be
discussed in the next chapter). Say that there's a variable `x` that _holds_ an `OrdMap`:

- Can `x` read the data from the structure? Sure it can.
- Can `x` mutate the data? It can by doing the following:
  - Creating a new clone of the data.
  - Modifying the clone and let itself point to the new clone.
- Can `x` transfer the ownership to another variable? Sure it can.

#html.div(class: "mx-auto w-fit")[_IMAGE TODO, I will draw it myself_]

`OrdMap`, as well as many other data structures, functions just like a `Vec` or a `HashMap`.

In reality, the computer won't know when to clear each node, so each node carries a reference
counter. The counter shows how many datums #footnote[This is getting weirder.] still hold a
reference to the cons node. When the counter reaches 0, i.e., no datum references the cons node, the
computer frees up the memory occupied by the node. Of course, a cons list is not enough for
Paiagram.

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

== OrdMap

#let complexity-ftn = footnote[Like Rust's ```rust std::collections::BTreeMap```, most operations on
  `OrdMap` is $O(log n)$. However, most operations on `imbl`'s `HashMap` is not $O(1)$, instead they
  are also $O(log n)$ as they were implemented as trees.

  But we don't really need to care about the complexity of data structures for Paiagram's data
  sizes...
]

Paiagram uses the `OrdMap` structure from the crate #link("https://docs.rs/imbl")[`imbl`], which is
implemented using a B+Tree. `OrdMap` and `imbl`'s `HashMap` both provide some generic key--value
storage #complexity-ftn. Accessing values stored in a `HashMap` is sometimes faster than `OrdMap`,
but each key--value pair stored in OrdMap is always ordered (hence the name "Ord" Map), and this
behaviour is more predictable than hashes. Additionally, because snowflake IDs start with
timestamps, the pairs in the map are sorted based on the key's creation time.

= Trunk

A common reason why apps run slow is they put every single task in one thread, including UI, IO, and
other sorts of random calculations, such as calculating cache and updating the world. UI and IO are
separate topics of their own, though.

Let's start with importing new contents as an example. Paiagram allows importing from various other
formats. Each format handler simply outputs a new _World_ with data in it. So the app has the new
world, how should it merge the new world with the existing world? Unfortunately, this step can only
be done on the main thread to avoid desyncs.

TODO: another example read from existing world and do some edits bla bla bla.

`OrdMap` is thread safe. This means different procedures running on different threads can logically
own their distinct copy of the world, while still sharing data and saving RAM.

#let btreeset-diff-impl = {
  "https://doc.rust-lang.org/stable/std/collections/"
  "struct.BTreeSet.html#method.symmetric_difference"
}

The #link("https://docs.rs/imbl/latest/imbl/struct.GenericOrdMap.html#method.diff")[`diff` API]
returns an iterator that outputs the difference between two `OrdMap`s. Normally, doing so would walk
through each pair in both maps#footnote[See the #link(btreeset-diff-impl)[implementation] of
  ```rust BTreeSet::symmetric_difference``` in the Rust standard library.]. However, if two
`OrdMap`s already share most of their contents, the iterator can simply compare the pointers of
their subtrees; if two subtrees have the same address, their contents must be the same.

Summary:
- Merging world state must be done on the main thread, which can be expensive sometimes
- Saving history is now extremely easy as we only need to swap a few pointers
- In the future each undo and redo will be implemented as (World, World) to match multiuser collab

= One Year of Paiagram

I don't have much experience in writing large apps, nor am I familiar with Rust itself. Still, I
found immutable data structures to be the only working solution for Paiagram's case. It is also a
great solution. Of course, there are a lot more that I didn't cover in this post.

I created the first commit on Nov. 4, 2025 PT. Over the last 12 months, I've made all kinds of
changes to the app; though my focus sometimes shifted. I took many detours, including learning Typst
HTML export, making a custom documentation framework, and building more sites --- these will be
covered in a separate post. I enjoyed building, failing, and learning new stuff in the process.

Thank you for reading my blog post.
