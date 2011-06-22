use strict;
use warnings;

package Dist::Zilla::Plugin::ProgCriticTests;
# ABSTRACT: Gradually enforce coding standards with Dist::Zilla

use 5.008;

use Moose;
extends 'Dist::Zilla::Plugin::InlineFiles';
with 'Dist::Zilla::Role::TextTemplate';

has step_size    => ( is => 'ro', isa => 'Int', default => 0                     );
has severity     => ( is => 'ro', isa => 'Int', default => 0                     );
has exclude      => ( is => 'ro', isa => 'Str'                                   );
has profile      => ( is => 'ro', isa => 'Str'                                   );
has history_file => ( is => 'ro', isa => 'Str', default => '.perlcritic_history' );


around add_file => sub {
    my ($orig, $self, $file) = @_;

    my $test_content = $self->fill_in_string(
        $file->content,
        {
            root_path       => \$self->zilla->root->absolute,
            step_size       => \$self->step_size,
            severity        => \$self->severity,
            exclude         => \$self->exclude,
            profile         => \$self->profile,
            history_file    => \$self->history_file,
        },
    );

    my $mem_file = Dist::Zilla::File::InMemory->new({
        name    => $file->name,
        content => $test_content,
    });

    return $self->$orig($mem_file);
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 SYNOPSIS

In C<dist.ini>:

    [ProgCriticTests]
    severity = 1                        # optional : default = 5
    step_size = 1                       # optional : default = 0
    exclude = RequireExplicitPackage    # optional : default = undef
    profile = .critic_profile           # optional : default = undef
    history_file = .perlcritic_history  # optional : default = .perlcritic_history

=head1 DESCRIPTION

Please see Test::Perl::Critic::Progressive on what exactly it does. For you it's
only important to know that by using this plugin you can avoid the creep of bad
coding practices into your distribution and slowly remove those that have made
their way in already, without being forced to fix everything at once.

The plugin automatically creates the needed test file and primes it with all
data it needs to know about your dist as well as the options you give.

=head1 OPTIONS

=head2 severity

A numerical indicator of severity (see Perl::Critic). This is optional. The
default is 5.

=head2 step_size

A numerical indicator of the expected violation reduction step size. (see
T::P::C::P).  This is optional. The default is 0.

=head2 exclude

A string containing a list of space-separated patterns, which are forwarded as
the exclude option to Perl::Critic. This is optional. Default is undefined.

=head2 profile

A string indicating the path of a perlcriticrc file (see Perl::Critic). If the
path seems to be relative (Class::Path) it is prepended by the distribution root
directory, otherwise it is used as is. This is optional. Default is undefined.

=head2 history_file

A string indicating the path of a perlcritic history file (see T::P::C::P). If
the path seems to be relative (Class::Path) it is prepended by the distribution
root directory, otherwise it is used as is. This is optional. Default is
'.perlcritic_history'.

=head1 SUPPORT

I'm usually on irc.perl.org in #distzilla. If you don't see my name (Mithaldu)
I'm still there, just not at the computer. However if you mention my name, as
well as your problem, I'll get back to you as soon as i get back. Alternatively,
sending me an email or a message on GitHub works as well.

The repository for this plugin is located here:

L<http://github.com/wchristian/Dist-Zilla-Plugin-ProgCriticTests>

=cut

__DATA__
___[ xt/author/critic_progressive.t ]___
#!perl

use strict;
use warnings;

use lib '../lib';
use lib 'lib';

use Test::More;
use Try::Tiny;
use Path::Class qw(file);

try {
    require Test::Perl::Critic::Progressive;
    Test::Perl::Critic::Progressive->import( ':all' );
}
catch {
    plan skip_all => 'T::P::C::Progressive required for this test' if $@;
};

my $root_path = q<{{ $root_path }}>;
my $step_size = {{ $step_size }};
my $severity = {{ $severity }};
my $exclude = [qw< {{ $exclude }} >];

my $history_file = q<{{ $history_file }}>;
$history_file = qq<$root_path/$history_file> if file($history_file)->is_relative;

my $profile = q<{{ $profile }}>;
$profile = qq<$root_path/$profile> if $profile and file($profile)->is_relative;

run_test( $history_file, $step_size, $exclude, $severity, $profile );

exit;

sub run_test {
    my ( $history_file, $step_size, $exclude, $severity, $profile ) = @_;

    set_history_file( $history_file );
    set_total_step_size( $step_size );

    my %args;
    $args{-severity} = $severity if $severity;
    $args{-profile} = $profile if $profile;
    $args{-exclude} = $exclude if $exclude;

    set_critic_args( %args ) if keys %args;

    progressive_critic_ok();

    return;
}
