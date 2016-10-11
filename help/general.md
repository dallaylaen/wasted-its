General

##Purpose

**Potracheno** is a [tech debt](https://en.wikipedia.org/wiki/Technical_debt)
issue tracking system ([ITS](https://en.wikipedia.org/wiki/Issue_tracking_system)).

##Naming

*Potracheno* ("потрачено") is a Russian adjective with a meaning 
close to *wasted* or *spent*. 
It became a local meme after being incorrectly used
in *Grand Theft Auto* death scene localization.

## Description

Just like a normal ITS, *Potracheno* has tickets, which in turn have
comments, statuses, and a time tracking facility. [Markdown](/help/markdown)
is supported for both tickets and comments.

However, instead of tracking time spent *fixing* an issue, it rather
tracks time wasted *dealing with it*, aka
[total\_hours\_wasted\_here](http://stackoverflow.com/a/482129/280449).

Also unlike a normal ITS it has *solution proposals* which can be posted
for any issue. Those are just special comments with a time estimate.

## Usage
The intended usage is as follows.
All the inconveniences of the project should be
[posted here](/post), like:

* Poorly written code (each case separately);
* Hard to use APIs;
* Outdated libraries;
* Sloppy or missing internal tools;
* Slow or broken development/testing environment;
* Missing or broken tests;
* etc, etc, etc.

Then, as any developer encounters some of those beasts, he or she should
log the time wasted instead of doing actual work.

As statistics [accumulate](/report/http://localhost:5000/report?status_not=on&status=0&order_by=time_spent_s&order_dir=DESC),
it may become clear which parts of the system should be
rewritten, refactored, or otherwise improved on in the first place,
and how much time is affordable to spend on that.