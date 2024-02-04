---
layout: post
title:  "Red code, blue code, and honesty"
date:   2024-01-21 19:12:38 +0100
categories: async opinions programming
---

**TL;DR:** `async/await`-style concurrency forces you to be explicit about which code does I/O. That's a good thing.

## Introduction
In this post I go over one aspect of `async/await`-style concurrency that is frequently cited as a drawback, and show that it's actually big benefit (in my opinion even one of the main benefits). In short, `async/await` forces you to be explicit about I/O by requiring you to use the `async` and `await` keywords. I also discuss my main gripe with `async/await`, which is that it's easy to accidentally block the event loop.

## Red code, blue code
There is a [classic blog post][red-blue-original] by Bob Nystrom explaining why he prefers (for example) Go's concurrency model over the `async/await`-based ones found in for example Python and C#. It's a classic for a reason, and worth a read. I'll summarize one part of his argument here.

To illustrate why `async/await` is bad/annoying, he invents a convincing allegorical language. The language has so-called "red functions" and "blue functions". These are just like regular functions, except they adhere to some rules, namely:
1. in defining a function, you must specify its color, like for example `red_def my_red_func(): ...` and `blue_def my_blue_func(): ...`
2. to call a red/blue function, you need to use a special syntax, something like `red_call my_red_func()` or `blue_call my_blue_func()`
3. you can only call red functions from within red functions. That is, `blue_def my_blue_func(): red_call my_red_func()` is not allowed.

The red functions are meant to be a metaphor for async functions, and the blue ones for non-async ones.

In this allegorical language, the main problem arises almost immediately. If you have some deep call stack of blue functions, and you want to call a red one on the top of it, you're going to have to go down the call stack and change every blue function on there to a red one. Every single one. That's a lot of paperwork to go through just to call a function! Were these functions non-colored, you could've just called it without touching the entire call stack. Effectively, **red (or async) functions will bleed all through your codebase**, and soon your entire codebase will consist of nothing but red (async) functions.

The author goes into more detail, and has more to say, but it is this specific point I want to focus on here.

## Dropping the metaphor: asynchronous code
While I like the colored code metaphor, I also think that by obscuring some aspects of `async/await`, it makes the argument above seem more persuasive than it deserves to be. In order to drop the metaphor, I'll give a short (and necessarily shallow) introduction to `async/await`-style concurrency. Various languages support this style of concurrency (for example Python, C# and JavaScript), and more in-depth explanations can probably be found in your language of choice. For Python, you can find one [here][python-in-depth-async-explanation]. Readers familiar with `async/await`-style concurrency wouldn't miss much in skipping this section.

Asynchronous programs aim to run several procedures concurrently, and typically it works as follows. Somewhere, somehow, there is a task scheduler running, called the **event loop**. This event loop is responsible for running your async functions (or **coroutines**). When a coroutine performs some I/O (call to the database, send an email, etc), it yields control back to the event loop, allowing another coroutine to continue running. The key difference from thread-based concurrency is precisely that. It is not the event loop which decides when to context switch between running coroutines, but the coroutines themselves. Yielding control to the event loop is done using the `await` keyword.

In Python, a coroutine is defined using the `async` keyword. Consider the snippet
{% highlight python %}
async def hi():
    while True:
        print('hi')
        await asyncio.sleep(1.25)

async def ho():
    await asyncio.sleep(0.25)
    while True:
        print('ho')
        await asyncio.sleep(1.25)
{% endhighlight %}
Suppose we run the coroutines `hi` and `ho` concurrently (for example using [gather][python-docs-gather]). When `hi` starts running, it prints `'hi'`, and then immediately yields control back to the event loop using `await asyncio.sleep(1.25)`. The coroutine `asyncio.sleep` is used here to replace some actual I/O, but it functions the same. Execution for `hi` will resume after the 1.25 seconds expire. As `hi` has yielded control back to the event loop, `ho` can run. It immediately yields control to the event loop with `asyncio.sleep`. After 0.25 seconds, `ho` is ready to go again, and since there's no other coroutine holding control, it is allowed to run. It prints `'ho'`, and it yields control back tot he event loop. And so on.

In this example you can see rules 1 and 2 from the allegorical language in action. We use `async` to define our red functions (its absence defines sync functions), as in rule 1, and we have to use `await` to call our red functions, as in rule 2.

To experience rule 3, consider the snippet
{% highlight python %}
async def hi():
    print('hi')

def sync_function_1():
    await hi()

def sync_function_2():
    hi()
{% endhighlight %}
Running `sync_function_1` will raise `SyntaxError: 'await' outside async function`. Running `sync_function_2` will not raise this exception, but it will also not print `'hi'`. You can only call `async` functions from within async functions.

## Expensive and cheap functions
The three rules are inconvenient. And when dealing with red/blue functions, that's all they are. Who cares if a function is red or blue? I just want to call it! All these rules seem to do is to make life difficult. However, when dealing with async/sync functions, two of them serve a purpose, and one isn't an inconvenient law in the sense of parking tickets, but rather a natural law, in the sense of gravity.

The main difference between synchronous and asynchronous functions is that asynchronous functions might do I/O, and synchronous functions do not. That is, in an I/O-bound system[^1], asynchronous is essentially synonymous with (potentially) **expensive**, and synchronous with (definitely) **cheap**. In contrast with color, surely these are properties we're interested in. A function `f` being expensive versus cheap makes the difference between `for _ in range(100): f()` being a bad idea versus a complete non-issue. 

# Rule 1
Suppose you have a function `do_stuff`, hundreds of lines long, calling various other functions with similarly well-chosen names. A colleague submits a merge request which uses this function in some loop somewhere. Is this a bad idea? Depends on whether it's cheap or expensive. How can you tell which one it is? In a non-async codebase, the only way is to read it and its dependencies, which can be immensely time-consuming and error-prone. If you're working in an async codebase, it's as simple as looking at the signature:
{% highlight python %}
def do_stuff():
    ##lots of code
{% endhighlight %}
It's synchronous, hence cheap, and it took less than a second to find out. This quick inspection is made possible by rule 1: defining an expensive function looks different from defining a cheap function.

# Rule 2
Suppose we can call async functions without using the `await` keyword, and suppose your colleague submits a merge request containing something like
{% highlight python %}
async def do_more_stuff():
    ...
    for _ in range(1000):
        f_1()
        f_2()
        f_3()
    ...
{% endhighlight %}
Is this a bad idea from a performance perspective? Not necessarily, each of the functions `f_i` could be synchronous. But to find out, you'll have to inspect the signature of each one of them. In a language satisfying rule 2, the snippet might instead look something like
{% highlight python %}
async def do_more_stuff():
    ...
    for _ in range(1000):
        f_1()
        await f_2()
        f_3()
    ...
{% endhighlight %}
This makes it immediately clear that this is a pretty expensive change to make.

# Rule 3
Rule 3 says essentially the following: if `f` is cheap, and `g` is expensive, then if we change `f` so as to call `g`, then `f` becomes expensive. That is to say, if you call an expensive function in another function, that other function becomes expensive automatically. Or, to put it conversely, **you cannot call an expensive function from a cheap function**. Not cannot as in "it is not allowed", rather cannot as in "it's a logical contradiction". This is not a rule so much as a fact of life. A natural law. It doesn't need motivation, it just *is*.

**In summary**: functions either do or do not do I/O. This is inherent to the function. Choosing whether or not to have rules 1 and 2 in your language is essentially choosing whether you want want to be honest with yourself and to make this explicit and easily inspected, or implicit and hidden in implementation. Rule 3 is a necessary consequence of choosing to have rules 1 and 2.

## But all my code will be red!
Not necessarily. Check out these hexagons:
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="171px" viewBox="-0.5 -0.5 171 141" content="&lt;mxfile host=&quot;app.diagrams.net&quot; modified=&quot;2024-01-26T21:46:12.798Z&quot; agent=&quot;Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0&quot; etag=&quot;J4dPCS4FsGYKhAfRh0TV&quot; version=&quot;22.1.21&quot; type=&quot;google&quot;&gt;&#xA;  &lt;diagram name=&quot;Page-1&quot; id=&quot;Oouc9fD8gRl2aMlskFq-&quot;&gt;&#xA;    &lt;mxGraphModel dx=&quot;1432&quot; dy=&quot;796&quot; grid=&quot;1&quot; gridSize=&quot;10&quot; guides=&quot;1&quot; tooltips=&quot;1&quot; connect=&quot;1&quot; arrows=&quot;1&quot; fold=&quot;1&quot; page=&quot;1&quot; pageScale=&quot;1&quot; pageWidth=&quot;800&quot; pageHeight=&quot;700&quot; math=&quot;0&quot; shadow=&quot;0&quot;&gt;&#xA;      &lt;root&gt;&#xA;        &lt;mxCell id=&quot;0&quot; /&gt;&#xA;        &lt;mxCell id=&quot;1&quot; parent=&quot;0&quot; /&gt;&#xA;        &lt;mxCell id=&quot;c5InBF9XVYWPZ4O_JD-l-1&quot; value=&quot;&quot; style=&quot;shape=hexagon;perimeter=hexagonPerimeter2;whiteSpace=wrap;html=1;fixedSize=1;fillColor=#FF0000;&quot; vertex=&quot;1&quot; parent=&quot;1&quot;&gt;&#xA;          &lt;mxGeometry x=&quot;130&quot; y=&quot;110&quot; width=&quot;170&quot; height=&quot;140&quot; as=&quot;geometry&quot; /&gt;&#xA;        &lt;/mxCell&gt;&#xA;        &lt;mxCell id=&quot;c5InBF9XVYWPZ4O_JD-l-2&quot; value=&quot;&quot; style=&quot;shape=hexagon;perimeter=hexagonPerimeter2;whiteSpace=wrap;html=1;fixedSize=1;fillColor=#0000FF;strokeColor=#6c8ebf;&quot; vertex=&quot;1&quot; parent=&quot;1&quot;&gt;&#xA;          &lt;mxGeometry x=&quot;152.5&quot; y=&quot;130&quot; width=&quot;125&quot; height=&quot;100&quot; as=&quot;geometry&quot; /&gt;&#xA;        &lt;/mxCell&gt;&#xA;      &lt;/root&gt;&#xA;    &lt;/mxGraphModel&gt;&#xA;  &lt;/diagram&gt;&#xA;&lt;/mxfile&gt;&#xA;" onclick="(function(svg){var src=window.event.target||window.event.srcElement;while (src!=null&amp;&amp;src.nodeName.toLowerCase()!='a'){src=src.parentNode;}if(src==null){if(svg.wnd!=null&amp;&amp;!svg.wnd.closed){svg.wnd.focus();}else{var r=function(evt){if(evt.data=='ready'&amp;&amp;evt.source==svg.wnd){svg.wnd.postMessage(decodeURIComponent(svg.getAttribute('content')),'*');window.removeEventListener('message',r);}};window.addEventListener('message',r);svg.wnd=window.open('https://viewer.diagrams.net/?client=1&amp;page=0&amp;edit=_blank');}}})(this);" style="cursor:pointer;max-width:100%;max-height:141px;"><defs/><g><path d="M 20 0 L 150 0 L 170 70 L 150 140 L 20 140 L 0 70 Z" fill="#ff0000" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"/><path d="M 42.5 20 L 127.5 20 L 147.5 70 L 127.5 120 L 42.5 120 L 22.5 70 Z" fill="#0000ff" stroke="#6c8ebf" stroke-miterlimit="10" pointer-events="all"/></g></svg>
Suppose your application is structured along the lines [hexagonal architecture][hexagonal-architecture][^2]. The nested hexagon above is a schematic representation of such an application. The outer shell represents the code responsible for communicating with the outside world. It might consist of communication with the database, code for publishing messages to your message broker, or a server receiving API calls. The inner hexagon represents your domain layer. It contains the business logic. The basic idea is that the dependencies flow inward. That is, the outer layer depends on the inner layer, not the other way around.

The outer layer necessarily consists of async functions, since they (by definition) do I/O. The domain is called by the outer layer, but since asynchronous functions can call synchronous ones, this makes it perfectly possible for your domain layer to be completely synchronous.

For example, one part of the outer layer might look something like this:
{% highlight python %}
@rpc
async def service_layer_function(request: AssignCourierToDelivery) -> None:
    delivery = await delivery_repository.get_by_id(request.delivery_id)
    courier = await courier_read_repository.get_by_id(request.courier_id)

    delivery.assign_courier(courier)

    await delivery_repository.save(delivery)
{% endhighlight %}
Here the I/O all happens in the repositories (which connect to the database or something like that), and the `assign_courier` method, which presumably makes some complicated business computations, is free to be synchronous.

## An actual drawback
Now that it's clear that being explicit about I/O is actually a good thing, in this section I want to acknowledge `async/await` is not all sunshine and roses, and talk about what I consider to be its main drawback.

Asynchronous code has the following footgun: You cannot run asynchronous functions inside synchronous functions, but nothing logically prevents you from running expensive synchronous code inside asynchronous code. To give a trivial example:
{% highlight python %}
async def my_async_function():
    time.sleep(10)
{% endhighlight %}
Why is this bad? Well, as discussed in the section on the `async/await` paradigm, coroutines are themselves responsible for yielding control back to the event loop. Moreover, only one coroutine runs at a time, so until `my_async_function` yields back control, other coroutines are blocked from continuing. The example above would **block all other coroutines from running** for 10 seconds straight, which is really bad!

The given example is very artificial, so it's tempting to dismiss it as an easily avoided mistake. But any synchronous code doing I/O or CPU intensive computations can cause this, and this kind of issue is hard to lint for, so it can (and will) sneak up on you. The next section gives an example I've seen in production of such a footgun going off.

# Example: logging in Python
Logging in Python is done using `Logger` objects and `Handler` objects. The `Logger` objects are responsible for accepting logs from the developer. These `Logger` objects have a number of `Handler` objects. These `Handler` are responsible for emitting these logs to various places, such as files, Graylog, or stdout/stderr. These `Handler` objects are called as such because they *handle* the emission of log records. Sometimes naming things well is easy!

For example, in the snippet
{% highlight python %}
logger = logging.getLogger('my_logger')
logger.addHandler(logging.StreamHandler())
logger.info('hi mom')
{% endhighlight %}
the string `'hi mom'` is sent to stderr.

A developer familiar with Python's logging functionality might put
{% highlight python %}
async def my_async_function():
    ...
    logger.info('We did the thing')
    ...
{% endhighlight %}
in their code and not think twice about it. Since we don't know what handlers are attached to the logger, each of which might do some I/O (if only our code could clearly indicate which functions do I/O and which don't!), this snippet potentially blocks the event loop.

# How to do logging in async Python
For completeness' sake, let's look at how you could go about logging in an async Python application. One way of doing so is with `logging.handlers.QueueHandler`. Instead of emitting the log records directly to whatever log aggregator you have, `QueueHandler` puts them (non-blockingly) on a queue which some async-compatible log emitter can listen to. For example,
{% highlight python %}
logger = logging.getLogger('my_logger')
my_log_queue = asyncio.Queue()
logger.addHandler(logging.handlers.QueueHandler(my_log_queue))

async def handle_log_records(queue):
    while True:
        record = await queue.get()
        await send_record_to_log_aggregator(record)

asyncio.create_task(handle_log_records(my_log_queue))
{% endhighlight %}
The final line runs the log emission as a background task. Now the I/O needed for log aggregation is running in a coroutine, and will not block other coroutines when emitting logs.

This solution is still fraught with footguns. For example, all it takes for the above to break down is for some unsuspecting developer to run `getLogger('my_logger').addHandler(BlockingHandler())` somewhere else, and our logger is back to blocking the event loop.


## Some more pros and cons
Mostly Python-specific, but may apply to other languages.

Cons:
- If your language didn't support `async/await` from the get-go (as is the case for Python), chances are you're dealing with an ecosystem which is not built for `async/await`. See the logging example. To integrate with non-async third parties, you have to make use of threads to emulate asynchronous code. This comes with the extra cost of context switching, and all the other drawbacks of multithreaded code.
- You are limited to fairly specific IPC methods. `asyncio` is built upon the `select()` system call, which really only works for sockets.

Pros:
- Pit of success: if your domain is synchronous, then doing I/O inside your domain is painful, since you have to go down the call stack and make everything async. This makes it harder to fall into such anti-patterns as [lazy loading][lazy-loading-is-antipattern] or disconnected domain model.
- Since your code is single-threaded (barring thread pool based escape hatches), you eliminate certain things which make multi-threaded code hard to reason about, such as access to shared resources.
- Your code is more explicit about when exactly it does I/O, and that's actually a good thing.


[red-blue-original]: https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/
[async-python-is-not-faster]: https://calpaterson.com/async-python-is-not-faster.html
[lazy-loading-is-antipattern]: https://www.mehdi-khalili.com/orm-anti-patterns-part-3-lazy-loading
[python-in-depth-async-explanation]: https://example.com
[python-docs-gather]: https://docs.python.org/3/library/asyncio-task.html##asyncio.gather
[hexagonal-architecture]: https://alistair.cockburn.us/hexagonal-architecture/
[functional-core]: https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell
[io-monad]: https://www.microsoft.com/en-us/research/wp-content/uploads/1993/01/imperative.pdf
[1] I/O bound means that the execution time of the program is primarily made up of waiting on I/O, rather than being made up of expensive computations.
[2] A similar argument applies to applications structured according to [functional core, imperative shell][functional-core].

