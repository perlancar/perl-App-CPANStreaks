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
    'daily-releases'            => 'CPAN authors that release something everyday',
    'daily-distributions'       => 'CPAN authors that release a (for-them) new distribution everyday',
    'daily-new-distributions'   => 'CPAN authors that release a new distribution everyday',
    'weekly-releases'           => 'CPAN authors that release something every week',
    'weekly-distributions'      => 'CPAN authors that release a (for-them) new distribution every week',
    'weekly-new-distributions'  => 'CPAN authors that release a new distribution every week',
    'monthly-releases'          => 'CPAN authors that release something every month',
    'monthly-distributions'     => 'CPAN authors that release a (for-them) new distribution every month',
    'monthly-new-distributions' => 'CPAN authors that release a new distribution every momth',
);
our @tables = sort keys %tables;

$SPEC{cpan_streaks} = {
    v => 1.1,
    summary => 'Calculate and display CPAN streaks',
    args => {
        action => {
            schema => ['str*', {in=>\@actions, 'x.in.summaries' => [map { $actions{$_} } @actions]}],
            cmdline_aliases => {
                list_tables => {is_flag=>1, code=>sub { $_[0]{action} = 'list-tables' }, summary=>'Shortcut for --action=list-tables'},
            },
            default => 'calculate',
            req => 1,
            pos => 0,
        },
        table => {
            schema => ['str*', {in=>\@tables, 'x.in.summaries'=>[map { $tables{$_} } @tables]}],
            pos => 1,
        },
        author => {
            summary => 'Only calculate streaks for certain authors',
            schema => 'cpan::pause_id*',
        },
        exclude_broken => {
            schema => 'bool*',
            default => 1,
        },
        min_len => {
            schema => 'posint*',
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
        require Set::Streak;
        my @period_names = (''); # index=period, value=name

        my $td;
        if ($table =~ /daily/) {
            require TableData::Perl::CPAN::Release::Static::GroupedDaily;
            $td = TableData::Perl::CPAN::Release::Static::GroupedDaily->new;
        } elsif ($table =~ /weekly/) {
            require TableData::Perl::CPAN::Release::Static::GroupedWeekly;
            $td = TableData::Perl::CPAN::Release::Static::GroupedWeekly->new;
        } else {
            require TableData::Perl::CPAN::Release::Static::GroupedMonthly;
            $td = TableData::Perl::CPAN::Release::Static::GroupedMonthly->new;
        }

        log_trace "Creating sets ...";
        my @sets;
        my (%seen_dists, %seen_author_dists);
        $td->each_row_arrayref(
            sub {
                my $row = shift;
                my ($period, $rels) = @$row;
                push @period_names, $period;
                push @sets, [];
                for my $rel (@$rels) {
                    my ($author, $dist) = ($rel->[2], $rel->[7]);
                    if (defined $args{author}) { next unless $author eq $args{author} }
                    if ($table =~ /-new-distributions/) {
                        next if $seen_dists{$author}{$dist}++;
                    } elsif ($table =~ /-distributions/) {
                        next if $seen_author_dists{$author}{$dist}++;
                    }
                    push @{ $sets[-1] }, $author unless grep { $_ eq $author } @{ $sets[-1] };
                }
                1;
            });
        log_trace "Calculating streaks ...";
        my $rows = Set::Streak::gen_longest_streaks_table(
            sets => \@sets,
            exclude_broken => $args{exclude_broken},
            min_len => $args{min_len},
        );
        for my $row (@$rows) {
            $row->{start_date} = $period_names[ $row->{start} ];
            if ($row->{status} eq 'broken') {
                my $p = $row->{start} + $row->{len} - 1;
                $row->{end_date} = $period_names[ $p ];
            }
            delete $row->{start};
            $row->{author} = delete $row->{item};
        }
        return [200, "OK", $rows, {'table.fields'=>[qw/author len start_date end_date status/]}];

    } else {

        return [400, "Unknown action '$action'"];

    }
}

1;
#ABSTRACT: Calculate various CPAN streaks

=head1 DESCRIPTION


=head1 SEE ALSO

=cut
