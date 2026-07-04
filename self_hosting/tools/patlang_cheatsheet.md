PatLang syntax reference (the only language you may write in). This is the
COMPLETE syntax - do not invent syntax from other languages.

Variables: `let x = 5` (reassigning: `let x = x + 1`, not `x = x + 1`)

Functions:
```
make a function called add takes a, b returns r
  let r = a + b
  return r
end
```
Calling: `add(2, 3)`. Every function needs `returns <name>` even if you
never assign to it before an early `return`.

Control flow:
```
if x > 0 then
  print("positive")
else
  if x == 0 then
    print("zero")
  else
    print("negative")
  end
end
```
(there is no `elif`/`else if` keyword - nest another `if` inside `else`)

```
while i < 10 do
  print(i)
  let i = i + 1
end
```
There is NO `for` loop of any kind (no `for x in xs`, no `for i = 0 to n`).
Iterate over a list with a `while` loop and an integer index instead:
```
let i = 0
while i < xs.length do
  print(xs[i])
  let i = i + 1
end
```

Operators: `+ - * / %` arithmetic; `== != < > <= >=` comparison;
`and or not` logical (not `&&`, `||`, `!`). String concatenation also uses
`+` (numbers auto-convert to strings when concatenated with `+`).

Lists: `let xs = [1, 2, 3]`, `xs[0]`, `xs.length`, `list_push(xs, 4)`
(returns a NEW list - lists are not mutated in place, so always do
`let xs = list_push(xs, 4)`).

Strings: `.length` counts characters. `xs[i]` indexes a single character.
`substr(s, start, len)` returns a substring. `char_code(s, i)` returns the
character code at position i (-1 past the end). `chr(code)` builds a
1-character string from a code point.

Printing: `print(value)` - always adds a newline, works on any type.

Comments start with `#`.

No classes/objects are needed for straightforward tasks - just top-level
`make a function` declarations and a few `print()` calls at the end
demonstrating example usage. A function CANNOT see variables from outside
its own parameters - everything it needs must be passed as an argument.

Common mistakes to avoid (these are NOT valid PatLang, even though they
exist in other languages):
  - `else if` / `elif` as a single construct - does not exist. For 3+
    branches, nest a full `if...end` inside the `else`, with one `end` per
    nesting level. Worked example:
    ```
    if n <= 1 then
      let result = false
    else
      if (n == 2) or (n == 3) then
        let result = true
      else
        if (n % 2) == 0 then
          let result = false
        else
          let result = true
        end
      end
    end
    ```
    Count the `end`s: one per `if` AND one per `while`, always, with no
    exceptions for "else if" chains.
  - `mod` as a word operator - use `%` instead (`n % 2`, not `n mod 2`).
  - `break` / `continue` - do not exist and are silently ignored rather
    than erroring, which can produce a loop that looks like it compiled
    but never actually exits early. Use the `while` condition itself to
    control iteration, or `return` to exit a function early from inside a
    loop (that part does work).
  - `&&`, `||`, `!` - use `and`, `or`, `not`.
  - `if`/`else` as an inline expression (e.g. `let x = if cond then a else
    b end`, a ternary) - does not exist. `if`/`else` are statements only.
    Assign in each branch instead:
    ```
    let x = a
    if not cond then
      let x = b
    end
    ```

Example of a complete, correct program:
```
make a function called factorial takes n returns result
  if n <= 1 then
    let result = 1
  else
    let result = n * factorial(n - 1)
  end
  return result
end

print(factorial(5))
print(factorial(0))
```

Second worked example, showing list iteration with a `while` loop (never a
`for` loop) and building up a running result:
```
make a function called sum_list takes xs returns total
  let total = 0
  let i = 0
  while i < xs.length do
    let total = total + xs[i]
    let i = i + 1
  end
  return total
end

make a function called max_list takes xs returns best
  let best = xs[0]
  let i = 1
  while i < xs.length do
    if xs[i] > best then
      let best = xs[i]
    end
    let i = i + 1
  end
  return best
end

print(sum_list([1, 2, 3, 4]))
print(max_list([3, 7, 2, 9, 4]))
```
