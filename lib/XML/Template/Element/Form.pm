# XML::Template::Element::Form
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Form;
use base qw(XML::Template::Element::DB);

use strict;
use XML::Template::Element;


sub select {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name    = $self->get_attrib ($attribs, 'name')    || 'undef';
  my $default = $self->get_attrib ($attribs, 'default') || 'undef';

  my $outcode = qq!
  do {
    \$vars->create_context ();

    print "<select name=\\"" . $name . "\\">\n";

    my \$__default = $default;
    $code

    print "</select>\n";

    \$vars->delete_context ();
  };
  !;

  return $outcode;
}

sub option {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $value = $self->get_attrib ($attribs, 'value') || 'undef';

  return '' if $value eq 'undef';

  my $outcode = qq!
  do {
    \$vars->create_context ();

    print "<option value=\\"" . $value . "\\"";
    print " selected" if $value eq \$__default;
    print ">";
    $code
    print "</option>\n";

    \$vars->delete_context ();
  };
  !;

  return $outcode;
}

sub upload {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $name = $self->get_attrib ($attribs, 'name') || 'undef';
  my $dest = $self->get_attrib ($attribs, 'dest') || 'undef';

  my $outcode = qq!
do {
  \$vars->create_context ();

  my \$cgi = CGI->new ();
  my \$fh = \$cgi->upload ($name);
  open (OUTFILE, ">" . $dest)
    || die XML::Template::Exception->new ('Upload', \$\!);
  my \$buffer = '';
  while (my \$bytesread = read (\$fh, \$buffer, 1024)) {
    print OUTFILE \$buffer;
  }
  close OUTFILE;

  \$vars->delete_context ();
};
  !;

  return $outcode;
}


1;
