---
date: 2020-03-17T21:10:59+13:00
title: Wasm bits and bobs
---

## Background

I've been dabbling with Wasm for several years, but only really started going
at it in the past month, and for the purposes of this post, for the past two
weeks. I had [a bad idea] and I've been [working] to [make] it [real].

I'm not coming from the JS-and-Wasm perspective. Some of the things here might
be relevant, but here I'm mostly talking from the point of view of writing a
Wasm-engine-powered integration, not writing Wasm for the web and not
particularly writing Wasm at all even.

For those who don't know me, I work (as a preference) primarily in Rust, and I
work (for money) primarily in PHP, JS, Ruby, Linux, etc. Currently I'm in the
telecommunication industry in New Zealand.

[a bad idea]: https://twitter.com/passcod/status/1236558663269208066
[working]: https://twitter.com/passcod/status/1237983212212760577
[make]: https://twitter.com/passcod/status/1238371837442002944
[real]: https://github.com/passcod/slicism


## The wasm text and bytecode format

One very interesting thing that I like about wasm is that the text format, and
to a certain extent the bytecode, is an s-expression. Instructions are the
usual stack machine as seen e.g. in assembly. But the structure is all
s-expressions. Perhaps that's surprising and interesting to me because I'm not
intimately familiar with other binary library and executable formats...
[fasterthanlime's ELF exploration is still on my to-read list][ftl-elf].

The standard wasm tools come with `wat2wasm` and `wasm2wat`, which translate
between the bytecode (wasm) and text (wat) formats. `wat2wasm` will produce
simple yet nice errors if you write wrong wat.

My _preferred_ way of writing small wasm programs is to write the wat directly
instead of using a language on top. I am fairly comfortable with stack
languages (I have a lingering fondness for `dc`) and a lot of the work involves
more interacting with wasm structure than it does the behaviour of a module. To
write larger programs, especially those dealing with allocations, I use Rust
with [`wee_alloc`], optionally in `no_std` mode. I do not use wasm rust
frameworks such as wasm-pack or wasm-bindgen.

I have tried [AssemblyScript], I am not interested in C and family, and that's
pretty much the extent of my options as much of everything else either embeds
an entire runtime or is too high level or is too eldritch, [wildly
annoying][go], or unfamiliar.

[ftl-elf]: https://fasterthanli.me/blog/2020/whats-in-a-linux-executable/
[`wee_alloc`]: https://github.com/rustwasm/wee_alloc
[AssemblyScript]: https://github.com/AssemblyScript/assemblyscript
[go]: https://fasterthanli.me/blog/2020/i-want-off-mr-golangs-wild-ride/


## The wasm module system

There is an assymmetry in the module system that... makes sense to anyone who's
used language-level module systems but might not be immediately obvious when
approaching this in the context of dynamic libraries.

There are four types of exports and imports: functions, globals (i.e. constants
and statics), memories, tables (which I don't concern myself with).

While engines do support all types fairly well, languages targetting Wasm often
only support functions well. It's not uncommon to initially start with an
integration that expects an exported global, only to then change it to a
function that's read on init and documented to need a constant output, because
some desired language doesn't support making wasm globals.

Wasm has the concept of _multiple_ linear memories, and of exportable and
importable memories. Currently, the spec only supports one memory, which can
either be defined in the module or imported (defined elsewhere, including some
other module). In theory and/or experiments, most languages also only support a
single memory, or only support additional memories as addressable blobs of
data. C &co, with manual memory management, can in theory allocate anywhere,
and so may be better off... Rust's [AllocRef] nightly feature shows promise to
be able to specify the allocator for some data, and therefore be able to
configure multiple allocators each targeted at a different memory. However,
that will require multiple memory support at the (spec and then) language level
in the first place. For now, designing integrations to handle more than one
memories is not required but a good future-proofing step.

Exports are straightforward: each export has a name and maps to some entry in
the module's index spaces. Once you compile a module from bytecode you can look
up all of its exports and get the indices for the names. This is important
later.

Imports have _two_-level names: a namespace and a name. The idea is for
integrations to both be able to provide multiple libraries of imports without
clashes, and to support plugging one module's exports directly to another
module's imports, presumably namespaced under the first module's name, version,
some random string, etc.

In practice there are two namespaces worth knowing about: `env` is the de-facto
default namespace, and `js` is the de-facto namespace for web APIs.

In Rust, to specify the import namespace (defaults to `env`), you need to use
the `#[link(wasm_import_namespace = "foo")]` attribute on the extern block like
so:

```rust
#[link(wasm_import_namespace = "log")]
extern {
   fn trace(mem: i32, ptr: i32, len: i32);
   fn debug(mem: i32, ptr: i32, len: i32);
   fn info(mem: i32, ptr: i32, len: i32);
   fn warn(mem: i32, ptr: i32, len: i32);
   fn error(mem: i32, ptr: i32, len: i32);
}
```

[AllocRef]: https://doc.rust-lang.org/nightly/std/alloc/trait.AllocRef.html


## Functions calls

In the [wasmer] runtime, which is what I've most experience with, there are two
contexts to call exported functions in: on an `Instance`, that is, once a
compiled module is instantiated (we'll come back to that), and from a `Ctx`,
that is, from inside an imported function call. The first is highly ergonomic,
the other not very (this will probably improve going forward, there's no reason
not to).

```rust
let func: Func<(i32, i32)> = instance.func("foo_functer")?;
let res = func.call(42, 43)?;
```

To call from a `Ctx`, the best way currently is to pre-emptively (before
instantiating) obtain the indices of the exported functions you want to call
from the compiled module, and then call into the `Ctx` using those indices:

```rust
// after compiling, with a Module
let export_index = module
    .info()
    .exports
    .get("foo_functer")
    .unwrap();

let func_index = if let ExportIndex::Func(func_index) = export_index {
    unsafe { std::mem::transmute(*func_index) }
} else {
    panic!("aaah");
}

// inside an imported function, with a Ctx
let foo = 42;
let fun = 43;

let res = ctx.call_with_table_index(
    func_index,
    &[WasmValue::I32(foo as _), WasmValue::I32(fun as _)],
)?;
```

[wasmer]: https://wasmer.io


## Instantiation and the start section

Wasm modules can contain a `start` section, which can **absolutely not** be
thought of like a `main` function in C and Rust: code that runs directly,
without being called via an exported function.

The `start` section is run during the instantiation sequence.
If there's no `start` section, it's not called, simple as that.

Now, wasm people will insist that the `start` section is a compiler detail that
should absolutely not be used by common plebeians or for programs and such,
that it's useless anyway because it runs before "the module" and "exports" are
available, and that implicitely `export`ed functions rely on the `start` having
been run, so you really shouldn't use this for anything...

Anyway, you can't generate it.

And fair enough. I'm sure they know their stuff and they have good reasons.

**However**. The instantiation process for Wasm is [precisely defined][w-i].
*After* this process, the module is ready for use. Wonderful. **The `start`
section is called as the very last step of the instantiation process.**

So while the official advice is to have some export named, e.g. `main` or
something and then having the runtime call this export straight away, if you
want to deliberately flout the guidelines, _you probably can_. You can totally
use the instantiation of a module as a kind of glorified function call.

It's most certainly a bad idea... but you can.

Given that nothing will generate this for you, you'll need to post-process the
wasm to add the `start` section in yourself. A small price to pay.

[w-i]: https://webassembly.github.io/spec/core/exec/modules.html#exec-instantiation


## Types

People usually start with that, but it's kind of an implementation detail in
most cases, and then they leave it at that... there's some good bits there,
though.

As a recap, Wasm at the moment has 2×2 scalar types: signed ints and floats,
both in 32 and 64 bit widths, plus one 128-bit vector type for SIMD (when
supported).

To start with, you can't pass 128-bit integers in using v128. Good try!

The wasm pointer size wasm is 32 bits. Period. There's no wasm64 at this point.
If you're writing an integration and need to store or deal with pointers from
inside wasm, don't bother with usize and perhaps-faillible casts, use u32 and
cast up to usize when needed (e.g. when indexing into memories). Then pop this
up in your code somewhere to be overkill in making sure that cast is always
safe:

```rust
#[cfg(not(any(target_pointer_width = "32", target_pointer_width = "64")))]
compile_error!("only 32 and 64 bit pointers are supported");
```

When engines have magical support for unsigned and smaller width integers,
that's all convention between the two sides. `u8` and `i16` and `u32` are cast
to 8, 16, or 32 bits, padded out, given to wasm as an "`i32`", and then the
inner module re-interprets the bits as the right type... if it wants to. Again,
it's all convention. Make sure everything is documented, because if you pass
–2079915776 (`i32`) and meant 2215051520 (`u32`), well, who could have known?


## There may be more

but that's all I can think of for now.
