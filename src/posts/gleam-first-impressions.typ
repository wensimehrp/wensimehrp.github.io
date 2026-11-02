#import "../mod.typ": *
#show: wstemplate.with(
  title: "First Impressions with Gleam",
  description: "Functional programming sounds interesting!",
  created: datetime(year: 2026, month: 11, day: 1),
  author: jeremy-gao,
)

I knew Gleam when doomscrolling through GitHub feeds#footnote[Evil service] on a random day during
grade 11 or grade 12#footnote[When I was in Vancouver. It is so cold here!]. I basically set the
`Language: Rust` filter and looked for interesting projects -- that was also how I discovered Typst,
by the way.

I went into university after I graduated from high school. My first CS course in university was
about functional programming#footnote[Although the professor used Python with a lot of custom
  modules instead of a proper functional programming language e.g. Haskell or something else. I'd
  argue that Python is one of the worst options for an FP course because 1. it has the weird LEGB
  thingy for variable scopes and 2. everything in Python is shareable and mutable. It's not meant to
  be FP!
], Although I knew much of the content the forehand by writing other projects in Rust and Typst. I
decided to learn Gleam to learn more about functional programming beyond the course's contents.

= QOI Decoder in Gleam

The #link("https://qoiformat.org/")[QOI image format] is simple and very fast to decode. #link(
  "https://qoiformat.org/qoi-specification.pdf",
)[Its entire specification fit in a single page], and its C reference implementation is only \~600
lines with comments and explanation. An image decoder takes a byte stream and outputs an RGB(A)
image, or some other gibberish if it fails to decode. QOI files start with a header and carry a
payload. The payload ends with an ending mark, and whatever coming after the ending mark is unknown
territory.

My first step was writing the function to separate the header from the payload. Gleam also
conveniently provides the ```gleam BitArray``` type, which can contain arbitrary binary data, and it
has dedicated construction syntax using less-than and greater-than signs: `<< >>`:

```gleam
fn decode_qoi(data: BitArray) -> Result(#(
  Int, // width
  Int, // height
  Int, // channels
  Int, // colorspace
  BitArray // RGBA buffer
), Nil) {
  case data {
    <<
      "qoif":utf8,
      width:unsigned-big-size(32),
      height:unsigned-big-size(32),
      channels:unsigned-big-size(8),
      colorspace:unsigned-big-size(8),
      data:bytes,
    >>
      if { channels == 3 || channels == 4 }
      && { colorspace == 0 || colorspace == 1 }
    -> {
      decode_qoi_payload(data, Pixel(0, 0, 0, 0) |> list.repeat(64), <<0, 0, 0, 255>>)
      |> result.map(fn(data) { #(width, height, channels, colorspace, data) })
    }
    _ -> Error(Nil)
  }
}
```

The language forces the programmer to specify the types in function definitions, which help prevent
a lot of bugs before running the code, although I was lazy and wrote four ```gleam Int```s instead
of defininig a dedicated ```gleam QoiImage``` type.

Pattern matching was absolutely gorgeous. Aside from matching list element and strings, Gleam also
supports matching bits and bytes in ```gleam BitArray```s, and can automatically convert integers
from different endians, or different widths. The only things that I feel missing are
```rust if let``` and ```rust let {..} else { .. }``` from Rust.

The next step was writing the payload decoder. Let's first take a look at the function signature:

```gleam
fn decode_qoi_payload(
  data: BitArray,
  lookup: List(Pixel), // lookup table required for a codec
  acc: BitArray,
) -> Result(BitArray, Nil) {}
```

The function starts with an initial state (`acc`), builds up the state as it progresses, and bites a
bite of bytes from `data` on each run. Its return value is either a complete BitArray containing the
decoded RGBA buffer, or an error (in this case it is empty).

Inside the function, we match the bytes and progress to the next step or stop.

```gleam
case data {
  // end of stream
  <<0:size(56), 1:size(8), _rest:bytes>> -> Ok(acc)
  // QOI_OP_RUN
  <<0b11:size(2), run_length:unsigned-size(6), rest:bytes>> -> {
    let assert Ok(prev_px) = get_prev_pixel(acc)
    decode_qoi_payload(rest, lookup, <<
      acc:bits,
      { prev_px |> list.repeat(run_length + 1) |> bit_array.concat }:bits,
    >>)
  }
  // Other codecs and the error case are omitted for simplicity
}
```

There are exactly two branches in this simplified implementation. In this example, the data either
matches the end of stream marker, or it matches `QOI_OP_RUN`. If it matches end of stream, it
immediately exits and returns `Ok(acc)`, where `acc` is the accumulated RGBA buffer. If it matches
`QOI_OP_RUN` instead, it gets the previous pixel, concatenates a new buffer by taking the
accumulated RGBA buffer and appending the previous pixel for `run_length` times, and passes the
buffer, as well as the rest of the data, and the lookup table into the same function.

There are no `for` or `while` loops in this decoder, and ```gleam fn decode_qoi_payload``` simply
translates the state then processes the translated state using the same procedure.

= Conclusion

This is my first project in a functional programming language. The full project is at
https://github.com/wensimehrp/gleam_fun_qoi. After trying the language and the paradigm, I think it
is a relatively smart way to eliminate bugs (by removing mutable states) and reducing workload.

Thank you for reading my blog post.
