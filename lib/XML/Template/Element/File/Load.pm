# XML::Template::Element::File::Load
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::File::Load;
use base qw(XML::Template::Base);

use strict;
use XML::Template::Document;


sub _init {
  my $self   = shift;
  my %params = @_;

  print ref ($self) . "->_init\n" if $self->{_debug};

  $self->{_include_path} = $params{IncludePath} || XML::Template::Config->include_path
    || [''];

  $self->{_enabled} = 1;

  return 1;
}

sub load {
  my $self     = shift;
  my $filename = shift;
  my %params   = @_;

  print ref ($self) . "->load\n" if $self->{_debug};

  my $xml;

  my $include_path = $self->{_include_path};
  # If file name is absolute, no need to search path.
  $include_path = [''] if $filename =~ /^\//;

  my $filespec;
  foreach my $path (@$include_path) {
    # If path is empty, do not prepend anything.
    $filespec = $path eq '' ? $filename : "$path/$filename";

    if (open (FILE, $filespec)) {
      while (my $line = <FILE>) {
        $line =~ s/\$(?!{)/\\\$/g;
        $line =~ s/&(?!amp)/&amp\;/g;
        $xml .= $line;
      }
      close (FILE);
      last;
    }
  }

  return $self->error ("ERROR [load - file]: Could not find '$filename' in include path")
    if ! defined $xml;

  return XML::Template::Document->new (XML       => $xml,
                                       Source    => "file:$filespec");
}


1;
