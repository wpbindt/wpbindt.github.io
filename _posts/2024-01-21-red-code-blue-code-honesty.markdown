---
layout: post
title:  "Red code, blue code, and honesty"
date:   2024-01-21 19:12:38 +0100
categories: async opinions
---

Establish context: IO-intensive apps. Different considerations for CPU-intensive apps.

# Red code, blue code
Reference to [original blog][red-blue-original].

# Dropping the metaphor, or: asynchronous code
Move from calling it red and blue, to expensive/cheap.

# Hexagon with red shell, blue core
Reference functional core, imperative shell.

# The `IO` monad

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
