# XML::Template::Element::Condition
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Condition;
use base qw(XML::Template::Element);

use strict;
use XML::Template::Element;


sub if {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $cond = $self->get_attrib ($attribs, 'cond') || 'undef';

  my $outcode = qq!
if ($cond) {
  $code
}
  !;

  return $outcode;
}

sub elseif {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $cond = $self->get_attrib ($attribs, 'cond') || 'undef';

  my $outcode = qq!
} elsif ($cond) {
  $code
  !;

  return $outcode;
}

sub else {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $outcode = qq!
} else {
  $code
  !;

  return $outcode;
}

sub switch {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $expr = $self->get_attrib ($attribs, 'expr') || 'undef';

  my $outcode = qq!
do {
  \$vars->create_context ();

  my \$__expr = $expr;
  SWITCH: {
$code
  }

  \$vars->delete_context ();
};
  !;

  return $outcode;
}

sub case {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $value = $self->get_attrib ($attribs, 'value');

#  my $cond;
#  if ($value =~ /^\/.*\/$/) {
#    $cond = "\$expr =~ $value";
#  } else {
  my $cond = "\$__expr eq '$value'";
#  }

  my $outcode = qq!
    $cond && do {
      $code
      last SWITCH;
    };
  !;

  return $outcode;
}

sub default {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $outcode = qq!
    $code
  !;

  return $outcode;
}


1;
