---
layout: post
title:  "Red code, blue code, and honesty"
date:   2024-01-21 19:12:38 +0100
categories: async opinions
---

Establish context: IO-intensive apps. Different considerations for CPU-intensive apps.

# Red code, blue code
There is a [classic blog post][red-blue-original] written by Bob Nystrom where he goes into why he prefers Go's concurrency model over the `async/await` based ones found in for example Python and C#. It's an classic for a reason, and worth a read if you haven't yet. I'll summarize the main point of his argument here.

To illustrate why `async/await` is bad/annoying, he invents a convincing allegorical language. The language has so called "red functions" and "blue functions". These are just like regular functions, except they adhere to some rules, namely:
- in defining a function, you must specify its color, like for example `red_def my_red_func(): ...` and `blue_def my_blue_func(): ...`
- to call a red/blue function, you need to use a special syntax, something like `red_call my_red_func()` or `blue_call my_blue_func()`

And the most crucial rule:
- you can only call red functions from within red functions. That is, `blue_def my_blue_func(): red_call my_red_func()` is not allowed.

The red functions are meant to be a metaphor for async functions, and the blue ones for non-async ones.

In this allegorical language, the main problem arises almost immediately. If you have some deep call stack of blue functions, and you want to call a red one on the top of it, you're going to have to go down the call stack and change every blue function on there to a red one. Every single one. That's a lot of paperwork to go through just to call a function! Were these functions non-colored, you could've just called it without touching the entire call stack. Effectively, **red (or async) functions will bleed all through your codebase**, and soon your entire codebase will consist of nothing but red (async) functions.

The author goes into more detail, and has more to say, but it is this specific point I want to focus on here.

# Dropping the metaphor, or: asynchronous code
Move from calling it red and blue, to expensive/cheap.

# Hexagon with red shell, blue core
Reference functional core, imperative shell.

# A poor man's IO monad
It's just a simile, Promises are not monads (maybe not even functorial?). Link to stackoverflow post.

# Drawback: the terrible Hidden Fourth Rule which Forbids us From Running Blue in Red

# Drawback: integration with sync third party libraries
{% highlight python %}
from third_party import sync_function

async def f():
    event_loop = asyncio.get_running_event_loop()
    return await loop.run_in_executor(None, sync_function)
{% endhighlight %}

# Drawback: refactoring sync legacy codebase to using async is difficult
Pattern to include: `AsyncioProxy`?

# Pro: forced not to inject I/O code into domain
Pit of success. Reference to Mark Seemann? Who came up with this metaphor?
Why is disconnected domain bad? Form of lazy loading, which has its [problems][lazy-loading-is-antipattern]. It's mentioned in Vernon's book in the Aggregates chapter, but he does not go into detail. Something about scaling and fetching large dependency trees.

# Drawback: unnecessarily async standard library functions?
Async left pad? Don't actually know examples of unnecessarily async stuff.

# Drawback: no async file I/O

# Drawback: performance?
See [this blog post][async-python-is-not-faster]. Pays to read this one carefully, seems the author made some mistakes in the async code. Some issues: non-locked pool creation, database running on same machine as app (async shines when I/O slow, which is less so the case when there's no network hops), code used for serialization (and hence irrelevant to sync v async debate) differs between async and sync benchmarks.

[red-blue-original]: https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/
[async-python-is-not-faster]: https://calpaterson.com/async-python-is-not-faster.html
[lazy-loading-is-antipattern]: https://www.mehdi-khalili.com/orm-anti-patterns-part-3-lazy-loading
