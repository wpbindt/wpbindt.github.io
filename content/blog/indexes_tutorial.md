+++
title = "A guided tour through (B-tree) indexes"
date = "2025-01-04"
+++

### General structure

#### Talk (15 mins)
__Main point__: reading is faster, writing is slower, compound indexes are a thing.

#### Lab (30 mins)
__Main point__: get everyone to a point where they are confident to actively participate in a group discussion on indices.

In triples or pairs, depending on how large a fraction of the audience considers themselves comfortable with indexes (triples if few, pairs if many, or maybe just triples regardless). Participants should have access to an instance of MongoDB or PostgreSQL filled with example data (maybe both?). The idea is to have a bunch of questions on the theory of indices, the answers to which the participants can verify using the example database.

#### Group discussion (25 mins)
__Main point__: apply the theory to your own applications.

Probably in two or three groups, depending on the number of participants. Maybe one group per team. Idea is to discuss what's been learned in light of queries in the particpants' own codebases. Should be very loose, but with some leading questions to get the conversation started.

#### Plenary discussion (5 mins)
__Main point__: spread the insights gained from the group discussion.

Back to one single group, and participants from the groups from the previous section share (if they want) what they learned.

### Talk
- Definition of B tree (as vague as possible without losing ability to reason about B-trees
- Illustrate with picture of B-tree, showing how to read, and how to write (ish)
- Some bladibla about disk reads and pages, maybe
- Relation to MongoDB, PostgreSQL, Redis
- BSON?

### Lab
- What is the maximal height of a B-tree with n keys?
- If page size is 4kb, how much can you store on a tree with 4 layers?
- CQRS?
- `WHERE`
- sorting
- range queries
- why not just index all the things?
- projections 
- consider different shapes of data. Many a's for few b's, unique b for every a, etc
- Consider the sort order in compound indexes, and the effect it has on queries
- Illustrate ESR rule of thumb

#### Single index
```sql
SELECT * FROM table WHERE a=3
```
filler
```sql
SELECT * FROM table WHERE 1 <= unindexed_column < 3
```
filler
```sql
SELECT * FROM table ORDER BY indexed_column
```
filler
```sql
SELECT a FROM table WHERE a=3;
```

#### Compound indexes
Run
```sql
SELECT * FROM table WHERE a=3 AND b=5;
```
with no index, index on `a` and `b` separately, `(a, b)`, one on `(b, c)`, and one on `(a, b, c)`, and one on `(c, a, b)`.

```sql
SELECT * FROM table WHERE a < 3;
```
filler
```sql
SELECT * FROM table WHERE a < 3 AND b > 1;
```
filler
```sql
SELECT * FROM table WHERE a = 3 ORDER BY b;
```
filler
```sql
SELECT * FROM table ORDER BY a
```
Sort order of indexes


### Group discussion
- Find a read query in your codebase, and discuss what indexes it might benefit from. How do these indices affect parts of your codebase that write to this table? Find concrete examples.
