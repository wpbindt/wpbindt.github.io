+++
title = "Parsing postal addresses with parser combinators"
date = "2025-01-03"
+++

A parser is a function which turns unstructured data (usually a string) into structured data (for example an abstract syntax tree, or a list, etc). A __parser combinator__ is a function which combines simpler parsers into more complex ones. This post gives an example of using such parser combinators to construct a parser. We'll see that parser combinators lead to declarative parsers, mirroring almost 1-1 the Backus-Naur form of what we're trying to parse. You'll find the code for this post [here](https://github.com/wpbindt/parsing_dutch_postal_address/blob/main/parse_postal_address.py).

## Dutch postal addresses
The kind of strings we'll consider are a simplified form of Dutch postal addresses. Here's an example:
```
TWEEDE BANANENSTRAAT 67
1012 AB KOMKOMMERVILLE
```
It consists of 
- a street, `TWEEDE BANANANENSTRAAT`, which is a bunch of words separated by spaces;
- a space;
- a house number, `67`;
- a newline;
- a zipcode, consisting of a four-digit number `1012`, a space, and two letters `AB`;
- a space
- the name of the city, which is just a bunch of letters, `KOMKOMMERVILLE`.

In reality, it's a little more complicated than that (for example, the two letters in the zipcode cannot be `SS`, `SA`, or `SD` because they refer to nazi organizations from WWII), but we'll consider this simplified version.

## Backus-Naur form
In [Backus-Naur form](https://en.wikipedia.org/wiki/Backus%E2%80%93Naur_form), this language can be expressed as
```
<dutch-address> ::= <street-address> <newline> <postal-code> <whitespace> <city-name>

<street-address> ::= <street-name> <whitespace> <house-number>
<street-name> ::= <word-sequence>
<house-number> ::= <digit-sequence>

<postal-code> ::= <digit-sequence> <whitespace> <letter> <letter>
<city-name> ::= <word-sequence>
```
Going a bit deeper, we can specify the smaller parts, such as
```
<digit-sequence> ::= <digit> | <digit> <digit-sequence>
<word-sequence> ::= <word> | <word> <whitespace> <word-sequence>
<word> ::= <letter> | <letter> <word>
```
This can be read as "a digit sequence is either a single digit, or a single digit followed by a digit sequence". That is to say, a digit sequence is a positive number of digits. Similarly for word sequence and word. Going even deeper, we get to the smallest parts of the language:
```
<letter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" 
             | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" 
             | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z"
<digit> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
<whitespace> ::= " "
<newline> ::= "\n"
```

## Structured representation of addresses
We want to parse Dutch addresses into structured data, so we'll need to have some structure we can parse them into. Here's some classes that kind of follow the structure of Dutch postal addresses:
```python
from dataclasses import dataclass

@dataclass(frozen=True)
class PostalCode:
    number_part: int
    letter_1: str
    letter_2: str


@dataclass(frozen=True)
class StreetAddress:
    street: str
    house_number: int


@dataclass(frozen=True)
class DutchAddress:
    street_address: StreetAddress
    city: str
    postal_code: PostalCode
```
They don't capture all the subtleties of our language (for example, the letter part of the zipcode are any two strings, both of which could contain any number of characters), but it's good enough for illustrative purposes. We could improve this by for example adding a `__post_init__` to `PostalCode`:
```python
@dataclass(frozen=True)
class PostalCode:
    number_part: int
    letter_1: str
    letter_2: str

    def __post_init__(self) -> None:
        if len(self.letter_1) != 1 or len(self.letter_2) != 1:
            raise Exception
```
Or even better, expressing it in the type system rather than validating, by having some `Letter` class which represents one single letter (for example an enum with 26 members, which I will not write down here).

## Parsing addresses
Now we get to writing a parser for this language using parser combinators. It makes use of a small parser combinator library I wrote, [`functional_parsing_library`](https://pypi.org/project/functional-parsing-library/), and the code for this section can be found [here](https://github.com/wpbindt/parsing_dutch_postal_address), so you can play around with the parsers yourself.  We'll start at the bottom of the Backus-Naur form, and work our way up. 

You're encouraged to follow along in a Python interpreter and play around with the parsers we construct. Install `functional_parsing_library` with
```bash
pip install functional_parsing_library==0.0.28
```
and run
```python
>>> from functional_parsing_library import *
```
in a Python interpreter.

### Single characters
First we define the newline parser:
```python
from functional_parsing_library import char
newline = char('\n')
```
This creates a function `newline` with type signature
```
newline : str -> ParseResults[Literal['\n']] | CouldNotParse
```
where `ParseResults` and `CouldNotParse` are defined as
```python
from dataclasses import dataclass
from typing import TypeVar, Generic

StructuredData = TypeVar('StructuredData')

@dataclass(frozen=True)
class ParseResults(Generic[StructuredData]):
    result: StructuredData
    remainder: str

class CouldNotParse:
    pass
```
The function `newline` successfully parses any string `to_parse` starting with `'\n'`, resulting in
```python
>>> to_parse = '\nabcd'
>>> newline(to_parse)
ParseResult(result='\n', remainder='abcd')
```
and it fails to parse any string _not_ starting with `'\n'`, resulting in `CouldNotParse`. Note that when `newline` successfully parses a string, it stores the remainder to be passed on to other parsers.

Similarly, we can define a parser `whitespace` by
```python
whitespace = char(' ')
```

### One of a set of tokens
Let's move up the Backus-Naur form. Next comes the parser for `<digit>`, which we'll call `digit`:
```python
digit = (
    char('0') | char('1') | char('2') | char('3') | char('4') 
    | char('5') | char('6') | char('7') | char('8') | char('9')
)
```
Here, we encounter our first combinator `|`, which can be read as "or". That is to say, `digit` parses any string starting with `'0'`, `'1'`, ..., `'9'`, stores the first character, and passes the remainder of the string on for further parsing. It fails on any string _not_ starting with a digit. Note that we've taken simpler parsers for single characters, like `char('0')`, and combined them into a more complex parser.

The parser `letter` for `<letter>` can be defined in a simlar way, which I'll leave as an exercise for the reader.

### Sequences 
Next, there's the part about the words and word sequences. These read, for example
```
<word> ::= <letter> | <letter> <word>
```
This recursive relation is hard to express in python (`word = letter | (letter & word)` will result in a `NameError` if `word` is not yet defined). But we can rewrite the definition of `<word>` in a kind of pseudo Backus-Naur form:
```
<word> ::= [many] <letter>
```
And for this, `functional_parsing_library` has a function, `many`. It takes one parser `p` parsing strings into some type `T`, and yields a parser which turns strings into type `list[T]`. More concretely, the parser `many(p)` tries to match as many matches for `p` as possible, and stores the result in a list. For example, parsing the string `abc1234` with the parser `many(letter)` will result in
```python
ParseResults(result=['a', 'b', 'c'], remainder='1234')
```
Now if we define `word = many(letter)`, then `word` will parse a sequence of letters into a list of characters. But this isn't quite what we want, because we want to model word just as a string. This is where mapping comes into play.

### Mapping
If we have a function `f: A -> B`, and a list `xs` of type `list[A]`, then we can get a list of type `list[B]` by applying `f` to each element of `xs` individually. In short, you run `list(map(f, xs))`. Parsers admit a similar structure. If we have a parser `p` for `A`, and a function `f: A -> B`, then we can define a parser `fmap(f, p)` for `B` by the following recipe:
- parse using `p`, yielding an object `result` of type `A`;
- apply `f` to `result`, yielding an object of type `B`.

The operator `functional_parsing_library` uses for this is `*`. So the parser `fmap(f, p)` can be written as `f * p`.

As an example, we can look at the parser `many(letter)`. It parses strings into an object of type `list[str]`. As our function, we'll take `''.join`, which concatenates a list of strings. Now, the parser
```python
word = ''.join * many(letter)
```
will first parse using the parser `many(letter)`, resulting in a list of characters, and then concatenate them using `''.join`, which is exactly what we want!

As an exercise, covince yourself that
```python
digit_sequence = int * (''.join * many(digit))
```
is a parser that parses sequences of digits into integers.

### Separator tokens
Next, we can define a parser for `<word-sequence>` as follows:
```python
word_sequence = ' '.join * separated_by(word, separator=whitespace)
```
Here, `separated_by` is a function similar to `many` in that it parses many matches for a given parser. The difference is that it also matches (and ignores) a separator character. So in this case, we match a bunch of words, separated by whitespaces, and at the end, we join them back together using `' '.join`.

### Ignoring tokens
Sometimes, we want to ignore tokens. For example, the definition of `<street-address>` reads
```
<street-address> ::= <street-name> <whitespace> <house-number>
```
Here, I really only care about the `<street-name>` and `<house-number>` parts, and the whitespace I don't really want to keep. The way to do this in `functional_parsing_library` is with the `<` operator. For example,
```python
word < whitespace
```
will match on `word` and then `whitespace`, and then only keep the result of `word`. So in parsing the string `'abcd '`, it will match `'abcd'` to `word`, and `' '` to `whitespace`, and ultimately result in `'abcd'`. I think of `<` as a little arrow saying "that one".

The operator `>` is defined in a similar way ("that one", but pointing to the right).

### Mapping over multiple arguments
Now let's try to implement a parser for `<street-address>`. A street address consists of a street name, followed by a whitespace, and then a house number, and we wish to turn this into an instance of our class `StreetAddress`. We can treat `StreetAddress` as a fucntion of two arguments, and we know how to ignore the whitespace, but we don't know how to do sequential parsing yet. The operator `&` is overloaded to do this:
```python
street_name = word_sequence
house_number = digit_sequence
street_address = StreetAddress * (street_name < whitespace) & (house_number)
```
So our parser parses a street name (and keeps the result), followed by a whitespace (whcih it ignores), then parses a house number, and finally applies `StreetAddress` to the two parsed objects.

As an aside, under the hood the sequence is a bit different. Actually it first parses `street_name < whitespace)`, then already it partially applies `StreetAddress` to yield a function 
```python
int -> StreetAddress
```
by filling in the `street_name` argument. Then it parses `house_number`, to which we finally apply the `int -> StreetAddress` function to get a `StreetAddress`. In particular, the statement
```python
(street_name < newline) & house_number
```
does not by itself make sense, because we don't know how to combine the string resulting from the left parser with the integer resulting from the right parser. Only when we specify how to combine them (in our case, apply `StreetAddress`) is the expression valid.

As an exercise, implement a parser for `<postal-code>`. If you get stuck, an implementation can be found [here](https://github.com/wpbindt/parsing_dutch_postal_address).

## The full parser
Finally, we are ready to combine our smaller parsers into a full parser for Dutch addresses:
```python
dutch_address = DutchAddress * (street_address < newline) & (postal_code < whitespace) & city_name
```
In words, parse a street address, followed by a newline, then parse a postal code, followed by a whitespace, and then parse a city name. Finally, apply `DutchAddress` to the result. And indeed, running this (which you can do [here](https://github.com/wpbindt/parsing_dutch_postal_address)) on our example string yields:
```python
>>> dutch_address('TWEEDE BANANENSTRAAT 67\n1012 AB KOMKOMMERVILLE').result
DutchAddress(
    street_address=StreetAddress(
        street='TWEEDE BANANENSTRAAT',
        house_number=67
    ),
    city=PostalCode(
        number_part=1012,
        letter_1='A',
        letter_2='B'
    ),
    postal_code='KOMKOMMERVILLE'
)
```

Aside from some details, implementing our parser boils down to copying the Backus-Naur form, and flipping it upside down. It's very declarative, and I personally prefer it to other methods. For example, a potential regular expression for parsing these addresses is 
```
([[A-Z]+ ]*[A-Z]+|[A-Z]+) (\d+)\n(\d\d\d\d) ([A-Z][A-Z]) ([[A-Z] ]*[A-Z]+|[A-Z]+)
```
and that makes me unhappy. Probably this expression is wrong, but I have funner things to do with my life than debugging regular expressions, for example filing my income tax.

As an exercise, try amending this parser to disallow leading 0s in the zipcode. Maybe consider using parser combinators the next time you find yourself in a parsing mood ([advent of code](https://adventofcode.com) is usually a nice place to try).
