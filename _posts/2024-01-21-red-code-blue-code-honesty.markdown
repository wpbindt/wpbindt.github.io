---
layout: post
title:  "Red code, blue code, and honesty"
date:   2024-01-21 19:12:38 +0100
categories: async opinions programming
---

**TL;DR:** `async/await`-style concurrency forces you to be explicit about which code does IO. That's a good thing.

# Red code, blue code
There is a [classic blog post][red-blue-original] by Bob Nystrom where he explains why he prefers (for example) Go's concurrency model over the `async/await`-based ones found in for example Python and C#. It's a classic for a reason, and worth a read if you haven't yet. I'll summarize one part of his argument here.

To illustrate why `async/await` is bad/annoying, he invents a convincing allegorical language. The language has so called "red functions" and "blue functions". These are just like regular functions, except they adhere to some rules, namely:
1. in defining a function, you must specify its color, like for example `red_def my_red_func(): ...` and `blue_def my_blue_func(): ...`
2. to call a red/blue function, you need to use a special syntax, something like `red_call my_red_func()` or `blue_call my_blue_func()`

And the most crucial rule:
3. you can only call red functions from within red functions. That is, `blue_def my_blue_func(): red_call my_red_func()` is not allowed.

The red functions are meant to be a metaphor for async functions, and the blue ones for non-async ones.

In this allegorical language, the main problem arises almost immediately. If you have some deep call stack of blue functions, and you want to call a red one on the top of it, you're going to have to go down the call stack and change every blue function on there to a red one. Every single one. That's a lot of paperwork to go through just to call a function! Were these functions non-colored, you could've just called it without touching the entire call stack. Effectively, **red (or async) functions will bleed all through your codebase**, and soon your entire codebase will consist of nothing but red (async) functions.

The author goes into more detail, and has more to say, but it is this specific point I want to focus on here.

# Dropping the metaphor, or: asynchronous code
While I like the colored code metaphor, I also think that by obscuring some aspects of `async/await`, it makes the argument above seem more persuasive than it deserves to be. In order to drop the metaphor, I'll give a short (and necessarily shallow) introduction to `async/await`-style concurrency. Various languages support this style of concurrency (for example Python, C# and JavaScript), and more in-depth explanations can probably be found in your language of choice. For Python, you can find one [here][python-in-depth-async-explanation].

Asynchronous programs aim to run several procedures concurrently, and typically it works as follows. Somewhere, somehow, there is a task scheduler running, called the **event loop**. This event loop is responsible for running your async functions (or **coroutines**). When a coroutine performs some IO (call to the database, send an email, etc), it yields control back to the event loop, allowing another coroutine to continue running. The key difference from thread-based concurrency is precisely that. It is not the event loop which decides when to context switch between running coroutines, but the coroutines themselves. Yielding control to the event loop is done using the `await` keyword.

In Python, a coroutine is defined using the `async` keyword. For example, in the snippet
{% highlight python %}
import asyncio
from typing import NoReturn

async def hi() -> NoReturn:
    while True:
        print('hi')
        await asyncio.sleep(1.25)

async def ho() -> NoReturn:
    await asyncio.sleep(0.25)
    while True:
        print('ho')
        await asyncio.sleep(1.25)

async def main() -> NoReturn:
    await asyncio.gather(hi(), ho())

asyncio.run(main())
{% endhighlight %}
the `main` coroutine uses `asyncio.gather` to concurrently run the coroutines `hi` and `ho`. When `hi` starts running, it prints `'hi'`, and then immediately yields control back to the event loop using `await asyncio.sleep(1.25)`. The coroutine `asyncio.sleep` is used here to replace some actual IO, but it functions the same. Execution for `hi` will resume after the 1.25 seconds expire. As `hi` has yielded control back to the event loop, `ho` can run. It immediately yields control to the event loop with `asyncio.sleep`. After 0.25 seconds, `ho` is ready to go again, and since there's no other coroutine holding control, it is allowed to run. It prints `'ho'`, and it yields control back tot he event loop. And so on.

Note that in this example you can see rules 1. and 2. from the allegorical language in action. We use `async` to define our red functions (its absence defines sync functions), as in rule 1, and we have to use `await` to call our red functions, as in rule 2.

To see rule 3. in action, consider the snippet
{% highlight python %}
async def hi() -> None:
    print('hi')

def sync_function_1() -> None:
    await hi()

def sync_function_2() -> None:
    hi()
{% endhighlight %}
Running `sync_function_1` will raise `SyntaxError: 'await' outside async function`. Running `sync_function_2` will not raise this exception, but it will also not print `'hi'`. You can only call `async` functions from within async functions.


# Hexagon with red shell, blue core
Reference functional core, imperative shell.

# A poor man's IO monad
It's just a simile, Promises are not monads (maybe not even functorial?). Link to stackoverflow post. Haskell has an async plugin. Are Promises really not monads, or is that just a quirk of JavaScript?

# Drawback: the terrible Hidden Fourth Rule which Forbids us From Running Blue in Red

# Drawback: integration with sync third party libraries
In my experience, this has not been much of an issue. For example, you can just do
{% highlight python %}
from third_party import sync_function

async def f():
    event_loop = asyncio.get_running_event_loop()
    return await loop.run_in_executor(None, sync_function)
{% endhighlight %}
There's a drawback to doing this, but I don't know what it is.

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
[python-in-depth-async-explanation]: https://example.com
