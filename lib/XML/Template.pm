# XML::Template
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@bbl.med.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# ------------------------------------------------------------------------
#
# Much of the initial design philosophy (and design) was taken from the
# masterfully written Template Toolkit by Andy Wardley which I use 
# extensively myself.


package XML::Template;
use base qw(XML::Template::Base);

use strict;
use vars qw($VERSION);
use CGI;
use XML::Template::Config;


$VERSION	= '3.00';


=pod

=head1 NAME

XML::Template - Front end module to XML::Template.

=head1 SYNOPSIS

  use XML::Template;

  my $xml_template = XML::Template->new ($config)
    || die XML::Template->error;
  $xml_template->process ('filename.xhtml', %vars)
    || die $xml_template->error;

=head1 DESCRIPTION

This module provides a front-end interface to XML::Template.

=head1 CONSTRUCTOR

A constructor method C<new> is provided by L<XML::Template::Base>.  A list
of named configuration parameters may be passed to the constructor.  The
constructor returns a reference to a new XML::Template object or undef if
an error occurrs.  If undef is returned, use the method C<error> to
retrieve the error.  For instance:

  my $xml_template = XML::Template->new (%config)
    || die XML::Template->error;

The following named configuration parameters are supported by this 
module:

=over 4

=item Process

Reference to a processor object.  The default process object is
XML::Template::Process.

=back

See L<XML::Template::Base> for general options.

=head1 PRIVATE METHODS

=head2 _init

This method is the internal initialization function called from
L<XML::Template::Base> when a new object is created.

=cut

sub _init {
  my $self   = shift;
  my %params = @_;

  print "XML::Template::_init\n" if $self->{_debug};

  # Get processor object.
  $self->{_process} = $params{Process}
                      || XML::Template::Config->process (%params)
    || return $self->error (XML::Template::Config->error);

  return 1;
}

=pod

=head1 PUBLIC METHODS

=head2 process

  $xml_template->process ($filename, %vars)
    || die $xml_template->error;

This method is used to process an XML file.  The first parameter is the
name of a piece of XML.  The source of the XML depends on the present
process loaders.  (See C<get_load> and C<set_load> in
L<XML::Template::Process>.)  The second parameter is a reference to a hash
containing name/value pairs of variables to add to the global variable
context.

=cut

sub process {
  my $self          = shift;
  my ($name, $vars) = @_;

  print ref ($self) . "::process\n" if $self->{_debug};

  # Put CGI variables in a global hash named Form.
  my $cgi = CGI->new ();
  foreach my $param ($cgi->param) {
    my @values = $cgi->param ($param);
    $vars->{"Form.$param"} = scalar (@values) == 1 ? $values[0] : \@values;
  }

  # Load configuration file.
use Data::Dumper;
#print Dumper ($self->{_conf}) . "\n";
  $self->{_process}->process (XML::Template::Config->configfile)
    || return $self->error ($self->{_process}->error);
#print Dumper ($self->{_process}->{_conf}) . "\n";

  my $basedir = $self->{_conf}->{basedir};
  $self->{_process}->process ("$basedir/xml-template.conf")
    || return $self->error ($self->{_process}->error);

  # Call the processor.
  $self->{_process}->process ($name, $vars)
    || return $self->error ($self->{_process}->error);

  return 1;
}


1;


__END__

=pod

=head1 ACKNOWLEDGEMENTS

Much of the initial design philosophy (and design) was taken from the 
masterfully written Template Toolkit by Andy Wardley which I use 
extensively myself.

Thanks to Josh Marcus, August Wohlt, and Kristina Clair for many valuable 
discussions.

=head1 AUTHOR

Jonathan A. Waxman
jowaxman@bbl.med.upenn.edu

=head1 COPYRIGHT

Copyright (c) 2002 Jonathan A. Waxman
All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
