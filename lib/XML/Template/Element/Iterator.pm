# XML::Template::Element::Iterator
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Iterator;


use strict;
use XML::Template::Element;


sub _foreach {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $module = ref ($self);

  my $loopinit_code    = $self->loopinit ($attribs);
  my $get_first_code   = $self->get_first ($attribs);
  my $set_loopvar_code = $self->set_loopvar ($attribs);
  my $get_next_code    = $self->get_next ($attribs);
  my $loopfinish_code  = $self->loopfinish ($attribs);

  my $outcode = qq!
  my (\@__array, \$__value);
  my \$__index = 0;

  $loopinit_code

  $get_first_code

  while (defined \$__value) {
    $set_loopvar_code
    $code
    $get_next_code
  }
  $loopfinish_code
  !;
#print $outcode;

  return $outcode;
}

sub foreach {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $foreach_code = $self->_foreach ($code, $attribs);

  my $outcode = qq!
do {
  \$vars->create_context ();

  $foreach_code

  \$vars->delete_context ();
};
  !;
#print $outcode;

  return $outcode;
}

sub loopinit {
  my $self = shift;
  my ($vars, $attribs) = @_;

  return '';
}

sub get_first {
  my $self    = shift;
  my $attribs = shift;

  my $outcode = qq!
  \$__value = \$__array[0];
  !;

  return $outcode;
}

sub get_next {
  my $self    = shift;
  my $attribs = shift;

  my $outcode = qq!
  \$__value = \$__array[++\$__index];
  !;

  return $outcode;
}

sub set_loopvar {
  my $self    = shift;

  return '';
}

sub loopfinish {
  my $self = shift;

  return '';
}


1;
