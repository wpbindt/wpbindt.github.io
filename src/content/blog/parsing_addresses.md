+++
title = "Parsing postal addresses with parser combinators"
date = "2025-01-03"
+++

A parsser is a function which turns unstructured data (usually a string) into structured data (for example an abstract syntax tree, or a list, etc). A __parser combinator__ is a function which combines simpler parsers into more complex ones. This post gives an example of using such parser combinators to construct a parser.

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

<postal-code> ::= <digit> <digit> <digit> <digit> <whitespace> <letter> <letter>
<city-name> ::= <word-sequence>
```
Going a bit deeper, we can specify the smaller parts, such as
```
<digit-sequence> = <digit> | <digit> <digit-sequence>
<word-sequence> = <word> | <word> <word-sequence>
<word> = <letter> | <letter> <word>
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
We want to parse Dutch addresses into structured data, so we'll need to have some structure we can parse them _into_. Here's some classes that kind of follow the structure of Dutch postal addresses:
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
ParseResult(result='\n', remainder=to_parse[1:])
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

### Mapping

### Ignoring tokens

### The full parser
Now, we can write a full parser for Dutch addresses:
```python
dutch_address = DutchAddress * (street_address < newline) & (postal_code < whitespace) & city_name
```
And indeed, running this (which you can do [here](https://github.com/wpbindt/parsing_dutch_postal_address)) on our example string yields:
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

Aside from some details, implementing our parser boils down to copying the Backus-Naur form, and flipping it upside down. It's very declarative, and I personally prefer it to other methods. As an exercise, try amending this parser to disallow leading 0s in the zipcode. Maybe consider using parser combinators the next time you find yourself in a parsing mood ([advent of code](https://adventofcode.com) is usually a nice place to try).
