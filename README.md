Stash is a graph-based cache system for [Node.js](http://nodejs.org/) powered by [Redis](http://redis.io/).

*NOTE: This is just a mental exercise at this point. Feedback is very much appreciated, but using it in
production may cause you to contract ebola or result in global thermonuclear war.*

# Overview

One of the most difficult parts about caching is managing dependencies between objects. When something changes,
you need to know which cache entries to invalidate. This can be challenging.

For example, consider the following data model powering a blog:

* `Page` has many `Posts`
* `Post` has many `Comments`

Using this model, here's some sample data that might be cached:

```coffeescript
comment1 = {author: 'jack', text: 'foo'}
comment2 = {author: 'jill', text: 'bar'}
comment3 = {author: 'bob',  text: 'bloo'}

post1 = {author: 'joe', text: 'blah', comments: [{author: 'jack', text: 'foo'}, {author: 'jill', text: 'bar'}]}
post2 = {author: 'joe', text: 'derp', comments: [{author: 'bob',  text: 'bloo'}]}

page1 = [
	{author: 'joe', text: 'blah', comments: [{author: 'jack', text: 'foo'}, {author: 'jill', text: 'bar'}]}
	{author: 'joe', text: 'derp', comments: [{author: 'bob',  text: 'bloo'}]}
]
```

Note that the data from the "child" entities (`Post` and `Comment`) is duplicated inside of the cache entries
for their parents. This means when a child changes, you can't just invalidate the cache entry for the child &mdash;
you have to invalidate all of its parents' entries as well. Also, if the parents have parents of their own, you have
to invalidate those, and so on. In our example, if data in `comment1` changes, we must invalidate `comment1`,
`post1`, and `page1`.

Stash helps you by allowing you to define *dependencies* between entries.

```coffeescript
stash = new Stash()

# Save the comments
stash.set 'comment1', {author: 'jack', text: 'foo'}
stash.set 'comment2', {author: 'jill', text: 'bar'}
stash.set 'comment3', {author: 'bob',  text: 'bloo'}

# Save the first post
stash.set 'post1', {author: 'joe', text: 'blah', comments: [{author: 'jack', text: 'foo'}, {author: 'jill', text: 'bar'}]}
stash.set 'post2', {author: 'joe', text: 'derp', comments: [{author: 'bob',  text: 'bloo'}]}

# Declare that the posts depend on the comments that exist therein
stash.dep 'post1', ['comment1', 'comment2']
stash.dep 'post2', 'comment3'

# Save the page
stash.set 'page1', [
	{author: 'joe', text: 'blah', comments: [{author: 'jack', text: 'foo'}, {author: 'jill', text: 'bar'}]}
	{author: 'joe', text: 'derp', comments: [{author: 'bob',  text: 'bloo'}]}
]

# Declare that the page depends on the posts
stash.dep 'page1', ['post1', 'post2']
```

Then, when `comment1` changes, just tell Stash to invalidate it:

```coffeescript
stash.inv 'comment1'
```

This will result in not only the comment being removed from the cache, but Stash will also resolve the graph
of dependencies and invalidate them as well. In the case of `comment1`, Stash will remove `comment1`, `post1`, and `page1`,
while leaving the rest of the cache alone.

# API

All callbacks use the standard Node convention of `(err, data)`.

## stash.get(key, callback)

Gets the value stored at the specified key.

## stash.set(key, value, [callback])

Sets the value stored at the specified key. If `callback` is specified, it will be called after the item is set.

## stash.dep(key, dependencies..., [callback])

Declares that the value stored at `key` depends on values stored at the keys specified in `dependencies`.
The `dependencies` may be either an array, or varargs, or a combination of both. If `callback` is specified,
it will be called after the dependencies are created.

## stash.inv(keys..., [callback])

Declares that the value stored at each key in `keys` is no longer valid and should be removed from the cache.
The `keys` may be either an array, or varargs, or a combination of both. If `callback` is specified, it will
be called with an array of keys that were removed from the cache.

## stash.rem(keys..., [callback])

Removes the entries stored at each key in `keys` from the cache. This differs from `inv()` in that it does not
remove dependent items, and also destroys the entries' dependency graph. Use this when the object that's cached
no longer exists, and won't need to react to updates. If `callback` is specified, it will be called after the
items are removed.

# License (Apache 2.0)

Copyright (c) 2012 Nate Kohari.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

