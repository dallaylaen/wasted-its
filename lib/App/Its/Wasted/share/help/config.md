Configuration & Troubleshooting

## Contents of this package

* `bin` - scripts & tools (see below)
* `help` - help files in markdown
* `html` - static files (will be served automatically)
* `lib` - libraries
* `local` - files not to be stored in Git.
* `sql` - SQL schemas for MySQL and SQLite.
* `t` - tests
* `tpl` - templates using Template::Toolkit

## Configuration

Configuration is located at `local/potracheno.cfg`.
It uses a homegrown ini-like format, which is a shame.
Format is as follows:

<code>
[section]
param = "value"
# ...
</code>

It is possible to use variables, like $(ROOT). This all has to be rewritten
in v.0.20+

The following sections are expected:

### db

Database config, most likely just where the SQLite is.

* handle - [DBI](https://metacpan.org/pod/DBI)-compatible database description.

* `user` - if db server is used, username

* `pass` - if db server is used, password

### status

List of issue status names.
Keys must be integer numbers from 1 to 100.
Status id 1 MUST be present, others are optional.

The general idea is that tickets advance gradually from 1 to 100 over time.

### server

_This only affects `./Start.PL` and is ignored by application itself._

* `port`
* `pidfile`
* `error_log`
* `access_log`
* `server` - which PSGI to run, defaults to `plackup`

### search

* `limit` - search results per page.
Does not affect reports & browse,
which is a bug.

### security

* `members_only` - only allow logged in users, display a 403 for anonymous.
May be useful if a severe NDA is in place.
* `members_moderated` - only allow users after approval by admin

### update

* `interval` = seconds - how ofter to check for newer version on github.
Install.PL will generate this section, remove by hand if paranoid.

* `cooldown` = seconds - how long to wait before next attempt if fetching
new version info failed.
Defaults to interval / 10.

A usable configuration file is generated by Install.PL (see below).

## Scripts and tools

*All scripts described below have a --help option that outputs usage summary.*

* `Install.PL` - make a local installation of Potracheno.
Will create a local directory, put a default config there, and
also download Neaf framework if you don't have it and
make a fresh sqlite db.

* `Start.PL` - init-script accepting start, stop, and restart options.
Run Potracheno on a Unix-like system.

* bin/potracheno-admin.pl

* bin/potracheno-backup.pl - dump & restore DB content.
Use this script for backup, or when updating the tool. I.e.

<code>
bin/potracheno-backup.pl --config local/potracheno.cfg --dump local/dump.txt
git pull
mv local/potracheno.sqlite local/potracheno.sqlite.bak
perl -MApp::Its::Wasted -we 'print get_schema_sqlite()' |\
    sqlite3 local/potracheno.sqlite
bin/potracheno-backup.pl --config local/potracheno.cfg --restore local/dump.txt
</code>

* bin/potracheno-dbcheck.pl - test whether the configured database is suitable
for Potracheno, by doing some simple requests.

* bin/potracheno-lostpass.pl - generate links for users who want 
a forced password change.

* bin/potracheno.psgi - finally, the application itself.
Unless Start.PL is being used, run it as
<code>
plackup bin/potracheno.psgi
</code>

`bin/potracheno.psgi --list` will print a summary of enabled endpoints instead
and is a valid method of checking the application before running.

## Automatic update

Starting from version 0.11, _Potracheno_ will search for a newer version on
github.com periodically and output a red "new version available" box
in the footer if found. No calling home apart from that.

This can be turned off (by setting update interval to 0), but is on by default.

## Troubleshooting

Please reach out to the author of this package (khedin@gmail.com)
if you notice any bugs.
Feedback & patches welcome.

