import terminal
# import colors
import strformat
import strutils
import osproc
import nre
import os

{.push checks:off, optimization: speed.}

const
    version = "0.2.3"
    date = "Dec 25 2020"
    message = fmt"""
Replim {version} (default, {date}) [{hostOS}, {hostCPU}]
    :back : clear the last line.
    :clear : clear all lines.
    :quit or :exit : quit replim.
    :display : display the history.
"""
    initcode = """
template on_ce(state: void): void = discard
template on_ce[T: not void](arg: T): void =
    echo arg
template on_ce(args: varargs[untyped]): void =
    echo args
"""
    keywords = [
        "import", "from", "using", "macro", "template", "return", "discard", "once"
    ]
    blockKey = [
        "case"
    ]
    assnKey = [
        "var", "let", "const", "proc", "type", "func"
    ]
    cache_dir = getHomeDir() & "/.replimcathe"
    exec_cmd = "nim e -r --checks:off --hints:off " & cache_dir & "/repl.nims"

type BlockKind = enum
    Main
    Proc
    Func
    Temp
    Macro
    For
    If
    Elif
    Else
    Case
    Of
    While
    Block
    Assn
    Type
    Other

type Replim = object of RootObj
    nowblock: seq[BlockKind]
    pastblock: seq[BlockKind]
    code: string

proc escape(s: var string) =
    s = s.replace(re".\[D", "").replace("[", "")

proc save(self: Replim) =
    let f = open(cache_dir & "/repl.nims", fmWrite)
    f.write(self.code)
    f.close()

#[proc canContainEcho(blockkind: seq[BlockKind]): bool =
    if blockkind.len() == 1:
        return false

    if blockkind[1] == Proc or blockkind[1] == Temp or blockkind[1] == Macro:
        return true
    else:
        return false
]#

proc `*`(a: string, times: int): string  =
    result = ""
    if times == 0:
        return result
    for i in countup(1, times):
        result = result & a

proc delLine(self: var Replim) =
    var codelines = self.code.split("\n")
    codelines.del(codelines.high-1)
    self.code = codelines.join("\n") & "\n"

proc delOnce(self: var Replim) =
    # Unfortunataly, using regex in 'multiReplace' is impossible.
    self.code = self.code.replace(re"once.*", "")
    self.code = self.code.replace(re"case.*\n\n", "\n")
    self.code = self.code.replace(re"\n\nelse:\n( .*)*\n", "\n\n")
    var rep = self.code.replace(re".*:\n *\n", "\n")
    while self.code != rep:
        self.code = rep
        rep = self.code.replace(re".*:\n *\n", "\n")

proc isContinueBlock(blockkind: seq[BlockKind]): bool =
    if blockkind.find(If) != -1 or blockkind.find(Elif) != -1 or blockkind.find(Case) != -1:
        return true
    return false

proc orderType(self: Replim, order: string): string =
    if order.match(re"\{\..*\.\}").isSome:
        return "pragma"
    elif blockKey.find(order.split(" ")[0]) != -1:
        return "case"
    elif order.split(" ")[0] == "of":
        return "of"
    elif assnKey.find(order) != -1:
        return "assnblock"
    elif keywords.find(order.split(" ")[0]) != -1:
        return "keystatement"
    elif order.endsWith(":"):
        if order == "else:" and self.nowblock.find(Case) != -1:
            return "caseelse"
        else:
            return "block"
    elif order.endsWith("="):
        return "statement"
    elif assnKey.find(order.split(" ")[0]) != -1:
        return "expression"
    elif order.match(re".*=.*").isSome:
        return "expression"
    else:
        if self.nowblock.find(Proc) != -1 or self.nowblock.find(Assn) != -1 or self.nowblock.find(Type) != -1:
            return "expression"
        else:
            return "oncecall"

proc newReplim(): Replim =
    if not dirExists(cache_dir):
        createDir(cache_dir)
    result.nowblock = @[Main]
    result.pastblock = @[Main]
    result.code = initcode
    return result

proc main() =
    var vm = newReplim()
    echo message
    while true:
        if vm.nowblock.len > 1:
            stdout.write("...")
            for i in countup(1, vm.nowblock.len-1):
                stdout.write("    ")
        else:
            if vm.pastblock.isContinueBlock():
                stdout.write("...")
            else:
                stdout.write(">>>")
        stdout.flushFile()

        var order = stdin.readline()
        case order
        of ":quit", ":q", ":exit", ":e":
            break
        of ":display", ":d":
            echo "block: ", vm.nowblock
            echo "code:\n", vm.code.replace(initcode, "")
            continue
        of ":clear", ":c":
            vm.nowblock = @[Main]
            vm.pastblock = @[Main]
            vm.code = initcode
            continue
        of ":back", ":b":
            vm.delLine()
            vm.nowblock = vm.pastblock
            continue
        # for debuging
        of ":save", ":s":
            vm.save()
            continue
        of "":
            if vm.nowblock[^1] == Of:
                discard vm.nowblock.pop
                continue
            if vm.nowblock != @[Main]:
                discard vm.nowblock.pop
            if vm.nowblock.len == 1 and not vm.pastblock.isContinueBlock():
                let (outs, errc) = execCmdEx(exec_cmd)
                if errc == 0:
                    echo outs
                    vm.delOnce()
                else:
                    stdout.styledWrite(fgRed, "Error: ")
                    stdout.write(outs.replace(re"repl.nims\((.*)\) Error: ", "") & "\n")
                    stdout.flushFile()
                    vm.delLine()
                    vm.nowblock = vm.pastblock
            continue
        else:
            vm.pastblock = vm.nowblock
            case orderType(vm, order)
            of "oncecall":
                order = fmt"once({order})"
            of "case":
                vm.code &= "  " * (vm.nowblock.len() - 1) & order & "\n"
                vm.code.escape()
                vm.save()
                continue
            of "of":
                vm.code &= "  " * (vm.nowblock.len() - 1) & order & "\n"
                vm.code.escape()
                vm.save()
                vm.nowblock.add(Of)
                continue
            of "caseelse":
                vm.nowblock = @[Main, Else]
                vm.code &= order & "\n"
                vm.code.escape()
                vm.save()
                continue
            else:
                discard

            vm.code &= "  " * (vm.nowblock.len() - 1) & order & "\n"
            vm.code.escape()
            vm.save()

            if order.endsWith(":") or order.endsWith("="):
                case order.split(" ")[0]
                of "proc":
                    vm.nowblock.add(Proc)
                of "func":
                    vm.nowblock.add(Func)
                of "template":
                    vm.nowblock.add(Temp)
                of "macro":
                    vm.nowblock.add(Macro)
                of "for":
                    vm.nowblock.add(For)
                of "if":
                    vm.nowblock.add(If)
                of "elif":
                    vm.nowblock.add(Elif)
                of "else":
                    vm.nowblock.add(Else)
                of "while":
                    vm.nowblock.add(Elif)
                of "block":
                    vm.nowblock.add(Block)
                of "var":
                    vm.nowblock.add(Assn)
                of "let":
                    vm.nowblock.add(Assn)
                of "const":
                    vm.nowblock.add(Assn)
                of "type":
                    vm.nowblock.add(Type)
                else:
                    vm.nowblock.add(Other)

            if vm.nowblock.len() == 1 and not vm.pastblock.isContinueBlock():
                let (outs, errc) = execCmdEx(exec_cmd)
                if errc == 0:
                    echo outs
                    vm.delOnce()
                else:
                    stdout.styledWrite(fgRed, "Error: ")
                    stdout.write(outs.replace(re"repl.nims\((.*)\) Error: ", "") & "\n")
                    stdout.flushFile()
                    vm.delLine()
                    vm.nowblock = vm.pastblock


if isMainModule:
    try:
        main()
    finally:
        removeDir(cache_dir)
