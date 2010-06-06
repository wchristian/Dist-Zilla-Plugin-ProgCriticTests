use strict;
use warnings;
package DZT::Sample;

my $a;
unless( $a ) { 1 }

sub return_arrayref_of_values_passed {
  my $invocant = shift;
  return \@_;
}

1;
