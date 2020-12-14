# Performance tuning tips

This document gives some tips about how to increase the performance off typhonql queries.

## Deployment

First, make sure you've deployed ql in a setting that enables performance:

- Give it at least 2GB of memory
- Do not limit the CPU access
- If you are running the full suite (analytics, evolution, multiple backends) make sure the machine has 8GB+ available for these docker machines
- Tune memory limits of different components
- If you are running NLP on the same machine, add another 8GB of memory requirements
- Inspect `docker stats` when running a query to see which container is consuming memory and cpu.
- If you are running on kubernetes, you can scale-out the QL engine behind a service. Every ql engine is stateless, and queues requests depending on the memory allocated to the container.
- DL support configuring cluster versions of mongodb and mariadb for kubernetes deployment.

## Query tips

### Parameterized insert/update/delete

If the code is sending seperate insert/update statements, this is most likely the bottleneck. Our query compilation is relativly complex (and less tuned for performance). For this specific reason we added [parameterized queries](typhonql.md#parameterized-queries) (inspired by most other db connectors that have a similar mode).

With parameterized queries you supply the query once, and a list of bindings to placeholders in that query. QL only has to compile the query once, and then run the generated plan for every row in the `boundRows` matrix. This brings great performance benefits.

The code might has to be changed to either collect incoming data for a few seconds and only then send if to the QL server, or if it's coming from an existing dataset, just iterate in chunks over the source data.

### Slow select queries

If your queries are slow, think of the following aspects:

- add indexes in ML on the columns used in the where expressions
- if you expect big data results, try improving the where clauses (or the model) so that we can strip away data earlier. While we support `limit` and `offset` due to the multiple backends, they won't prevent us from downloading all the data
- only select the columns you need
- if you frequenlty want to join 2 entities, consider putting them on the same backend (if the data concerns fit the domain of the backend)


### Use the @id as identity

All QL entities get an uuid identity. You can access this as the special `@id` field. Some specific tips around UUID/@id:

- We generate it if not supplied, but for some batch processing, it can be nice to set the `@id` field during the `insert`.
- if you have an existing unique identifier and it has less than 122bits, you can fit directly into a [version4 UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier#Version_4_(random)). If it's more than 122bit, you can use a [version 5 UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier#Versions_3_and_5_(namespace_name-based)) to hash the value before turning it into a uuid.

### use native types instead of string

Typhon has many datatypes, `string[size]`, `text` `int` (32bit), `bigint`(64 bit), `date`, `datetime`, `point`, `polygon`, and `blob`. Try to use the most accurate one for your case.

## Measuring performance

- Every QL query response HTTP header contains a `QL-Wall-Time-Ms` value. This is the absolute time the query spent in compiling, running, assembling results. Next to the global wall clock time, measure this value to get a sense of incorrectly configured scaling.
- `QL-Wall-Time-Ms` also helps figure out overhead of other components like analytics and evolution.
- monitor the containers for unexpected cpu or memory spikes
- QL has a startup time of roughly 30s (which is delayed per request, so depending on the internal scaling you can see this a few times). If this is much longer, check the Deployment section. 
- Do a warmup run of the queries for a few minutes
- Reset databases before doing measurements

