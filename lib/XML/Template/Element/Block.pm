# XML::Template::Element::Block
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Block;
use base qw(XML::Template::Element::DB);

use strict;
use XML::Template::Element::DB;


sub include {
  my $self = shift;
  my ($code, $attribs) = @_;

  # Create attribute param code;
  my $attribs_named_params = $self->generate_named_params ($attribs);

  my $name = $self->get_attrib ($attribs, 'name') || 'undef';

my $outcode = qq!
do {
  use XML::Template::Element::Block::Load;

  \$vars->create_context ();
  my \%attribs = ($attribs_named_params);

  my \$cgi_header = \$process->{_cgi_header};
  \$process->{_cgi_header} = 0;
  my \$value;
  my \$io = IO::String->new (\$value);
  my \$ofh = select \$io;
  $code
  select \$ofh;
  \$vars->set ('_content' => \$value);
  \$process->{_cgi_header} = \$cgi_header;

  my \%vars;
  while (my (\$attrib, \$value) = each \%attribs) {
    my (\$attrib_namespace, \$attrib_name) = split (/\01/, \$attrib);
    \$vars{\$attrib_name} = \$value;
  }

  my \%loaded = \$process->get_load ();
  my \%tloaded;
  while (my (\$module, \$loaded) = each \%loaded) {
    if (\$module =~ /Cache/) {
      \$tloaded{\$module} = \$loaded;
    } else {
      \$tloaded{\$module} = 0;
    }
  }
  \$tloaded{'XML::Template::Element::Block::Load'} = 1;
  \$process->set_load (\%tloaded);
  \$process->process ($name, \\\%vars) || die \$process->error;
  \$process->set_load (\%loaded);

  \$vars->delete_context ();
};
!;

  return $outcode;
}


1;
