# XML::Template::Util
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Util;

use strict;
use Exporter;

use vars qw(@ISA @EXPORT_OK);


@ISA       = qw(Exporter);
@EXPORT_OK = qw(defined set_date_vars);


sub defined {
  my $class   = shift;
  my $process = shift;
  my ($var, $value) = @_;

  return CORE::defined $value;
}

sub set_date_vars {
  my $class   = shift;
  my $process = shift;
  my $value   = shift;
  my $prefix  = shift;

  my $vars = $process->{_vars};

  $value =~ /^(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)$/;
  $vars->set ($prefix . "_year", $1);
  $vars->set ($prefix . "_month", $2);
  $vars->set ($prefix . "_day", $3);
  $vars->set ($prefix . "_hour", $4);
  $vars->set ($prefix . "_minute", $5);
  $vars->set ($prefix . "_second", $6);

  return '';
}

sub replace {
  my $class   = shift;
  my $process = shift;
  my ($var, $value, $pattern, $replace) = @_;

  $value =~ s/$pattern/$replace/;
  $process->{_vars}->set ($var, $value);

  return '';
}


1;
