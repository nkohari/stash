Stash is a graph-based cache powered by Redis. It's currently just a mental exercise and can be safely ignored. :)

```coffeescript
obj1 = {id: 1, text: "foo"}
obj2 = {id: 2, text: "bar"}
obj3 = {id: 3, text: "baz"}
arrA = [obj1, obj3]
arrB = [obj3]
arrC = [arrA, arrB]
```

```
KEY    VALUE
1      `{id: 1, text: "foo"}`
2      `{id: 2, text: "bar"}`
3      `{id: 3, text: "baz"}`
A      `[{id: 1, text: "foo"}, {id: 3, text: "baz"}]`
B      `[{id: 3, text: "baz"}]`
C      `[[{id: 1, text: "foo"}, {id: 3, text: "baz"}], [{id: 3, text: "baz"}]]`
1:deps `[A]`
2:deps `[A]`
3:deps `[A]`
A:deps `[C]`
B:deps `[C]`
```

```coffeescript
stash.set 1, obj1
stash.set 2, obj2
stash.set 3, obj3

stash.set A, arrA
stash.dep A, [1, 3]

stash.set B, arrB
stash.dep B, 1

stash.set C, arrC
stash.dep C, [A, B]

stash.inv 3 # [3, 3:deps] -> [3, A, A:deps] -> [3, A, C, C:deps] -> [3, A, C]
```