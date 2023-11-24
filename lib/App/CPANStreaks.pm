package App::CPANStreaks;

use 5.010001;
use strict;
use warnings;
use Log::ger;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

our %actions = (
    'calculate' => 'Calculate and display a streak table',
    'list-tables' => 'List available streak tables',
);
our @actions = sort keys %actions;

our %tables = (
    'daily-releases' => 'CPAN authors that release something everyday',
);
our @tables = sort keys %tables;

$SPEC{cpan_streaks} = {
    v => 1.1,
    summary => 'Calculate and display CPAN streaks',
    args => {
        action => {
            schema => ['str*', {in=>\@actions, 'x.in.summaries' => [map { $actions{$_} } @actions]}],
            cmdline_aliases => {
                list_tables => {is_flag=>1, code=>sub { $_[0]{action} = 'list-tables' }, summary>'Shortcut for --action=list-tables'},
            },
            default => 'calculate',
            req => 1,
            pos => 0,
        },
        table => {
            schema => ['str*', {in=>\@tables, 'x.in.summaries'=>[map { $tables{$_} } @tables]}],
            pos => 1,
        },
    },
};
sub cpan_streaks {
    my %args = @_;
    my $action = $args{action} or return [400, "Please specify action"];
    my $table = $args{table};

    if ($action eq 'list-tables') {
        return [200, "OK", \%tables];
    } elsif ($action eq 'calculate') {
        require TableData::Perl::CPAN::Release::Static;
        require DateTime;
        require DateTime::Format::ISO8601;
        require Set::Streak;

        my $td = TableData::Perl::CPAN::Release::Static->new;
        my @sets;
        my ($min_time, $max_time);

        if ($table eq 'daily-releases') {
            my $cur_date;
            log_trace "Creating sets ...";
            $td->each_row_hashref(
                sub {
                    my $row = shift;
                    my $dt = DateTime::Format::ISO8601->parse_datetime($row->{date});
                    my $date = DateTime->ymd;
                    if (!$cur_date) {
                        $cur_date = $date;
                        push @sets, [];
                    } elsif ($cur_date ne $date) {
                        $cur_date = $date;
                        push @sets, [];
                    } else {
                        push @{ $sets[-1] }, $row->{author} unless grep { $_ eq $row->{author} } @{ $sets[-1] };
                    }
                });
            log_trace "Calculating streaks ...";
            my $res = Set::Streak::gen_longest_streaks_table(
                sets => \@sets,
            );
            return [200, "OK", $res];
        } else {
            return [404, "Unknown streak table '$table'"];
        }

    } else {
        return [400, "Unknown action '$action'"];
    }
}

1;
#ABSTRACT: Calculate various CPAN streaks

=head1 DESCRIPTION


=head1 SEE ALSO

=cut
