package Potracheno::Model;

use strict;
use warnings;
our $VERSION = 0.0107;

use DBI;
use Digest::MD5 qw(md5_base64);

use parent qw(MVC::Neaf::X::Session);

sub new {
    my ($class, %opt) = @_;

    my $self = bless \%opt, $class;

    $self->{dbh} = DBI->connect($opt{db_handle}, $opt{db_user}, $opt{db_pass},
        { RaiseError => 1 });

    return $self;
};

sub dbh { return $_[0]->{dbh} };

my $sql_user_by_id   = "SELECT user_id,name FROM user WHERE user_id = ?";
my $sql_user_by_name = "SELECT user_id,name FROM user WHERE name = ?";
my $sql_user_insert  = "INSERT INTO user(name) VALUES(?)";

sub get_user {
    my ($self, %opt) = @_;

    my $name = $opt{name};

    my $dbh = $self->{dbh};
    my $sth_insert = $dbh->prepare($sql_user_insert);
    my $sth_select = $dbh->prepare($sql_user_by_name);

    $sth_select->execute( $name );
    if (my $data = $sth_select->fetchrow_hashref) {
        return $data;
    };

    $sth_insert->execute( $name );
    $sth_select->execute( $name );
    if (my $data = $sth_select->fetchrow_hashref) {
        return $data;
    };
    die "Failed to either find or create user name=$name";
};


sub load_user {
    my ($self, %opt) = @_;

    my $where = '';
    my @arg;
    foreach (qw(user_id name)) {
        defined $opt{$_} or next;
        $where .= " AND $_ = ?";
        push @arg, $opt{$_};
    };
    die "No conditions found" unless @arg;

    my $sth = $self->{dbh}->prepare( "SELECT * FROM user WHERE 1 = 1".$where );
    $sth->execute(@arg);

    my ($data) = $sth->fetchrow_hashref;
    $sth->finish;
    return $data;
};

sub login {
    my ($self, $name, $pass) = @_;

    my $user = $self->load_user( name => $name );
    return unless $user;

    my $crypt = $self->make_pass( $user->{password}, $pass );
    return unless $crypt eq $user->{password};

    return $user;
};

my $sql_user_ins = <<'SQL';
INSERT INTO user(name,password) VALUES (?,?);
SQL

sub add_user {
    my ($self, $user, $pass) = @_;

    my $crypt = $self->make_pass( $self->get_session_id.'#', $pass );
    my $sth = $self->dbh->prepare( $sql_user_ins );
    eval {
        $sth->execute( $user, $crypt );
    };
    return if ($@ =~ /unique/);
    die $@ if $@; # rethrow

    my $id = $self->dbh->last_insert_id("", "", "issue", "issue_id");
    return $id;
};

sub make_pass {
    my ($self, $salt, $pass) = @_;

    $salt =~ s/#.*//;
    return join '#', $salt, md5_base64( join '#', $salt, $pass );
};

my $sql_art_ins = "INSERT INTO issue(summary,body,author_id,posted) VALUES(?,?,?,?)";
my $sql_art_sel = <<"SQL";
    SELECT a.issue_id AS issue_id, a.body AS body, a.summary AS summary
        , a.author_id AS author_id, u.name AS author
        , a.posted AS posted
    FROM issue a JOIN user u ON a.author_id = u.user_id
    WHERE a.issue_id = ?;
SQL
sub add_issue {
    my ($self, %opt) = @_;

    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare( $sql_art_ins );
    $sth->execute( $opt{summary}, $opt{body}, $opt{user}{user_id}, time );

    my $id = $dbh->last_insert_id("", "", "issue", "issue_id");
    return $id;
};

sub get_issue {
    my ($self, %opt) = @_;

    my $sth = $self->{dbh}->prepare( $sql_art_sel );
    my $rows = $sth->execute( $opt{id} );
    my $data = $sth->fetchrow_hashref;
    $sth->finish;

    $data->{time_spent} = $self->get_time( issue_id => $opt{id} );

    return $data;
};

my $sql_time_ins = "INSERT INTO time_spent(user_id,issue_id,seconds,note,posted) VALUES(?,?,?,?,?)";
my $sql_time_sum = "SELECT sum(seconds) FROM time_spent WHERE 1 = 1";
sub add_time {
    my ($self, %opt) = @_;

    my $sth = $self->{dbh}->prepare( $sql_time_ins );
    $sth->execute( $opt{user_id}, $opt{issue_id}, $opt{time}
        , $opt{note}, $opt{posted} || time );
};

sub get_time {
    my ($self, %opt) = @_;

    my $where = '';
    my @arg;
    foreach (qw(user_id issue_id)) {
        defined $opt{$_} or next;
        $where .= " AND $_ = ?";
        push @arg, $opt{$_};
    };

    my $sth = $self->{dbh}->prepare( $sql_time_sum . $where );
    $sth->execute( @arg );

    my ($t) = $sth->fetchrow_array;
    $t ||= 0;
    return $t;
};

my $sql_time_sel = "SELECT
    t.time_spent_id AS time_spent_id,
    t.issue_id AS issue_id,
    t.user_id AS user_id,
    u.name AS user_name,
    t.seconds AS seconds,
    t.note AS note,
    t.posted AS posted
FROM time_spent t JOIN user u USING(user_id)
WHERE 1 = 1";
sub get_comments {
    my ($self, %opt) = @_;

    my $where = '';
    my @arg;
    foreach (qw(user_id issue_id)) {
        defined $opt{$_} or next;
        $where .= " AND $_ = ?";
        push @arg, $opt{$_};
    };
    my $sort = '';
    if ($opt{sort}) {
        $opt{sort} =~ /^([-+]?)(\w+)/;
        my $by = $2;
        my $desc = $1 eq '-' ? ' DESC' : '';
        $sort = " ORDER BY $by$desc";
    };

    my $sth = $self->{dbh}->prepare( $sql_time_sel . $where . $sort );
    $sth->execute( @arg );

    my @ret;
    while (my $data = $sth->fetchrow_hashref) {
        push @ret, $data;
    };

    if ($opt{sort}) {
        $opt{sort} =~ /^([-+]?)(\w+)/;
        my $by = $2;
        my $desc = $1 eq '-' ? 1 : 0;
        use warnings FATAL => 'all';
        @ret = sort { $a->{$by} <=> $b->{$by} } @ret;
        @ret = reverse @ret if $desc;
    };

    return \@ret;
};

my $sql_search_art = <<"SQL";
SELECT issue_id, 0 AS comment_id, body, summary, posted FROM issue WHERE
SQL

sub search {
    my ($self, %opt) = @_;

    my $terms = $opt{terms};
    return [] unless $terms and ref $terms eq 'ARRAY' and @$terms;

    my @terms_sql = map { my $x = $_; $x =~ tr/*?\\'/%___/; "%$x%" } @$terms;
    my @terms_re  = map {
        my $x = $_; $x =~ tr/?/./; $x =~ s/\*/.*/g; $x =~ s/\\/\\\\/g; $x
    } @$terms;
    my $match_re  = join "|", @terms_re;
    $match_re     = qr/(.{0,40})($match_re)(.{0,40})/;

    my $where = join ' AND '
        , map { "(body LIKE '$_' OR summary LIKE '$_')" } @terms_sql;

    my $order = "ORDER BY posted DESC"; # TODO $opt{sort}

    my $sth = $self->{dbh}->prepare( "$sql_search_art $where $order" );
    $sth->execute;

    my @result;
    FETCH: while ( my $row = $sth->fetchrow_hashref ) {
        my @snip;
        foreach my $t( @terms_re ) {
            $row->{summary} =~ /(.{0,40})($t)(.{0,40})/i
                or $row->{body} =~ /(.{0,40})($t)(.{0,40})/i
                or next FETCH;
            push @snip, [ $1, $2, $3 ];
        };
        $row->{snippets} = \@snip;
        push @result, $row;
    };

    return \@result;
};

my $sql_sess_load = <<'SQL';
SELECT u.user_id, u.name
FROM user u JOIN sess s USING(user_id)
WHERE s.sess_id = ?
SQL

my $sql_sess_upd = <<'SQL';
UPDATE sess SET user_id = ? WHERE sess_id = ?
SQL

sub load_session {
    my ($self, $id) = @_;

    my $sth = $self->dbh->prepare($sql_sess_load);

    $sth->execute( $id );
    my ($user_id, $name) = $sth->fetchrow_array;
    $sth->finish;

    return { user_id => $user_id, user_name => $name };
};

sub save_session {
    my ($self, $id, $data) = @_;

    my $sth_ins = $self->dbh->prepare(
        "INSERT INTO sess(sess_id,user_id,created) VALUES (?,?,?)" );
    eval {
        $sth_ins->execute($id, $data->{user_id}, time);
    };
    # ignore insert errors
    die $@ if $@ and $@ !~ /unique/i;

    my $sth = $self->dbh->prepare($sql_sess_upd);
    $sth->execute( $data->{user_id}, $id );
};

1;
