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
- Supports extensions. Ideally we want the data to be shared with another thread
- Multiuser collaboration, in the future.

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
- It is a game engine. Not a library.

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
    AddTrain(...),
    RemoveTrain(...)
    ...
}

impl Command {
    fn act(self, world: World) -> Result<Command, E> {
        // in this case E is some generic error type
        use Command::*;
        match self {
            AddTrain(...) => Ok(RemoveTrain(...)),
            RemoveTrain(...) => Ok(AddTrain(...)),
        }
    }
}
```

Each command produces a countercommand that does the exact opposite when being committed, and that
countercommand would be pushed into a undo stack. The command pattern works particularly well, and
doesn't require an extra `undo` method. But applications grow and get complicated every, and
manually wiring each command to a counter command introduces _a lot_ of bugs. There are more
drawbacks to commands in general:

- It is easy to lose cached states, and the countercommand must store cached data accordingly.
- Some command variant might be huge. Though this could be solved by wrapping the variant in a Box.
- Changing the internal representation of one command meaning rewriting the mapping logic and
  changing another command's internals. A lot of the logic is already available somewhere else in
  the codebase, and the command system is just duplicating them.

:-(. I did something else that made it even worse.

= One Year of Paiagram

I created the first commit on Nov. 4, 2025 PT.
