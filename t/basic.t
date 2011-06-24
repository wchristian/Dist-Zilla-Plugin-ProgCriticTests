use strict;
use warnings;
use Test::More 0.88;

use lib 't/lib';
use lib 'lib';
use lib '../lib';

use autodie;
use Test::DZil;
use Try::Tiny;
use Capture::Tiny qw/capture tee/;

check_creation();
check_pass();
check_fail();
check_severity();
check_step_size();
check_profile();
check_exclude();

done_testing;

exit;

################################################################################

sub check_creation {
    
    my $tzil = create_tzil( 'DZT' );
    $tzil->build;

    my @files = map $_->name, @{ $tzil->files };

    is_filelist(
        \@files,
        [
            qw(
              basic_profile dist.ini
              perlcritic_history
              lib/DZT/Sample.pm t/basic.t
              t/author-critic_progressive.t
              Makefile.PL
              )
        ],
        "all files present",
    );
    
    my $root = $tzil->root->absolute;
    $root = qr/\Q$root\E/;
    my $test_program = $tzil->slurp_file("build/t/author-critic_progressive.t");
    
    like ( $test_program, $root, "root path is inserted into created test script" );
    
    return;
}

sub check_pass {
    my $res = test_in_tzil( 'DZT' );
    
    like( $res->{stdout}, qr/critic_progressive/s, 'test name mentioned in stdout' );
    is( $res->{error}, undef, 'no errors on clean dist' );
    is( $res->{stderr}, '', 'empty stderr on clean dist' );
    
    return;
}

sub check_fail {
    my $res = test_in_tzil( 'DZF' );
    
    like( $res->{error}, qr/error running.*test/, 'tests fail on unclean dist' );
    like( $res->{stderr}, qr/Got \d+ violation\(s\)\.  Expected no more than 0\./, 'errors complain about more than 0 violation' );
    
    return;
}

sub check_severity {
    my $res = test_in_tzil( 'DZT', { severity => 2 } );
    
    like( $res->{error}, qr/error running.*test/, 'tests fail on stricter severity' );
    like( $res->{stderr}, qr/ProhibitUnlessBlocks.*Got \d+ violation\(s\)\.  Expected no more than 0\./, 'errors complain about violations of stricter severity' );
    
    return;
}

sub check_step_size {
    my $res = test_in_tzil( 'DZT', { severity => 4, step_size => 1 } );
    
    like( $res->{error}, qr/error running.*test/, 'tests fail on higher step sizes severity' );
    like( $res->{stderr}, qr/Too many Perl::Critic violations/, 'errors complain about too many violations on higher step sizes' );
    
    return;
}

sub check_profile {
    my $res = test_in_tzil( 'DZF', { profile => 'critic_profile' } );
    
    is( $res->{error}, undef, 'no errors with profile excluding policies' );
    is( $res->{stderr}, '', 'empty stderr with profile excluding policies' );
    
    return;
}

sub check_exclude {
    my $res = test_in_tzil( 'DZF', { exclude => 'ProhibitNestedSubs' } );
    
    is( $res->{error}, undef, 'no errors with explicit excluding of policies' );
    is( $res->{stderr}, '', 'empty stderr with explicit excluding of policies' );
    
    return;
}

################################################################################

sub test_in_tzil {
    my ( $dist, $prog_params ) = @_;
    
    my $tzil = create_tzil( $dist, $prog_params );

    my ($error, $stdout, $stderr);
    
    ($stdout, $stderr) = capture {
        $error = try {
            my $wd = File::pushd::pushd($tzil->root);
            $tzil->test;
            return;
        }
        catch { return $_; };
    };
    
    my %result = (
        error => $error,
        stdout => $stdout,
        stderr => $stderr,
    );
    
    return \%result;
}

sub create_tzil {
    my ( $dist, $prog_params ) = @_;
    
    $prog_params->{history_file} = "perlcritic_history";
    $prog_params->{profile} ||= "basic_profile";
    my $prog_plugin = [ ProgCriticTests => $prog_params ];

    my $ini = simple_ini( 'GatherDir', 'MakeMaker', 'ExtraTests', $prog_plugin );
    
    my @config = (
        { dist_root => "corpus/$dist" },
        {
            add_files => {
                'source/dist.ini' => $ini
            },
        },
    );
    
    my $tzil = Dist::Zilla::Tester->from_config( @config );
    
    return $tzil;
}
