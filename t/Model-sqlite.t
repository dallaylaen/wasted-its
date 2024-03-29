#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use File::Temp qw(tempfile);
use FindBin qw($Bin);
use DBI;

use App::Its::Wasted::Model;

# copy-paste: t/Model-sqlite.t
my $dbfile = shift;
(undef, $dbfile) = tempfile
    unless $dbfile;
my $fail;
$SIG{__DIE__} = sub { $fail++ };
END {
    if ($fail) {
        diag "Tests failed, db available at $dbfile"
    } else {
        unlink $dbfile;
    };
};

my $db = "dbi:SQLite:dbname=$dbfile";
my $dbh = DBI->connect( $db, '', '', { RaiseError => 1 } );
# end copy-paste: t/Model-sqlite.t

my $model = App::Its::Wasted::Model->new(
    config  => { status => {
        1 => 'Open',
        2 => 'Closed',
    }},
    dbh     => $dbh,
);

# must deploy schema by hand
my $sql = $model->get_schema_sqlite();
$dbh->do( $_ ) for split /;/, $sql; # this autodies

# Huh, let the tests begin
note "TESTING USER";

my $user = $model->add_user( name => "Foo", pass => "secret" );

is ($user, 1, "1st user on a clean db" );

$user = $model->add_user( name => "Bar", pass => "secret" );

is ($user, 2, "2nd user on a clean db" );

$user = $model->load_user( name => "Foo" );
is ($user->{user_id}, 1, "Fetching 1st user again" );
is ($user->{name}, "Foo", "Input round trip(3)" );
is ($user->{banned}, 0, "Not banned by default" );

note explain $user;

$model->add_user( name => "Commenter", pass => "secret" );
$model->add_user( name => "Solver", pass => "secret" );

note "TESTING ISSUE";

my $id = $model->save_issue(
    issue => { body => "explanation", summary => "summary" }
    , user => $user );

my $art = $model->get_issue( id => $id );

is ($art->{author}, "Foo", "Author as expected");
is ($art->{body}, "explanation", "Round-trip - body");
is ($art->{summary}, "summary", "Round-trip - summary");
is ($art->{seconds_spent}, 0, "0 time spent");
is ($art->{status}, "Open", "Default = open");

note explain $art;

note "TESTING TIME";

$model->log_activity( issue_id => $art->{issue_id}, user_id => 1, time => "1s" );
$model->log_activity( issue_id => $art->{issue_id}, user_id => 2, time => "2s" );
$model->log_activity( issue_id => $art->{issue_id}, user_id => 3, note => "comment" );
$model->log_activity( issue_id => $art->{issue_id}, user_id => 3 );
    # this should appear nowhere
$model->log_activity( issue_id => $art->{issue_id}, user_id => 4, note => "solution", solve_time => "1h" );

$art = $model->get_issue( id => $id );
is ($art->{seconds_spent}, "3", "3 time spent");

my $comments = $model->get_comments;

foreach my $extra( qw(created activity_id) ) {
    foreach (@$comments) {
        (delete $_->{$extra}) =~ /^\d+$/
            or die "Bad format of $extra, must be natural number";
    };
};
@$comments = sort {
    $a->{user_id} <=> $b->{user_id}
} @$comments;
is_deeply( $comments, [
    { user_id => 1, note => undef, user_name => "Foo", issue_id => 1,
         seconds => 1, fix_estimate => undef },
    { user_id => 2, note => undef, user_name => "Bar", issue_id => 1,
         seconds => 2, fix_estimate => undef },
    { user_id => 3, note => "comment", user_name => "Commenter", issue_id => 1,
         seconds => undef, fix_estimate => undef },
    { user_id => 4, note => "solution", user_name => "Solver", issue_id => 1,
         seconds => undef, fix_estimate => 60*60 },
], "Comments as expected" );

$art->{summary} .= "[solved]";
$model->save_issue( issue => $art, user_id => 4 );

$art = $model->get_issue( id => $id );

is ($art->{author}, "Foo", "Author preserved by edit");
is ($art->{summary}, "summary[solved]", "Summary was edited");

diag "SMOKE-TESTING SEARCH";

my $results = $model->search( terms => [ "expl" ] );

note explain $results;
is (ref $results, 'ARRAY', "Got array");
is (scalar @$results, 1, "Got 1 element");
is (scalar (grep { ref $_ ne 'HASH' } @$results), 0
    , "All results in array are hashes");

diag "SMOKE-TESTING REPORT";

$SIG{__DIE__} = \&Carp::confess;

my $rep = $model->browse( min_time_spent => 1, has_solution => 1, max_i_created => time + 100000, limit => 100 );
is (ref $rep, 'ARRAY', "Got array");
is (scalar @$rep, 1, "Got 1 element");
is (scalar (grep { ref $_ ne 'HASH' } @$rep)
    , 0, "All results in array are hashes");

note explain $rep;

$rep = $model->browse( count_only => 1 );
is (ref $rep, 'HASH', "Got hash for count");
is ($rep->{n}, 1, "1 item in count");

note explain $rep;

note "SMOKE TESTING WATCH";

$model->add_watch( user_id => 1, issue_id => 1);
$model->add_watch( user_id => 2, issue_id => 1);

is_deeply( $model->get_watch( user_id => 1, issue_id => 1 ), [1,2], "Get watch");

my $feed = $model->watch_feed( user_id => 1 );

is (ref $feed, 'ARRAY', 'Array returned');
is (scalar (grep { ref $_ ne 'HASH' } @$feed)
    , 0, "All results in array are hashes");
is (scalar @$feed, 3, "3 comments in feed");

note "SMOKE TESTING TAGS";

$model->tag_issue( issue_id => 1, tags => [ "r2d2", "c3po" ] );
my $tags = $model->get_tags( issue_id => 1 );

is_deeply( [sort values %$tags], [ "c3po", "r2d2" ], "Tags round trip" );

my $tagdata = $model->get_tag_stats( tag_like => "3" );

is (scalar @$tagdata, 1, "Got 1 tag" );
note explain $tagdata;

my $stat = $model->get_stats_total();
is ($stat->{issues}, 1, "Total 1 issue");

note explain $stat;

note "SMOKE TESTING PASSWORD RESET";

my $key  = $model->request_reset( user_id => 1 );
like ($key, qr/[A-Za-z0-9_~]{10,30}/, "A random key generated");
my $key2 = $model->request_reset( user_id => 1 );
isnt ($key, $key2, "Another key generated");

my $r_user = $model->confirm_reset( reset_key => $key );
is ($r_user, 1, "Reset round-trip" );
$r_user = $model->confirm_reset( reset_key => "foobared" );
is ($r_user, 0, "Reset failed" );

$model->delete_reset( user_id => 100 );
is ($model->confirm_reset( reset_key => $key ), 1, "Reset still present");

my $list = $model->list_reset();

is (scalar @$list, 1, "1 req in list");
is $list->[0]{reset_key}, $key2, "Last key got listed";
note "keys: $key, $key2";
note explain $list;

$model->delete_reset( user_id => 1 );
is ($model->confirm_reset( reset_key => $key ), 0, "Reset deleted");

done_testing;
