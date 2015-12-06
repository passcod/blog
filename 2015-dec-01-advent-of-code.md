> [Advent of Code] is a series of small programming puzzles for a variety
> of skill levels. They are self-contained and are just as appropriate for
> an expert who wants to stay sharp as they are for a beginner who is just
> learning to code. Each puzzle calls upon different skills and has two
> parts that build on a theme.

[Advent of Code]: http://adventofcode.com

My solutions are usually in JavaScript or Ruby. For each problem, I also try to
create an "evil solution" which uses `eval()`. This page will update along
whenever I finish a problem.

## 1.1

First, eliminate as many pairs of `()` _or_ `)(` as possible, leaving you
with a string of either all `(` or all `)`. Then use the length of the
string and which symbol it is to figure out the answer.

```js
const regex = /(\(\)|\)\()/
while (null !== input.match(regex)) {
  input = input.replace(regex, '')
}

if (input === '') { return 0 }
return input.length * (input[0] === '(' ? 1 : -1)
```

Evil solution:

```js
return eval(
  input
  .replace(/\(/g, '+1')
  .replace(/\)/g, '-1')
)
```

## 1.2

This is actually easier. In part one, I wanted to be clever, so I didn't
do the naive thing and iterate through the string keeping a counter. Let's
do that now:

```js
let floor = 0
let position = 0
while (floor !== -1) {
  floor += input[position] === '(' ? 1 : -1
  position += 1
}
return position
```

Evil solution:

```js
return eval(`c=0;i=0;r=-1;${input.
  replace(/\(/g, 'i+=1;c+=1;').
  replace(/\)/g, 'i-=1;c+=1;if(r<0&&i===-1){r=c+0}')
};r`)
```

## 2.1

First, let's figure out a little math. We're going to get a lot of package
definitions, so optimise the whole thing a bit:

```
2*l*w + 2*w*h + 2*h*l   // Original formula (6 mulitiplications)
2*(l*w + w*h + h*l)     // Factorise, now we only have 4 multiplications

2*... + 2*... + 2*...   // Each individual result is multiplied by two
2*(... + ... + ...)     // So we can sum all results then double it once

l*w + w*h + h*l         // The simplified inner formula (3 multiplications)
w*(h + l) + h*l         // Factorised, only 2 multiplications
```

Onto the code!

```js
let slack = 0
return input.split("\n").reduce((memo, line) => {
  if (line === '') { return memo }
  let d = line.split('x').map(n => +n).sort((a, b) => a - b)
  slack += d[0] * d[1]
  return memo += d[0] * (d[1] + d[2]) + d[1] * d[2]
}, 0) * 2 + slack
```

Evil, but boring (it's just an inlining of the above), solution:

```js
return eval(`t=0;s=0;${input.
  replace(/(\d+)x(\d+)x(\d+)\s*/g, 't+=($1*($2+$3)+$2*$3);s+=[$1,$2,$3].sort((a,b) => a-b).slice(0,2).reduce((m,d) => m*d, 1);')
}t*2+s`)
```

In case you're confused (mwahaha):

- `.map(n => +n)` casts all items to numbers
- `.sort((a, b) => a - b)` sorts an array numerically
- `.slice(0, N)` takes the first N items
- `.reduce((m, d) => m * d, 1)` product of the array
- `.reduce((m, d) => m + d, 0)` sum of the array (used below)

## 2.2

No preliminary math, this time.

```js
return input.split("\n").reduce((memo, line) => {
  if (line === '') { return memo }
  let d = line.split('x').map(n => +n).sort((a, b) => a - b)
  return memo + d.slice(0, 2).reduce((m, d) => m + d, 0) * 2 +
    d.reduce((m, d) => m * d, 1)
}, 0)
```

Ugh. So boring.

Evil solution, which assumes that the input has a trailing newline:

```js
const bows = eval(input.replace(/x/g, '*').replace(/\s+/g, '+') + '.0')
const wrap = eval(`"${input.replace(/\s+/g, '\".split(/x/g).map(n => +n).sort((a, b) => a - b).slice(0, 2).reduce((m, d) => m + d, 0)+"')}".length`)
return bows + wrap * 2
```

