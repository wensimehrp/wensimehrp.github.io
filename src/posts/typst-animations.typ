#import "../mod.typ": *
#show: wstemplate.with(
  title: "Animations with Typst",
  description: "A.K.A. Typst with FFmpeg, or Tanim.",
  created: datetime(year: 2025, month: 09, day: 14),
  tags: ("Typst", "tools", "FFmpeg"),
  author: jeremy-gao,
)

Typst is a great typesetting tool. It's also great as a drawing tool. Reviewing its history of #{
  datetime.today() - datetime(year: 2019, month: 12, day: 1)
}.days() days, it has evolved from a simple typesetting tool to a powerful tool that can do way more than typesetting
documents alone. The community has developed presentation and poster templates, people are using it to draw #elink(
  "https://github.com/wensimehrp/paiagram",
)[train timetable diagrams] as well as complex mathematical graphs. Despite all these, one thing nobody has done (or at
least I haven't seen anyone doing) is using Typst to create animations.

An animation is a sequence of images. Typst can generate images from Typst code, so in theory, it is possible to
generate an animation using Typst. One of the easiest animations that involve procedural frame generation is a #elink(
  "https://decodeunicode.org/",
)[Unicode character flash animation], which involves displaying each Unicode character one by one -- something in which
its creation process could be simplified to a minimum with the help of a computer. I would be aiming to recreate this
animation in the following sections.

A simple way to create an animation is to first generate all frames as images using a loop or something else that serves
the same purpose #footnote[
  Like a Makefile. Friendship ended with `do while` and `for`, now `make -j` is my best friend.
], then use a tool like FFmpeg to stitch the images together to form a video. The pseudocode goes like this:

```
for idx in 0..=100 {
  typst compile frame.typ -f png frame_{idx}.png
}
ffmpeg frame_*.png output.mp4
```

But this is essentially the same as rendering one frame, and stretching the interval of that frame 100 times --
definitely not what we wanted.

= Typst Inputs

Typst's `input` feature is _bad_. It allows the file to take an input value, and take different actions based on that
value -- non-deterministic!#footnote[
  Use the same words on `datetime.today()`.
] However, in our case, it is the only way to pass the current frame index into the Typst file.

```
$> typst c frame.typ --input t=42
```

Typst offers `sys.inputs` for accessing input values inside the document. All inputs are of string type, so it's
necessary to convert them to numbers first. The following code would render a piece of text that is given by the system
input `i`:

#let a = ```typst
// In case there is no input, `our-text` would be "No input!"
#let our-text = sys.inputs.at("i", default: "No input!")
#our-text
```

#figure(
  caption: [Evaluation result with `--input i="Hello, world!"`],
  a + box(inset: 1em, [Hello, world!]),
)

With this, we can now pass the current frame index into Typst, and use that index as a unique codepoint for rendering
each frame.

= Speeding Up the Process

We have a simple workflow now, but it is very slow. FFmpeg only reports around 2 frames per second on my i9-13900HX
machine. Can we do better? Of course we can.

== Prevent Scanning System Fonts

By default, before rendering the document, Typst would check system fonts and check what glyphs/codepoints are
available. This process takes a significant amount of time to run on my i9-13900HX machine, and it is unreasonable to
let Typst do this for an animation with 60k frames. Luckily, there are two flags that can help:

- `--ignore-system-fonts`: Don't perform the system font check
- `--font-path`: Specify a font path to load fonts from

In my case, I just put the fonts that are required in the same working directory, and use `--font-path ./` to load fonts
from the current directory. The time difference for rendering a single frame is huge:

#figure(
  caption: [
    Performance comparison using `poop`. Here poop is using Typst to compile an early version of the article you're
    reading now. The `min-max` and `outliers` options are stripped away for better readability.
  ],
  ```
  Benchmark 1 (3 runs): typst c typst-animations.typ --features html -
  measurement          mean ± σ           delta
  wall_time          3.11s  ± 16.1ms      0%
  peak_rss           94.1MB ±  150KB      0%
  cpu_cycles         6.51G  ± 11.9M       0%
  instructions       14.5G  ± 14.9M       0%
  cache_references   8.23M  ±  621K       0%
  cache_misses       2.10M  ±  125K       0%
  branch_misses      24.7M  ± 18.2K       0%
  Benchmark 2 (32 runs): typst c typst-animations.typ --ignore-system-fonts --font-path ./ --features html -
  measurement          mean ± σ           delta
  wall_time           157ms ± 4.51ms      ⚡- 95.0% ±  0.2%
  peak_rss           58.7MB ±  411KB      ⚡- 37.6% ±  0.5%
  cpu_cycles          286M  ± 6.24M       ⚡- 95.6% ±  0.1%
  instructions        694M  ± 15.2M       ⚡- 95.2% ±  0.1%
  cache_references   1.33M  ± 70.6K       ⚡- 83.9% ±  2.5%
  cache_misses        274K  ± 83.6K       ⚡- 86.9% ±  5.1%
  branch_misses      2.23M  ± 60.0K       ⚡- 91.0% ±  0.3%
  ```,
)

The first command only runs 3 times over the 5000ms duration, while the second command runs 32 times over the same
duration. That's a 95.0% speedup!

== Multithreading with GNU Parallel

The Typst command part is now fairly fast, yet it's still possible to speed up the process by running multiple Typst
commands in parallel.

#elink("https://www.gnu.org/software/parallel/")[GNU Parallel] is the perfect tool for this job. It can take a list of
items, and run a set of commands for each item in parallel. This tool is written in Perl. That being said, it is good
enough to spawn a lot of processes and organize them.

```bash
seq 0 100 | parallel typst c flash.typ --input t={} -f png {}.png
```

Yet, this still has a problem: images are huge to store on the disk, not to mention that we are generating 60k images.
We could definitely do better.

== The POSIX Pipe

The naive approach involves writing to the disk, for FFmpeg would later read from the disk. Yet disk I/O is slow,
writing lots of small images to the disk is even slower.

A better approach is to use a pipe. A pipe redirects the standard output of the first command to the second command's
standard input. Both the standard input and output take place in memory, and memory I/O is magnitudes faster than disk
I/O.
#footnote[
  It's also possible to create a ramdisk or a tmpfs for this purpose, but for our scenario the pipe is sufficient. A
  tmpfs in this case is just an overkill. But don't worry, we'll talk about tmpfs later.
]
Take `ls -l | grep foo` as an example:

- `ls` lists all files in the current directory, and writes the output to its standard output (stdout)
- The pipe (`|`) redirects the stdout of `ls` to the standard input (stdin) of `grep`
- `grep` reads from its stdin, and filters the lines that contain `foo`, then writes the result to its stdout

Pipes are fast and instant. Once the first command produces output, the output is immediately sent to the second
command. There is no need to wait for the first command to finish in the first place, both commands can _run
concurrently_. FFmpeg, for example, can start encoding the video as soon as it receives input from its standard input.

Another cool feature about pipes is that if the second command cannot consume the input fast enough, the first command
is automatically paused until the second command digests the input. This prevents memory overflow, and saves CPU cow
power.

Naturally, for such a workflow, writing everything to the disk is not necessary. Taken the code from above, we can
modify it to:

```bash
seq 0 100 | \
  parallel typst c flash.typ --input t={} -f png - | \
  ffmpeg -f image2pipe -vcodec png -i - output.mp4
```

Notice that the pipe is not redirecting the output of the `typst` command, rather, it is redirecting the output of
`parallel`. This is because we want to pipe the output of all `typst` commands to `ffmpeg`, not just one of them.

However, this introduces a new problem: how to make sure that the pipe would pipe out images in order? The previous
approach would execute multiple Typst commands in parallel, and the output of each command is written to disk. Since
FFmpeg reads from the disk, the order is guaranteed. Yet, now that we are piping the output of Typst commands (that are
organized by `parallel`) to FFmpeg, and each Typst job might finish at different times, it seems that the order is not
guaranteed anymore.

Just kidding. GNU Parallel's `-k` or `--keep-order` flag guarantees that the output of each command is in the exact
order as the input. Now after adding the `-k` flag, we have a script that goes like this:

```bash
seq 0 100 | \
  parallel -k typst c flash.typ --input t={} -f png - | \
  ffmpeg -f image2pipe -vcodec png -i - output.mp4
```

== Storing Assets in Memory

During compilation, Typst would read assets (fonts, images, code, etc.) from the disk. As discussed above, disk I/O is
slow, yet memory I/O is fast. To speed up the process furthermore, we can first store all assets in memory, then invoke
Typst and let it read assets from memory instead of the disk.

A `tmpfs` is a filesystem that is located inside the memory -- exactly what we need. Because it is located inside the
memory, I/O operations on a `tmpfs` are way faster than on a regular disk. The following commands create a `tmpfs` that
is 256MB in size:

```bash
sudo mkdir /mnt/mytmpfs
sudo mount -t tmpfs -o size=256M tmpfs /mnt/mytmpfs
```

Ok, so are we copying all assets to that `/mnt/mytmpfs` directory? No, we are not.

Major Linux distributions such as Fedora and Ubuntu usually provide a space called the Shared Memory, mounted at
`/dev/shm`#footnote[
  Some distributions might have `/tmp` mounted as a tmpfs. Nontheless, it's not always guaranteed that `/tmp` is a
  tmpfs. To illustrate, my NixOS laptop has `/tmp` as a regular disk, so it's better to use `/dev/shm`.

  Also, sorry, Mac, BSD, and Windows users! This part doesn't apply to all of you.

  Well, OpenBSD is an exception here, traitor... ;P

  Disclaimer: I don't have a Mac, BSD, or Windows machine, so I cannot test.
]. This space is a `tmpfs` that is shared among all users and processes. In this case, there's no need to create a new
`tmpfs`, all we have to do is to just copy the assets to `/dev/shm` and let Typst read from there.

```bash
cp -r ./assets /dev/shm/animation
# and from this step on, let Typst read assets from /dev/shm/animation
```

== The Final Script

With all those modifications, here is our final script with some additional FFmpeg flags:

```bash
#!/usr/bin/env bash
set -euo pipefail

FPS=24
END=0xFFFF
OUTPUT="tanim.mkv"
INPUT="flash.typ"

# preload all assets from `assets` into RAM
mkdir -p /dev/shm/tanim
cp -r assets/* /dev/shm/tanim/

# Here I've instructed FFmpeg to use the NVENC hardware encoder. It's only available
# on NVIDIA GPUs. If you don't have an NVIDIA GPU, just replace `h264_nvenc` with `libx264`.
seq 0 $((END)) | parallel -k \
  typst c "/dev/shm/tanim/$INPUT" \
    --input t={} \
    --ignore-system-fonts \
    --ppi 120 \
    --font-path /dev/shm/tanim/ \
    -f png \
    - | \
  ffmpeg -y -f image2pipe \
    -vcodec png \
    -framerate "$FPS" \
    -i - \
    -i /dev/shm/tanim/music.mp3 \
    -map 0:v:0 -map 1:a:0 \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
    -af "loudnorm=I=-16:LRA=7:TP=-1.5" \
    -c:v h264_nvenc -preset medium -crf 23 -threads 0 \
    -c:a aac -b:a 192k \
    -shortest \
    "/dev/shm/$OUTPUT"

# copy final output to current directory
cp "/dev/shm/$OUTPUT" ./

# clean up
rm -rf /dev/shm/tanim
rm -f "/dev/shm/$OUTPUT"

```

= Potential Speedups

Typst is already pretty fast at rendering documents, yet, on the one hand, the PNG format is costly to both encode and
decode. Using a different format such as `rgb`, `bmp`, or `qoi` would accelerate the process even more. Yet Typst
doesn't even support JPEG yet, so I think that would take a while to happen.

Some may note that Typst also supports SVG output, and FFmpeg also supports SVG input. However, FFmpeg's SVG is based on
disk files, and piping from Typst to FFmpeg would not work. Outputting to SVG and using ImageMagick to convert SVG to
RGB would work in theory, yet I've tried and somehow it failed for me. If you managed to make it work, please let me
know!

On the other hand, even though we are running everything in parallel, Typst itself only runs on the CPU. Making Typst
GPU-accelerated would be a huge improvement, yet it is not something that can be done easily.

Lastly, it could be possible to get rid of `parallel` entirely -- Typst itself is multithreaded, just that it doesn't
support outputting raster images to the standard output. If Typst supports this feature, we could just run the Typst
command once, let Typst handle the multithreading part and organize the images, then pipe that to FFmpeg. This
eliminates not just the overhead of `parallel`, but also the overhead of cold-booting Typst 60k times.#footnote[
  Reviewing this part I realized that I missed a critical part in letting Typst handle parallelism: Typst provides
  `state`, `counter`, and `query` for querying the state of the current documentation. The query goes two ways in time
  -- time travelling. It is definitely possible and valid for an earlier frame to query the state of a later frame. This
  means that if any of those `foo-state.final()` code is involved, Typst would have to first store all 65k frames in
  memory, then resolve all queries, then pipe all frames out. The extra memory burden is definitely not what we want.
]#footnote[
  I know that someone is working on a Rust implementation of this animation thingy using Typst as a crate and rayon for
  parallelism. I haven't tried it yet (I am not that good at rust, and it is really a cult), but it seems promising.
]

= This Does Not Work in Nushell!

Well, it's a bit of an overexaggeration to say that it cannot work at all in Nushell. I am talking about the `par-each`
command in Nushell, that takes a list of items and passes them into a closure, and runs the closures in parallel. The
problem is not parallelism, neither the closure itself, but the fact that Nushell would collect the output of all
closures first, then pipe them into the next command. In our case there are 60k frames, and collecting all of them would
take a lot of memory and time.

Compared to GNU Parallel, `parallel` would start piping the output of each command immediately, doesn't need to wait for
all commands to finish. As soon as there are output from one command, it would be piped into the next command
immediately, which, in our case, is FFmpeg. This saves memory, and also allows two sets of commands to run concurrently.

= The Proper Engine That Actually Uses Typst

Okay, I hereby admit that I've just created the most advanced frame-by-frame animation engine *Tanim*!

Jokes aside, what we've now discussed are only the elementary steps of building an animation engine. A real engine
#footnote[
  Manim is indeed a great example, but Adobe Flash... is also not bad :P.
]
involves much more than simple frame-by-frame rendering. And this linear workflow simply composed using Typst and FFmpeg
cannot be sufficient for a real animation engine.

There is one engine, #elink("https://github.com/jkjkil4/JAnim")[JAnim], that actually uses Typst. It doesn't use Typst
to render each frame, but to invoke Typst at runtime for elements (text, arbitrary shapes and graphs, and math formulas)
that can be used by the engine.

= Not Really a Conclusion

Here's #elink("https://www.bilibili.com/video/BV1HVpWz3Epi")[
  unicode character display video
] #footnote[
  I know that some people might have problems playing Bilibili videos, but let's just keep that for now. I don't want to
  post it on YouTube yet.
]I made using the command given above. It has a bit less than 65536 frames -- 63488 to be exact, due to the fact that
some Unicode codepoints in this range are invalid. Some codepoints are not defined, some are not displayable, some are
just in the private use area, so the video doesn't reflect the actual Unicode standard. Nevertheless, I think this would
be a good starting point for anyone who wants to create animations using Typst. Enjoy!

#context if target() == "html" {
  html.elem("iframe", attrs: (
    src: "//player.bilibili.com/player.html?isOutside=true&bvid=BV1HVpWz3Epi",
    scrolling: "no",
    border: "0",
    frameborder: "no",
    framespacing: "0",
    allowfullscreen: "true",
    class: "w-full aspect-video",
    loading: "lazy",
  ))
} else [
  Unfortunately video embedding only works on the web version of this article. But you can visit the link above to watch
  the video.
]
