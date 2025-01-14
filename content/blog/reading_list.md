+++
title = "Reading list"
date = "2025-01-02"
+++

## Books

### Accelerate
It's rare to see an evidence-based book in this field, and this is one. Following the advice in this book will make you a happier developer.

### Designing data-intensive applications
Especially the chapter on transactions is worth a read.

### Cosmic Python
An approachable introduction to various ideas from domain-driven design, in Python. Also contains some good ideas on how to fake out dependencies in tests.

### Head-first design patterns
Introduction to object-oriented design principles, using a couple of design patterns to illustrate them.

### Clean Code
If there's one chapter you read, let it be the chapter on wrapping third party dependencies. Take the "short methods" advice with a grain of salt, but not too much salt.

## Online

### [Manifesto for Agile Software Development](https://agilemanifesto.org/)
It's so short, there's no excuse for not reading it. Instead of reading this here, you could've read the manifesto at least twice, probably three times by the end of this sentence. Agile is not synonymous with scrum. SAFe has nothing whatsoever to do with agile. Four times. Internalize it.

### [microservices.io](https://microservices.io/)
This and the [corresponding book](https://microservices.io/book) are filled with gems and good insights on microservices architectures.

### [Unit and Integration Tests](https://matklad.github.io/2022/07/04/unit-and-integration-tests.html)
I actually disagree with part of this blog post. But it has significantly impacted the way I think about tests, so I include it here.

I am not a fan of the term unit test. Take five developers, and you'll have five definitions of "unit test". What is a unit anyway? This blog post gives a way of categorizing tests more useful than the usual unit-integration-e2e trichotomy. Aside from being poorly defined, there's also no inherent reason to prefer unit over integration over e2e tests (as in the testing pyramid). It's a good rule of thumb, but the underlying reasoning is obscured by vague terms like "unit" and "integration".

This blog post suggests qualifying your tests not in terms of the the discrete categories unit, integration, and e2e, but rather in terms of two metrics: purity, and extent. Roughly, __purity__ is meant in the same sense of purity in functional programming. More I/O is less pure, less is more. The __extent__ of a test is the fraction of your codebase it covers. See the post and its references for more details.

The key reason for having automated tests is to prevent changes from breaking your product. That is, ideally, your tests pass if and only if your product works. In particular, if your tests fail, then you want to be able to conclude that your product is broken. Otherwise, why care about failing tests at all? False failures make you distrust your test suite, and make you waste your time on fixing broken tests.

Flaky tests are a source of false failures, and a hard to debug source at that. As the purity of a test increases, the odds of flakiness lower. Moreover, I/O is slow, so purer tests tend to be faster (by a lot). When possible, prefer tests with high purity.

False failures are also the reason why you sometimes hear the advice "automated tests should test _behavior_, not structure". A failing test on a change which changes only structure and no behavior is a false failure. One way of decoupling your test suite from your code's structure is by increasing the extent of your tests. I'll illustrate this with an example.

Suppose you have some sorting function `sort`, composed of two (private) steps, `prep_array` and `finalize`:
```python
def sort(xs: list[int]) -> list[int]:
    prepped_array = prep_array(xs)
    return finalize(prepped_array)
```
A high-extent test suite would write tests for just the `sort` function. A low-extent test suite would have a test for `sort`, and then have narrower, more focused tests for `prep_array` and `finalize`. Now suppose you realize the `sort` function would be much more understandable in three steps, `bumfuzzle_array`, `discombobulate_array`, and `finalize_discombobulated`. If you do this refactor, the high extent test suite stays green (since it only tests `sort`), and the low extent suite fails (it tests `prep_array` and `finalize` individually). The closer you test to the boundary (the higher the extent of your test), the lower the odds that it tests structure rather than just behavior. When possible, prefer tests with high extent.

This example also illustrates a drawback of the high extent approach. Suppose we introduce a bug in `prep_array` (that is to say, a change which breaks `sort`). In the high-extent test suite, all our test suite will tell us at first glance is that there's a bug somewhere in `sort`, but not whether it's in `prep_array` or `finalize`. The low extent test suite will tell you right away that the bug is somewhere in `prep_array`. This is a definite drawback of the high-extent approach, and actually the reason the author gives for preferring the low-extent approach. I don't really have an argument, but I've found in trying both approaches that the good that test specificity does is outweighed by the harm that false failures do.

### [Parse, don't validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/)
There is always a schema, even if you put your fingers in your ears and go "LA LA LA LA". Having your code reflect this schema, and checking it at the boundary of your system, is a good thing. I much prefer it to getting a call at 3 in the morning from a customer saying that some very strange looking data has leaked into their database.

### [You'll regret using natural keys](https://blog.ploeh.dk/2024/06/03/youll-regret-using-natural-keys/)
This post gives reasons why using synthetic primary keys (a uuid, some increasing sequence) is a better idea than using natural ones (a social security number, an email address). For me, it boils down to the following facts:
- if my code isn't modelled wrong right now, it will probably be wrong at a later point in time;
- changing primary keys is very hard (e.g., they're used by clients of your api, who save it in their own databases; good luck fixing that).

Suppose I use a natural key for a table of persons (their social security number). By the first bullet, there's a good chance I'm wrong about my assumption that there's a 1-1 correspondence between people and their social security number (this is actually an example given by the author, this assumption is actually false). When that turns out to be the case, I'll be in a bad situation because of the second bullet.

### [Python Design Patterns](https://python-patterns.guide)
This is a well-argued introduction to object-oriented design principles from a pythonic perspective. Especially the composition over inheritance section is worth a read.

### [On Pair Programming](https://martinfowler.com/articles/on-pair-programming.html)
Pair programming is very fun and highly efficient if done well. It is horrible and slow if done poorly. Pair programming is more than just sitting down at the same terminal to write code. There are some non-trivial dos and don'ts, and it takes practice, skill, and effort to do pair programming right. Reading this post is a good first step.

### [The Ideal Domain-Driven Design Aggregate Store?](https://kalele.io/the-ideal-domain-driven-design-aggregate-store/)

A demonstration that you don't need a NoSQL store to store full aggregates. The binary JSON type in PostgreSQL gets you a long way.

### [Writing tests for external API calls](https://www.cosmicpython.com/blog/2020-01-25-testing_external_api_calls.html)
This problem is interesting to me, and I don't think there's a fully satisfactory answer. I've settled on making a port out of the third party API, using a fake adapter in my app's broader test suite, and testing the real adapter using [`vcrpy`](https://vcrpy.readthedocs.io/en/latest/), and I'm pretty happy with it.

### [Hexagonal architecture](https://alistair.cockburn.us/hexagonal-architecture/)
Also known as an onion architecture, or the ports and adapters architecture. Roughly, the idea is that your domain is at the center of your app, and all else depends on it. So the dependencies flow from the boundary of your app towards your domain. Your domain does not know what a SQL is.

### [Jepsen analyses](https://jepsen.io/analyses)
Fun analyses on the correctness of databases. This is the right place to find out where your personal database vendor is lacking, because some database vendors have been less than honest in their documentation in representing for example their ACID-compliance, even after being called out by a Jepsen analysis. These are serious analyses, but they're written with a sense of humor.

## Videos
### [Missing semester, git lecture](https://youtu.be/2sjqTHE0zok?si=NHen99qWwpVuZ-lP)
In general, the lectures from the missing semester are good, but especially the git lecture is very useful to watch. The [course homepage](https://missing.csail.mit.edu/) also contains notes for all of the lectures, which include hands-on exercises.

### [Microservices megadisasters](https://www.youtube.com/watch?v=gfh-VCTwMw8)
Goes into common (and deadly) mistakes when people build microservices. Good illustration of why asynchronous communication should be preferred in a distributed architecture.

### [Stop using mocks](https://www.youtube.com/watch?v=rk-f3B-eMkI)
Through an extended example, Harry Percival (one of the cosmic Python guys) demonstrates that by adopting a more detroit style approach to testing, you get more readable and more maintainable tests, and more importantly, tests which are less sensitive to structure changes (which is a good thing, see the Test Desiderata video series by Kent Beck). Well worth a watch if your go-to approach in faking out third parties is constructing a mock hell.

### [Test desiderata](https://youtube.com/playlist?list=PLlmVY7qtgT_lkbrk9iZNizp978mVzpBKl&si=EoyILEphHKKrcsIb)
In this series of shorts, Kent Beck goes over a number of good properties tests should have. In short, tests should be behavior-sensitive, structure-\emph{in}sensitive, readable, writable, fast, deterministic, automated, isolated, composable, specific, production-predictive, and inspiring (confidence). These are not pies in the sky. These properties can and should be achieved. They were planning on doing a bonus episode on tradeoffs, but judging from the time these videos came out, a pandemic prevented them from doing so. Beck also wrote a [post](https://medium.com/@kentbeck_7670/test-desiderata-94150638a4b3) on Medium about this.
