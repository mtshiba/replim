# Replim
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://travis-ci.org/gmshiba/replim.svg?branch=master)](https://travis-ci.org/gmshiba/replim)
[![nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://github.com/yglukhov/nimble-tag)

replim is the most quick REPL of nim.

# DEMO

![demo](demo/replim.gif)

# Installation

if you have installed Nim already, that's easy:

```
nimble install replim
```


# Features

- checking value without "echo"
- auto indent
- running on VM

if you assigned variable or functions,
you can check those value without typing "echo".

```
>>>var foo = "bar"
>>>foo
bar
>>>proc bar(): string =
...    return "foo"
...
>>>echo bar()
foo
>>>bar()
foo
>>>bar() & ", bar"
foo, bar
```

**Warning**

- replim can't import librarys that import C library at present.

```
>>>import nre
..\..\..\..\..\nim-0.xx.x\lib\impure\nre.nim(432, 24) Error: cannot 'importc' variable at compile time
```

# Options

- **:back** : clear last line.
- **:clear** : clear all lines.
- **:quit** : quit this program.
- **:show** : display history.
