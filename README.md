# Replim
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

replim is the most quick REPL of nim.

# Features

- check value without "echo"
- auto indent
- running on VM

if you assign variable or functions,
you can check those value without typing "echo".

```
>>>var foo = "bar"
>>>foo
bar
>>>proc bar(): string =
...    return "foo"
...
>>>bar()
foo
>>>bar() & ", bar"
foo, bar
```

**Warning**

- Don't use "echo" or "stdout.writeline" for onetime output.  
Since replim isn't an interpreter, it memorises all lines you input. So if you use them, replim will  outputs the result at all time since that.
if you want to outputs for once, you can use "once" instead, or type variable or function as they are.

```
>>>echo "hello"
hello
>>>var a = 1
hello
>>>once "hello"
hello
hello
>>>proc hello() =
...    echo "world"
...
hello
>>>once hello()
hello
world
>>>a = 2
hello
>>>hello()
hello
world
```

- replim can't import librarys that import C library.

```
>>>import nre
..\..\..\..\..\nim-0.xx.x\lib\impure\nre.nim(432, 24) Error: cannot 'importc' variable at compile time
```

# Options

- **:back** : clear last line.
- **:clear** : clear all lines.
- **:quit** : quit this program.
- **:show** : display history.