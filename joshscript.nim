import os
import math
import strutils

const ignoredChars = [
  ' ',
  '\t',
  '\x0A', # LF
  '\x0D', # CR
  ';'
] ## Ignored character list
const cellHigh = 0xFF ## Top limit of cell

type
  Cells = array[0..0xFF, int]

  InterpretError = object of SystemError ## Raised on interpret error
var
  cells: Cells
  cellPtr: int = 0


iterator perJosh(str: string): (int, string) =
  ## Iterate string by 4 characters
  var n = (str.len / 4).floor.int
  for i in 0..<n:
    yield(4*i, str[(i*4)..(i*4 + 3)])


proc findLoopEnd(str: string, start: int): int {.raises: [InterpretError, ValueError].} =
  ## Find end of the loop starting at position
  ## Raises exception if no end found
  let
    slice = str[(start + 4)..^1]
    start = start + 4
  var depth = 0

  for index, josh in perJosh(slice):
    if josh == "JoSh":
      inc depth
    elif josh == "jOsH":
      if depth == 0:
        # Found the loop end
        return start + index - 1
      else:
        dec depth

  raise newException(InterpretError, "Unmatched loop tag at index $#" % $start)


proc stripIgnoredChars(str: var string) =
  ## Remove ignored characters and comments from string
  var
    i = 0
    commentStart = -1

  while i < str.len:
    let ch = str[i]

    if commentStart == -1:
      if ch == '(':
        commentStart = i

      elif ch in ignoredChars:
        str.delete i, i
        continue
    else:
      # We are in comment
      if ch == ')':
        str.delete commentStart, i

        i = commentStart
        commentStart = -1
        continue

    inc i


proc interpretCode(code: string) =
  ## Interpret JoshScript

  var
    skipTokens = 0
    code = code # Bring to local scope

  stripIgnoredChars code

  if code.len mod 4 != 0:
    echo code
    raise newException(InterpretError, "Invalid code length")

  for index, josh in perJosh(code):
    if skipTokens > 0:
      dec skipTokens
      continue

    var value = cells[cellPtr]

    case josh
    of "JOSH": # Addition
      cells[cellPtr] += (if value < cellHigh: 1 else: -cellHigh)

    of "josh": # Subtraction
      cells[cellPtr] -= (if value > 0: 1 else: -cellHigh)

    of "Josh": # Double the value (Shift left)
      cells[cellPtr] = (value shl 1) and 0xFF

    of "josH": # Shift right
      cells[cellPtr] = value shr 1

    of "JosH": # Write current to stdout
      write stdout, value

    of "JOsh": # Write current to stdout as ASCII char
      write stdout, value.chr

    of "jOsh": # Clear current
      cells[cellPtr] = 0

    of "JOSh": # Raise to the power of 2
      cells[cellPtr] = (value ^ 2) and 0xFF

    of "joSH": # Increment cell pointer
      cellPtr += (if cellPtr < 0xFF: 1 else: -0xFF)

    of "joSh": # Decrement cell pointer
      cellPtr -= (if cellPtr > 0: 1 else: -0xFF)

    of "JoSh": # Loop begin
      let
        loopEnd = findLoopEnd(code, index)
        codeSlice = code[(index + 4)..loopEnd]
        loopLength = loopEnd - index + 1

      while cells[cellPtr] > 0:
        interpretCode codeSlice

      skipTokens = (loopLength/4).int

    of "jOsH": # Loop end
      discard

    else:
      raise newException(InterpretError, "Unknown operation \"$#\"" % josh)


proc run() =
  ## If there are no arguments passed, start JoshScript interaction mode
  ## Otherwise expects first argument to be JoshScript source code

  if paramCount() == 0:
    while true:
      write stdout, ">>> "
      let input = readline stdin

      interpret_code(input)

      # Clear memory and reset pointer
      for i in cells: cells[i] = 0
      cellPtr = 0

      write stdout, "\n"

  else:
    let
      filename = paramStr(1)
      code = readFile filename

    interpretCode code
    write stdout, "\n"

try:
  run()
except InterpretError:
  echo "\nJoshScript Error // ", getCurrentExceptionMsg()
except:
  echo "\nUnknown Error :("
