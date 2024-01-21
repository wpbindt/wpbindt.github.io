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
- in defining a function, you must specify its color, for example as in `(red) def my_red_func(): ...` and `(blue) def my_blue_func(): ...`
- to call a red/blue function, you need to use a special syntax, for example `red_call my_red_func()` or `blue_call my_blue_func()`
And the crucial rule
- you can only call red functions from within red functions. That is, `(blue) def my_blue_func(): red_call my_red_func()` is not allowed.

The red functions are meant to be a metaphor for async functions, and the blue ones for non-async ones.

In this allegorical language, the main problem arises almost immediately. If you have some deep call stack of blue functions, and you want to call a red one on the top of it, you're going to have to go down the call stack and change every blue function on there to a red one. Every single one. That's a lot of paperwork to go through just to call a function you wrote yourself! Effectively, **red (or async) functions will bleed all through your codebase**, and soon your entire codebase will consist of nothing but async functions.

The author goes into more detail, and has more to say, but it is this specific point I want to focus on here.

# Dropping the metaphor, or: asynchronous code
Move from calling it red and blue, to expensive/cheap.

# Hexagon with red shell, blue core
Reference functional core, imperative shell.

# The `IO` monad
It's just a simile, Promises are not monads (maybe not even functorial?). Link to stackoverflow post.

# Drawback: integration with sync third party libraries

# Drawback: refactoring sync legacy codebase to using async is difficult
Pattern to include: `AsyncioProxy`
Very incomplete:
{% highlight python %}
def my_legacy_app() -> NoReturn:
    """
    do stuff forever
    """
{% endhighlight %}

{% highlight python %}
class AsyncioProxy:
    def __init__(self, loop):
        self._loop = loop

    def run_coro(self, coro):
        return self._loop.run_coroutine_threadsafe(coro).result()

def my_legacy_app(asyncio_proxy: AsyncioProxy) -> NoReturn:
    """
    do stuff forever
    """

async def my_shiny_new_async_app() -> NoReturn:
    """
    do async stuff
    """

def strangler_app() -> NoReturn:
    asyncio.run(my_shiny_new_async_app())
{% endhighlight %}

# Pro: forced not to inject I/O code into domain
Pit of success. Reference to Mark Seemann? Who came up with this metaphor?
Why is smart domain bad? Hard to reason about performance?

# Drawback: unnecessarily async standard library functions?
Async left pad? Don't actually know examples of unnecessarily async stuff.

# Drawback: no async file I/O

# Drawback: performance?
I recall seeing a blog post which bashes performance of async applications.

[red-blue-original]: https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/
