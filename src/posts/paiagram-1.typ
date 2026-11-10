#import "../mod.typ": *
#show: wstemplate.with(
  title: "Paiagram 1: World Design",
  description: "Immutable data structures.",
  created: datetime(year: 2026, month: 11, day: 1),
  tags: ("rust", "paiagram"),
  author: jeremy-gao,
)

_This post is part of the series of dev diaries about Paiagram, an application for creating and
visualizing transport timetables. Visit #elink("https://paiagram.com") to try out the app!_

The most difficult part during the development is designing a world model that satisfies all of the
following:

- Fast
- Lightweight, even when I need to use it across multiple threads
- Can be (de)serialized via serde
- Supports undo and redo
- Supports extensions.
- Multiuser collaboration.

These are the reasons why I used immutable data structures. Before discussing immutable data
structures, I want to first talk about the command--source pattern, and why I eventually abandoned
it.

= Overcomplicating the World

I set "performance" as one of the main goals for the world model. At a first glance, there seem to
be many ways to improve the performance, for example structure of arrays. It doesn't waste padding,
is fast to access, and keeps data in hot cache lines. But SoA isn't without its costs.

Structure of arrays (and on an extent, the Entity--Component--System paradigm), is best when the app
frequently accesses homogenous and processes them in batches. This is true for many types of games,
since there might be similar components shared accross different entities. However, this is not true
for Paiagram. Each entity in Paiagram carries its unique set of data, and the components of each
entity are barely shareable. In the previous blog post, I said that I will use Bevy because it is
"the magic trick that makes everything run faster." I removed Bevy six months later because of these
reasons:

- Bevy's entities are not ordered in memory.
- Each query to the ECS require a lot of `.unwrap()`s to get the underlying data type, or at least
  early returns. _Their type also can't be guaranteed by the Type system since each piece of data
  (trip, station, route, notes, etc.) share the same Key type (Entity)_.
- Undo/Redo becomes tedious as it is impossible to insert an old Entity into the World.
- It is a game engine. not a library. It introduces hidden bloat.

= Command and Conquer

All editors have a "world", which is the centralized storage of the current editing state. A text
editor's world would be the current text edit buffer. For Paiagram, it is the trips, routes, nodes,
and intervals that construct the transit network. Inside the editor, the user may perform some
actions, maybe revert them, and do some other stuff. Thus, we can make each action, such as shifting
the departure time of a trip, a command that changes the world.

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

SoA stands for structure of arrays. Conversely, there's also an array of structures, which is the
most common way to store some data. The idea of array of structures is to store the data inside a
big vector, and each datum#footnote[Do we even use this word] would be a structure containing some
fields:

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
total. The reason is #link("https://en.wikipedia.org/wiki/Data_structure_alignment")[explained
  here].

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

And I am going to talk about the pitfalls.

= One Year of Paiagram

I created the first commit on Nov. 4, 2025 PT.
