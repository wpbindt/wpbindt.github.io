---
layout: post
title:  "`git commit -m 'fix tests'`"
date:   2024-03-06 19:12:38 +0100
categories: test opinions programming
---

## `git commit -m 'fix tests'
This is a commit message I recently found myself writing a bunch of times when working in a codebase which wasn't designed with automated testing in mind. I spent a good 3 hours writing code where every commit message was some variation of "the code works, but this test doesn't". Time spent fixing false failures could be better spent adding/refining features or fixing bugs. It's a waste.

Most of the time, the cause of these false failures is unnecessary coupling between the automated tests and what they aim to test (the only reason I say "most of the time" instead of "always" is the qualifier "unnecessary"). This post lists some strategies to mitigate this kind of coupling.

## Coupling
There's a number of definitions of coupling floating around, and for some of them the argument in this post is valid, and I'm sure there's some for which it isn't, so let's make sure we're on the same page when I write "coupling". 

Suppose we have two things `f` and `g` (they might be functions, classes, microservices, etc). Suppose that when we make a change `d` in `f` we _must_ make a change in `g`. Then (and only then) do we say that `f` is coupled to `g` with respect to the change `d`. For example, if `f` is a function that is called by `g`, so
{% highlight python %}
def g():
    ...
    f()
    ...
{% endhighlight %}
then if we change the name of `f` to `h`, we _have to_ change `g` to
{% highlight python %}
def g():
    ...
    h()
    ...
{% endhighlight %}
So `f` is coupled to `g` with respect to changing the name of `f`.

I don't know who came up with this definition, but I learned it at [this][coupling-definition] talk by Kent Beck. There's also a chapter outlining this definition in his book _Tidy First?_

## Coupling and automated tests
Let's see what this definition means for automated tests. It follows from the definition that `git commit -m 'fix test x'` after making a change `d` to some component `f` is a consequence of `f` being coupled to test `x` with respect to `d`.

Sometimes this coupling is inevitable, and completely justified. For example, suppose `f` is a function which prints "hello world" to stdout, and suppose we have a test `test_that_f_prints_hello_world` which tests that it does. Then changing `f` to print "schmooby dooby" instead of "hello world" better force use to change the assert in `test_that_f_prints_hello_world` as well. That is, `f` is coupled to `test_that_f_prints_hello_world` with respect to changes in the string `f` prints to stdout, and that's inevitable, and I'm okay with that. The behavior of `f` changed, and the test which checks the behavior of `f` failed; that's just your test suite working as intended.

Sometimes, this coupling is not justifiable. For example, suppose the hello world function `f` prints "hello world" to stdout by calling `print('hello world')` somewhere. If we change this call to `import sys; sys.stdout.write('hello world')`, obviously `f` still works. It still prints "hello world" to stdout. Now, if `test_that_f_prints_hello_world` fails (in other words, if `f` is coupled to `test_that_f_prints_hello_world1` with respect to changing `print` to `sys.stdout.write` in `f`), that's a false failure. After all, the behavior of `f` hasn't changed in any way, just its structure. It si precisely this kind of coupling which causes false failures. Moreover, in this post we'll show some methods to avoid this kind of coupling.

Being coupled to automated tests with respect to _behavioral_ changes: inevitable, good, expected

Being coupled to automated tests with respect to _structural_ changes: unnecessary, time-consuming, (rightly) reduces trust in your test suite


## How to avoid coupling to tests with respect to structural changes
The key to avoiding unnecessary coupling to implementation details is the following truism: "test code is code". Any tool you have in your arsenal to achieve loose coupling in "regular" code can also be used to decouple your test suite from implementation details. Most of the strategies I'll mention ultimately follow from applying some well-known principle to automated tests.

- test interfaces, not concrete implementations
- [increase the scope of your test][unit-testing-overrated]
- spec pattern
- [prefer fakes over mocks][fakes-over-mocks]
- [don't fake what you don't own][dont-own-dont-mock]

# Test interfaces, not concrete implementations

# Increase the scope of your test

# Spec pattern

# Prefer fakes over mocks

# Don't fake what you don't own
Suppose you're implementing some public transport planning application, and your users are complaining that when they use your app they tend to forget to look outside to see if they need to bring an umbrella. You decide to help them out by adding clothing suggestions to your suggested routes. Simple enough, if your user asks for a route from A to B starting at 5:30PM, you do your usual computations, suggest them "Take bus 9 at 5:32PM", and you call out to some weather api to see if it's raining at 5:32PM. If it is, your app will suggest "Take bus 9 at 5:32PM, and bring an umbrella".

Thankfully, the good folks over at `weknowtheweather.com` publish a library containing a client class `Weather` for their API. It has a method `is_it_raining`, taking a time and a location in the form of GPS coordinates, and returning a boolean which tells whether it's raining then and there. You dutifully include it in your route planning routine somewhere. Maybe, on some high level it used to look something like
{% highlight python %}
def plan_route(
    from: Location, 
    to: Location, 
    time: datetime,
) -> PlannedRoute:
    ...
{% endhighlight %}
and after the change, it looks like
{% highlight python %}
def plan_route(
    from: Location, 
    to: Location, 
    time: datetime, 
    weather_api: Weather,
) -> PlannedRoute:
    ...
{% endhighlight %}
with `PlannedRoute` now containing some info on umbrellas.

Since you're a decent person (and more importantly, because you dislike flaky tests), you decide to write a fake version of `Weather` for use in your automated tests and your build pipelines. That is, you go directly against the advice of this section, you fake the `Weather` class, which you do not own. Your fake implementation looks exactly like their class (it has to, otherwise you couldn't substitute it for the real thing in your tests):
{% highlight python %}
class FakeWeather:
    def is_it_raining(self, time: datetime, at: str) -> bool:
        ...
{% endhighlight %}
This all works quite well, your users are happy with the umbrella feature, and you forget about it for a while. Then, disaster strikes. The `weknowtheweather.com` library contains a critical security flaw, and the fix is a couple major versions ahead of the one you're using. Annoyingly, the good folks over at `weknowtheweather.com` decided to make a backwards-incompatible change in their `Weather` class. Aside from the critical security patch, the `is_it_raining` method has been renamed to `check_rain_status`. 

In order for things to keep on working with this new version of the weather library, you now have to change two things: the `FakeWeather` class (`git commit -m 'Fix tests'`), and the `plan_route` routine. That is to say, your unit tests are coupled to the weather library with respect to name changes of `Weather.is_it_raining`.

Let's see what taking the advice in this section entails. It will get a bit verbose. Probably, the approach would look a little bit like this
{% highlight python %}
class MyWeather(ABC):
    @abstractmethod
    def is_it_raining(self, time: datetime, at: Location) -> bool:
        pass

class MyWeatherAdapter(MyWeather):
    def __init__(self, weather: Weather):
        self._weather = weather

    def is_it_raining(self, time: datetime, at: Location) -> bool:
        gps_string = convert_our_location_to_gps_string(at)
        return self._weather.is_it_raining(time, gps_string)

class MyFakeWeather(MyWeather):
    def is_it_raining(self, time: datetime, at: Location) -> bool:
        # pretty much the same implementation as FakeWeather
        ...
        
{% endhighlight %}
And instead of injecting `Weather` into `plan_route`, you inject an instance of the `MyWeather` interface:
{% highlight python %}
def plan_route(
    from: Location, 
    to: Location, 
    time: datetime, 
    weather_api: MyWeather,
) -> PlannedRoute:
    ...
{% endhighlight %}

Now, if the good folks over at `weknowtheweather.com` decide to rename `is_it_raining` to `check_rain_status`, only one class changes, namely the adapter:
{% highlight python %}
class MyWeatherAdapter(MyWeather):
    def __init__(self, weather: Weather):
        self._weather = weather

    def is_it_raining(self, time: datetime, at: Location) -> bool:
        gps_string = convert_our_location_to_gps_string(at)
        return self._weather.check_rain_status(time, gps_string)
{% endhighlight %}
The tests stay unchanged. An added benefit is that the `plan_route` routine is unchanged as well, which is means you have a lower risk of introducing bugs there. Fewer changes to make, happier developer.

Ah but wait, it seems all is not well with this approach. Let's assume we have no static type check in our build pipeline. Nothing would've stopped us from merging the major `Weather` version bump without changing the adapter. After all, not a single test hits it.


[dont-own-dont-mock]: https://hynek.me/articles/what-to-mock-in-5-mins/
[coupling-definition]: https://piped.video/watch?v=yBEcq23OgB4
[fakes-over-mocks]: https://tyrrrz.me/blog/fakes-over-mocks
[unit-testing-overrated]: https://tyrrrz.me/blog/unit-testing-is-overrated

