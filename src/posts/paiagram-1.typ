#import "../mod.typ": *
#show: wstemplate.with(
  title: "Paiagram 1: World Design",
  description: "Immutable data structures.",
  created: datetime(year: 2026, month: 10, day: 31),
  tags: ("egui", "rust", "paiagram"),
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
  changing another command's internals.

:-(. I did something else that made it even worse.

= Overcomplicating the World

After abandoning Bevy...

= The Red Alert

Paiagram has a few core components.
