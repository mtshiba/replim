import strformat
import strutils
import osproc
import nre
import os

{.push checks:off.}

const
    version = "0.2.0"
    date = "Nov 19 2018, 14:46:00"
    message = fmt"""
Replim {version} (default, {date}) [{hostOS}, {hostCPU}]
    :back : clear last line.
    :clear : clear all lines.
    :quit : quit this program.
    :show : display history.
"""
    initcode = """
template on_ce(state: void): void = discard
template on_ce[T: not void](arg: T): void =
    echo arg
template on_ce(args: varargs[untyped]): void =
    echo args
template on_ce[T: type](arg: T): void =
    echo arg
"""

    keywords = [
        "import", "from", "using", "macro", "template", "return", "discard", "once"
    ]
    blockKey = [
        "case"
    ]
    assnKey = [
        "var", "let", "const", "proc", "type"
    ]

type BlockKind = enum
    Main
    Proc
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
    let f = open("repl.nims", fmWrite)
    f.write(self.code)
    f.close()

proc canContainEcho(blockkind: seq[BlockKind]): bool =
    if blockkind.len() == 1:
        return false

    if blockkind[1] == Proc or blockkind[1] == Temp or blockkind[1] == Macro:
        return true
    else:
        return false

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
    self.code = self.code.replace(re"once.*", "")
    self.code = self.code.replace(re"case.*\n\n", "\n")
    var rep = self.code.replace(re".*:\n *\n", "\n")
    while self.code != rep:
        self.code = rep
        rep = self.code.replace(re".*:\n *\n", "\n")

proc delBlock(self: var Replim) =
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
        # onceが必要なのはこれだけ
        else:
            return "oncecall"

proc newReplim(): Replim =
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
        of ":quit":
            break
        of ":show":
            echo "block: ", vm.nowblock
            echo "code:\n", vm.code.replace(initcode, "")
            continue
        of ":clear":
            vm.nowblock = @[Main]
            vm.pastblock = @[Main]
            vm.code = initcode
            continue
        of ":back":
            vm.delLine()
            vm.nowblock = vm.pastblock
            continue
        # for debuging
        of ":save":
            vm.save()
            continue
        of "":
            if vm.nowblock[^1] == Of:
                discard vm.nowblock.pop
                continue
            if vm.nowblock != @[Main]:
                discard vm.nowblock.pop
            if vm.nowblock.len == 1 and not vm.pastblock.isContinueBlock():
                let errc = execCmd("nim e -r --verbosity:0 --checks:off --hints:off repl.nims")
                if errc == 0:
                    let pastcode = vm.code.split("\n")[^2].replace(" ", "")
                    if not vm.pastblock.canContainEcho():
                        vm.delOnce()
                else:
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
                let errc = execCmd("nim e -r --verbosity:0 --checks:off --hints:off repl.nims")
                if errc == 0:
                    vm.delOnce()
                else:
                    vm.delLine()
                    vm.nowblock = vm.pastblock


if isMainModule:
    main()
