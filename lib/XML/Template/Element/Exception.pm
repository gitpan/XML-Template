# XML::Template::Element::Exception
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Exception;
use base qw(XML::Template::Element);

use strict;
use XML::Template::Element;


sub try {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $outcode = qq!
do {
  my \$caught = 0;

  my \$__eval_error;
  my \$first = 1;

  eval {
  $code
  };

  die \$\@ if \$\@ && \! \$caught;
};
  !;
#print $outcode;

  return $outcode;
}

sub throw {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name = $self->get_attrib ($attribs, 'name') || 'undef';
  my $info = $self->get_attrib ($attribs, 'info') || 'undef';

  my $outcode = qq!
die XML::Template::Exception->new ($name, $info);
  !;

  return $outcode;
}

sub catch {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name = $self->get_attrib ($attribs, 'name') || 'undef';

  my $outcode = qq!
};
if (\$first) {
  \$__eval_error = \$\@ if \$\@;
  \$first = 0;
}

if (defined \$__eval_error && \! \$caught) {
  my \$exception = ref (\$__eval_error)
    ? \$__eval_error
    : XML::Template::Exception->new (undef, \$__eval_error);
  \$vars->set ('Exception.info' => \$exception->info);
  if (defined $name) {
    if (\$exception->isa ($name)) {
      \$caught = 1;
$code
    }
  } else {
    \$caught = 1;
$code
  }
  !;

  return $outcode;
}

sub else {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $outcode = qq!
};
if (\! defined \$__eval_error) {
  $code
  !;

  return $outcode;
}


1;
