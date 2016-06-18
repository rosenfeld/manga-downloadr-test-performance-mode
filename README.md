# Manga Downloader Performance Test Mode

## Background

Fábio Akita [wrote an article](http://www.akitaonrails.com/2016/06/07/manga-downloadr-improving-the-crystal-ruby-from-bursts-to-pool-stream)
comparing the performance of his implementations of his Manga Downloader in Elixir, Crystal and
Ruby.

While comparing them, his MRI version completed the tests on 27s, while Crystal took 21s,
JRuby took 30s and Elixir 16s.

Immediately I suspected there was something else going on rather than the language being the
culprit of such a big difference. It smelled like a design difference among the implementations
even if they might seem similar syntax wide. I also suspected about the HTTP client
implementation being faster in Elixir, but I found it weird that it could be that much faster.

So I decided to understand what the test mode was doing and wrote another program from scratch,
designing it with performance in mind for this particular use case.

There are improvements that I know that can be made both to the Elixir implementation as well as
to improve the performance of this Ruby implementation on MRI by using forks rather than threads
(there's a potential for improvement but I didn't actually implement to be sure that getting rid
of GIL would compensate the overhead of IPC between a forked child and its parent). Also, using
forks would complicate the code a little bit (I was thinking about using IO pipes for doing so).

The results I got with the implementation in this repository got similar results than
running the test mode with the Elixir program, both in MRI and in JRuby.

## Running the test mode

    bundle
    time ruby manga-downloader.rb

You may want to try other values for `workers_count`. It works with JRuby too.

## How the test mode works

Well, it's easy to see how it works by looking at `manga-downloader.rb`, but since I had to
spend some time understanding it from Akita's sources, I'll explain what it does to save your
time.

It downloads a page and extracts the chapter paths from it. Then, for each chapter path it
extracts the chapter page paths. Finally it downloads each of those pages and extract the image
path from each.

So, most of the time is spent on downloading pages and a bit of time on parsing those pages to
extract some paths from specific elements. The processing part is mostly spent on Nokogiri gem.

## Final considerations

By no means I'm trying to state that Ruby is as fast (or faster) than other languages. Nor I'm
saying people shouldn't be using Crystal or Elixir or whatever. I just wanted to make sure that
everyone understands that the language raw performance doesn't matter performance-wise if your
application is mostly I/O bound rather than CPU bound. There may be many reasons on why to choose
one language over another for this kind of application, but performance isn't one of those
reasons.

## Contributions

Feel free to point out other improvements you think could be made with a significant impact. I'm
already aware that replacing the thread-based approach by a fork-based one might improve
performance on MRI (I've been always frustrated by the sad state of real threading in MRI), so
if you want to give it a try and create other more sophisticated processors that would run
the Nokogiri HTML parse in a child fork (or a pool of forked children) and send the results back
to the parent using IO pipes, go ahead and send me a PR.

There's also a potential to save up to half a second by using a ConditionVariable and
abstract methods like `inc_tasks` and `dec_tasks` which could signal the variable.

Also, if you'd like to write an optimized version of this test mode in Elixir, it would be great
so that we could actually compare similar designs on different languages and confirm whether the
difference is huge or not.
