# XML::Template::Element::Var
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Var;
use base qw(XML::Template::Element XML::Template::Element::Iterator);


use strict;
use Exporter;
use IO::String;
use Data::Dumper;


sub set {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name = $self->get_attrib ($attribs, 'name') || 'undef';

  my $outcode = qq!
do {
  my \$__name = $name;
  my \$tarray;

  my \$cgi_header = \$process->{_cgi_header};
  \$process->{_cgi_header} = 0;

  my \$value;
  my \$io = IO::String->new (\$value);
  my \$ofh = select \$io;

  $code

  select \$ofh;

  \$process->{_cgi_header} = \$cgi_header;

  \$value =~ s/^\\s*//;
  \$value =~ s/\\s*\$//;

  if (defined \$tarray) {
    \$vars->push (\$__name => \$tarray);
  } else {
    \$vars->set (\$__name => \$value);
  }
};
  !;
#print $outcode;

  return $outcode;
}

sub element {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name = $self->get_attrib ($attribs, 'name') || 'undef';

  my $outcode = qq!
do {
  if (defined \$__name) {
    my \$name = $name;
    \$tarray = defined \$name ? {} : [] if \! defined \$tarray;
    my \$parray = \$tarray;
    my \$tarray;

    my \$value;
    my \$io = IO::String->new (\$value);
    my \$ofh = select \$io;

    $code

    select \$ofh;
    \$value =~ s/^\\s*//;
    \$value =~ s/\\s*\$//;

    \$tarray = \$value if \! ref (\$tarray);
    if (ref (\$parray) eq 'ARRAY') {
      push (\@\$parray, \$tarray);
    } else {
      \$parray->{$name} = \$tarray;
    }
  }
};
  !;

  return $outcode;
}

sub get {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name = $self->get_attrib ($attribs, 'name') || 'undef';

  my $outcode = qq!
print \$vars->get ($name);
  !;

  return $outcode;
}

sub dump {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name = $self->get_attrib ($attribs, 'name') || 'undef';

  my $outcode = qq!
print Dumper (\$vars->get ($name));
  !;

  return $outcode;
}

sub loopinit {
  my $self    = shift;
  my $attribs = shift;

  my $array = $self->get_attrib ($attribs, 'array') || 'undef';
# xxx do replace in get_attrib ?
#  $array =~ s/\@/\\\@/g;
  my $var   = $self->get_attrib ($attribs, 'var')   || 'undef';

  my $outcode = qq!
my \$__var = $var;
my \$array = $array;
if (ref (\$array) eq 'ARRAY') {
  \@__array = \@\$array;
} elsif (ref (\$array) eq 'HASH') {
  \@__array = keys \%\$array;
} else {
  my \@array = split (/(?<\!\\\\),/, \$array);
  foreach my \$str (\@array) {
    if (\$str =~ /^([^\.]+)\\.\\.(.+)\$/) {
      push (\@__array, \$1..\$2);
    } else {
      push (\@__array, \$str);
    }
  }
}
!;

  return $outcode;
}

sub set_loopvar {
  my $self    = shift;
  my $attribs = shift;

  my $outcode = qq!
  \$vars->set (\$__var => \$__value);
  !;

  return $outcode;
}


#
# Subroutines
#

sub push {
  my $class   = shift;
  my $process = shift;
  my ($array, $value) = @_;

  $value = $class->strip ($value);

  CORE::push (@$array, $value);

  return '';
}

sub pop {
  my $class   = shift;
  my $process = shift;
  my $array   = shift;

  CORE::pop (@$array);

  return '';
}

sub unshift {
  my $class   = shift;
  my $process = shift;
  my ($array, $value) = @_;

  $value = $class->strip ($value);

  CORE::unshift (@$array, $value);

  return '';
}

sub shift {
  my $class   = shift;
  my $process = shift;
  my $array   = shift;

  CORE::shift (@$array);

  return '';
}

sub join {
  my $class   = shift;
  my $process = shift;
  my ($array, $sep) = @_;

  $sep = $class->strip ($sep);

  return CORE::join ($sep, @$array);
}

sub split {
  my $class   = shift;
  my $process = shift;
  my ($string, $sep) = @_;

  $sep = $class->strip ($sep);

  my @array = CORE::split ($sep, $string);
  return \@array;
}

sub count {
  my $class   = shift;
  my $process = shift;
  my $array   = shift;

  return scalar (@$array);
}


1;
