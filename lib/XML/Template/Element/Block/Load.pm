# XML::Template::Element::Block::Load
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Block::Load;
use base qw(XML::Template::Base);

use strict;


sub _init {
  my $self   = shift;
  my %params = @_;

  print ref ($self) . "->_init\n" if $self->{_debug};

  $self->{_strip_pattern} = $params{StripPattern} if defined $params{StripPattern};

  $self->{_enabled} = 1;

  return 1;
}

sub load {
  my $self      = shift;
  my $blockname = shift;

  print ref ($self) . "->load\n" if $self->{_debug};

  if (defined $self->{_strip_pattern}) {
    if ($blockname =~ /$self->{_strip_pattern}/) {
      $blockname = $1;
    }
  }

  my $source = $self->{_conf}->{sourcename};
  my $db = $self->get_source ($source);
  if (defined $db) {
    my ($xml) = $db->select (Field	=> 'body',
                             Table	=> 'blocks',
                             Where	=> "blockname='$blockname'");

    return XML::Template::Document->new (XML       => $xml,
                                         Source    => "source:$source:blocks");
  } else {
    return $self->error ("ERROR [load - block]: " . $self->error ())
  }
}


1;
