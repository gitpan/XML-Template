# XML::Template::Element::File
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::File;
use base qw(XML::Template::Element XML::Template::Element::Iterator);

use strict;
use XML::Template::Element;


sub include {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name  = $self->get_attrib ($attribs, 'name')  || 'undef';
  my $parse = $self->get_attrib ($attribs, 'parse') || "'yes'";

  # Create attribute param code;
  my $attribs_named_params = $self->generate_named_params ($attribs);

  my $outcode = qq!
do {
  use XML::Template::Element::File::Load;

  \$vars->create_context ();

  my \%attribs = ($attribs_named_params);

  if ($parse =~ /^no\$/i) {
    open (FILE, $name)
      || die "Could not open " . $name . ": \$\!";
    while (<FILE>) {
      print \$_;
    }
    close (FILE);
    
  } else {
#    my \@old_load = \$process->load (XML::Template::Element::File::Load->new ());

    my \%loaded = \$process->get_load ();
    my \%tloaded;
    while (my (\$module, \$loaded) = each \%loaded) {
      if (\$module =~ /Cache/) {
        \$tloaded{\$module} = \$loaded;
      } else {
        \$tloaded{\$module} = 0;
      }
    }
    \$tloaded{'XML::Template::Element::File::Load'} = 1;
    \$process->set_load (\%tloaded);
    \$process->process ($name, \\\%attribs) || die \$process->error;
    \$process->set_load (\%loaded);

#    \$process->load (\@old_load);
  }

  \$vars->delete_context ();
};
!;

  return $outcode;
}

sub loopinit {
  my $self    = shift;
  my $attribs = shift;

  my $src = $self->get_attrib ($attribs, 'src') || 'undef';
  my $var = $self->get_attrib ($attribs, 'var') || 'undef';

  my $outcode = qq!
  my \$__var = $var;
  if (-d $src) {
    opendir (DIR, $src)
      || die XML::Template::Exception->new ('File', \$\!);
    \@__array = readdir (DIR);
    closedir (DIR);
  } else {
    \@__array = ($src);
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


1;
