# NAME

Wasted ITS is a specialized issue tracker for assessing tech debt.

# DESCRIPTION

Just like a normal ITS, this one has issues, which in turn have comments and
time tracking facility.
However, instead of tracking time spent on *resolving* an issue,
it tracks time wasted *living with it*.

This is supposed to help track down the exact tech debt instances
that slow down and demotivate the team.

Features:

* users, issues, comments, and time tracking (like in a normal ITS);

* markdown support (with *<*code*>*...*<*/code*>*)
for issues & comments, editing issues;

* solution proposals with time estimate;

* issue tags similar to those on Stackoverflow;

* report showing issues with various properties;

* report showing solutions that take less time then
wasted on corresponding issues;

* watching issues & in-app activity stream;

* issue & comment search (SLQ-based, search engine planned);

* admin interface to ban/unban users;

* DB migration script; MySQL, sqlite support.

Planned:

* versioned editing of comments & issues;

* comment replies.

# BUGS

Lots of them. This product is still under heavy development, see TODO.

Please report any bugs or feature request to
https://github.com/dallaylaen/potracheno/issues

The project was originally started in 2016 under the name "Potracheno"
(and incorrect Russian translation of _WASTED_ in GTA).

# COPYRIGHT AND LICENSE

Copyright 2016-2024 [Konstantin S. Uvarin](https://github.com/dallaylaen).

This program is free software available under the same terms as Perl itself.
