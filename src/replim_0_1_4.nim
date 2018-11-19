import strformat
import strutils
import osproc
import nre
import os

{.push checks:off.}

const
    version = "0.1.3"
    date = "Nov 17 2018, 20:09:00"
    message = fmt"""
Replim {version} (default, {date}) [{hostOS}, {hostCPU}]
    :back : clear last line.
    :clear : clear all lines.
    :quit : quit this program.
    :show : display history.
"""
    initcode = """
import typetraits
template on_ce(state: void): void = discard
template on_ce[T: not void](arg: T): void =
    echo arg
template on_ce(args: varargs[untyped]): void =
    echo args
template on_ce[T: type](arg: T): void =
    echo arg
"""
    keywords = [
        "import", "using", "macro", "template", "return"
    ]
    blockKey = [
        "case"
    ]
    assnKey = [
        "var", "let", "const", "proc", "type"
    ]

var
    nowblock = 0
    pastblock = 0
    code = initcode

proc escape(s: var string) =
    s = s.replace(re".\[D", "").replace("[", "")

proc blockStart(s: string): bool =
    if s.endsWith(":") or s.endsWith("=") or s.startsWith("type "):
        return true
    for key in blockKey:
        if s.startsWith(key):
            return true
    for assn in assnKey:
        if s == assn:
            return true
    return false

proc delLine() =
    var codelines = code.split("\n")
    codelines.del(codelines.high-1)
    code = codelines.join("\n")

proc delOnce() =
    code = code.replace(re"once.*", "")
    var rep = code.replace(re".*:\n *\n", "\n")
    while code != rep:
        code = rep
        rep = code.replace(re".*:\n *\n", "\n")

proc `*`(a: string, times: int): string  =
    result = ""
    if times == 0:
        return result
    for i in countup(1, times):
        result = result & a


proc main() =
    echo message
    while true:
        if nowblock > 0:
            stdout.write("...")
            for i in countup(1, nowblock):
                stdout.write("    ")
        else:
            stdout.write(">>>")
        stdout.flushFile()

        var order = stdin.readLine()
        if order.startsWith("quit") or order == ":quit":
            break
        case order
        of ":show":
            echo "code:\n", code.replace(initcode, "")
            continue
        of ":clear":
            nowblock = 0
            pastblock = 0
            code = initcode
            continue
        of ":back":
            delLine()
            nowblock = pastblock
            continue
        # for debuging
        of ":save":
            let f = open("repl.nims", fmWrite)
            f.write(code)
            f.close()
            continue
        of "":
            nowblock -= 1
            if nowblock == 0:
                let errc = execCmd("nim e -r --verbosity:0 --checks:off --hints:off repl.nims")
                if errc != 0:
                    delLine()
                    nowblock = pastblock
                else:
                    delOnce()
            continue
        else:
            pastblock = nowblock
            if assnKey.find(order.split(" ")[0]) == -1 and order.find("=") == -1 and keywords.find(order.split(" ")[0]) == -1 and order.match(re"\{\..*\.\}").isNone:
                if order.high >= 1 and not order.endsWith(":"):
                    if order.split(":").len != 2:
                        order = fmt"once({order})"
                else:
                    if not order.endsWith(":"):
                        order = fmt"once({order})"
            code &= ("  " * nowblock) & order & "\n"
            code.escape()

            let f = open("repl.nims", fmWrite)
            f.write(code)
            f.close()

            if blockStart(order):
                nowblock += 1

            if nowblock == 0:
                let errc = execCmd("nim e -r --verbosity:0 --checks:off --hints:off repl.nims")
                if errc != 0:
                    delLine()
                    nowblock = pastblock
                else:
                    delOnce()


if isMainModule:
    main()
