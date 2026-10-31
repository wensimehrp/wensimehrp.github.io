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
- Lightweight, even when I need to use it accross multiple threads
- Can be (de)serialized via serde
- Supports undo and redo
- Supports extensions, which will be sent from another thread

These are the reasons why I used immutable data structures. Before discussing immutable data
structures, I want to first talk about the command--source pattern, and why I eventually abandoned
it.

= Command and Conquer

All editors have a "world", which is the centralized storage of the current editing state. In a text
editor, it would be the current text edit buffer. For Paiagram, it is the trips, routes, nodes, and
intervals that construct the transit network. Inside the editor, the user may perform some actions,
maybe revert them, and do some other stuff. Thus, we can make each action, such as shifting the
departure time of a trip, a command that changes the world.

I started with the following:

```rust
enum Command {
    AddTrain(...),
    ...
}

impl Command {
    fn act(self, world: World) -> Result<World, World> {

    }
}
```

When it is created, it also produces a countercommand that does the exact opposite, and that
countercommand would be pushed into a undo stack. The command pattern works particularly well when
the application is simple, when there are only a few possible actions

= The Red Alert
