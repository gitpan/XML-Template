# XML::Template::Element::Config
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Config;
use base qw(XML::Template::Element);

use strict;
use vars qw($AUTOLOAD);


sub config {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $outcode = qq{
do {
  my \$print = \$process->set_print (0);
  my \$cgi_header = \$process->{_cgi_header};
  \$process->{_cgi_header} = 0;
  my \$__config = \$process->{_conf};

  $code

  \$process->set_print (\$print);
  \$process->{_cgi_header} = \$cgi_header;
};
  };

  return $outcode;
}

sub namespace {
  my $self = shift;
  my ($code, $attribs) = @_;

  $AUTOLOAD = 'namespace';
  return $self->AUTOLOAD ($code, $attribs);
}

sub hosts {
  my $self = shift;
  my ($code, $attribs) = @_;

  return $code;
}

sub host {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $hostname = $self->get_attrib ($attribs, 'name');
  return $hostname eq "'$self->{_hostname}'" ? $code : '';
}

sub AUTOLOAD {
  my $self = shift;
  my ($code, $attribs) = @_;

  return if $AUTOLOAD =~ /DESTROY/;

  $AUTOLOAD =~ /([^:]+)$/;
  my $field = $1;

  my $attribs_named_params = $self->generate_named_params ($attribs);
  my $key = XML::Template::Config->xmlconfig->{$field};
  my $nestname = '-';
  if ($key =~ /^[+-]/) {
    $key =~ s/^(.)//;
    $nestname = $1;
  }
  my $val = $self->get_attrib ($attribs, $key) || "'none'";

  my $outcode = qq{
  do {
    my \%attribs = ($attribs_named_params);

    my \$config = \$__config;
    my (\$__config, \$value, \$ofh);

    my \$key = XML::Template::Config->xmlconfig->{$field};
    if (defined \$key) {
      if (\$key eq '') {
        \$config->{$field} = {} if ! defined \$config->{$field};
        \$__config = \$config->{$field};
      } else {
        if ('$nestname' eq '-') {
          \$config->{$val} = {} if ! defined \$config->{$val};
          \$__config = \$config->{$val};
        } else {
          \$config->{$field}->{$val} = {} if ! defined \$config->{$field}->{$val};
          \$__config = \$config->{$field}->{$val};
        }
      }
    } else {
      my \$io = IO::String->new (\$value);
      \$process->set_print (1);
      \$ofh = select \$io;
    }

$code

    if (! defined \$key) {
      select \$ofh;
      \$process->set_print (0);
      \$config->{$field} = \$value;
    }
  };
  };

  return $outcode;
}


1;
