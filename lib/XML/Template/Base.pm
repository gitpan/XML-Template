# XML::Template::Base
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@bbl.med.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Base;

use strict;
use XML::Template::Config;
use XML::Simple;
use Data::Dumper;


my $SOURCE = {};
my $CONFIG;

=pod

=head1 NAME

XML::Template::Base - Base class for XML::Template modules.

=head1 SYNOPSIS

  use base qw(XML::Template::Base);
  use XML::Template::Base;

=head1 DESCRIPTION

This module is the XML::Template base class.  It implements common
functionality for many other XML::Template modules, including construction
and error handling.

=head1 CONSTRUCTOR

XML::Template::Base provides a common constructor for XML::Template
modules.  The constructor simply creates a new self and calls an
initialization method.  If the derived class does not have its own
initialization subroutine, XML::Template::Base provides one that simply
returns true.

The following named configuration parameters are supported:

=over 4

=item Debug

Set to true to turn on printing debug information.

=item HTTPHost

The hostname of the requesting server.  The default value is set to the
environment variable C<HTTP_HOST>.  If this is not set (for instance, if
running on the command line), the default is C<localhost>.

=item Config

A reference to a hash containing configuration information.  This is 
typically a representation of the XML configuration file 
C<xml-template.conf>.

=back 4

=cut

sub new {
  # Due to the force of karma, we take rebirth.
  my $proto = shift;

  # Due to ignorance, a self is fabricated.
  my $self  = {};

  # Due to karmic imprints on our consciousness, name and form arise.
  my $class = ref ($proto) || $proto;
  bless ($self, $class);

  # There is contact between the sense organs and consciousness.
  my %params = @_;

  # Contact is the basis for feelings.
  $self->{_debug} = $params{Debug} if defined $params{Debug};
  $self->{_hostname} = $params{HTTPHost}
                       || $ENV{HTTP_HOST}
                       || XML::Template::Config->hostname
    || return $proto->error (XML::Template::Config->error);

  if (! defined $CONFIG) {
    $CONFIG = $params{Config}
                     || XML::Template::Config->config ()
      || return $self->error (XML::Template::Config->error);
  }
  $self->{_conf} = $CONFIG;
  $self->{_source} = $SOURCE;
  $self->{_errid} = $self->errid;

  # We become attached to what feels good; attachment and craving lead 
  # to becoming and birth.
  return $self->_init (%params) ? $self : $proto->error ($self->error);

  # Eventually we grow old and die.
}

=pod

=head1 PRIVATE METHODS

=head2 _init

C<XML::Template::Base> provides an initialization function that simply 
returns 1. This is required for modules that use C<XML::Template::Base> as 
a base class, but do not require an initialization function.

=cut

sub _init {
  my $self = shift;

  return 1;
}

=pod

=head2 _copy

  my $namespace_info = $self->_copy ($orig_namespace_info);

This method makes a copy of whatever is passed to it (scalar, array, or
hash), interpolating any config variables with values from the appropriate
host entry of the config file.  For instance, if the host is C<syrme.net>, 
and the host entry for C<syrme.net> in the config file is:

  <host name="syrme.net">
    <sourcename>syrme</sourcename>
  </host>

and if the variable C<$orig_namespace_info> is a reference to a hash
representing the following section of the config file,

  <namespace name="http://syrme.net/xml-template/block/v1">
    <sourcename>${sourcename}</sourcename>
  </namespace>

that is,

$orig_namespace_info = {
  'name'	=> 'http://syrme.net/xml-template/user/v1',
  'sourcename'	=> '${sourcename}'
};

C<_copy> will replace C<${sourcename}> with the value from the 
variable named sourcename from the host entry, that is, syrme.  So, 
c<_copy> will return a reference to the hash:

$namespace_info = {
  'name'	=> 'http://syrme.net/xml-template/user/v1',
  'sourcename'	=> 'syrme'
};

=cut

sub _copy {
  my $self = shift;
  my $data = shift;

  if (! ref $data) {
    $data =~ s/\${([^}]+)}/$self->{_conf}->{$1}/g;
    return $data;
  } elsif (ref $data eq 'ARRAY') {
    return [map $self->_copy ($_), @$data];
  } elsif (ref $data eq 'HASH') {
    return +{map { $_ => $self->_copy ($data->{$_}) } keys %$data};
  }
}

sub get_ancestors {
  my $self = shift;
  my @packages = @_;

  my @ancestors;

  if (! @packages) {
    my $package = ref ($self);
    push (@ancestors, $package);
    @packages = eval "\@${package}::ISA";
  }

  push (@ancestors, @packages);
  foreach my $package (@packages) {
    my @tpackages = eval "\@${package}::ISA";
    my @tancestors = $self->get_ancestors (@tpackages)
      if scalar (@tpackages);
    push (@ancestors, @tancestors);
  }

  return wantarray ? return @ancestors : join (',', @ancestors);
}

sub errid {
  my $self = shift;

  my $errid;

  my @ancestors = $self->get_ancestors ();
  foreach my $ancestor (@ancestors) {
    $ancestor =~ /([^:]+)$/;
    $errid .= '/' if defined $errid;
    $errid .= $1;
  }

  return $errid;
}

=pod

=head1 PUBLIC METHODS

=head2 error

  return $self->error ($errstr);
  print $self->error;

XML::Template::Base provides the method C<error> to do simple error
handling.  If an argument is given (the error), it is stored, otherwise,
the stored error is returned.

C<error> may be called as a package method (e.g.,
C<XML::Template::Module-E<gt>error ($error);> or as an object method
(e.g., C<$xmlt-E<gt>error ($error);>.  If it is called as a package
method, the error is stored as a package variable.  If it is called as an
object method, the error is stored as a private variable.

=cut

sub error {
  my $self  = shift;
  my $error = shift;

  # If an error given, set it in the object or package.
  # Otherwise, return the error from the object or package.
  if (defined $error) {
    ref ($self) ? $self->{_error} = $error : $self::_error = $error;
    return undef;
  } else {
    return ref ($self) ? $self->{_error} : $self::_error;
  }
}

=pod

=head2 get_source_info

  my $source_info = $self->get_source_info ($sourcename);

This method returns a hash containing name/value pairs for the config 
variables from the source entry, C<$sourcename> in the config file.

=cut

sub get_source_info {
  my $self       = shift;
  my $sourcename = shift;

  my $orig_source_info = $self->{_conf}->{sources}->{$sourcename};
  my $source_info = $self->_copy ($orig_source_info);

  return $source_info;
}

=pod

=head2 get_subroutine_info

  my $subroutine_info = $self->get_subroutine_info ($subroutine);

This method returns a hash containing name/value pairs for the config 
variables from the subroutine entry, C<$subroutine>, in the config file.

=cut

sub get_subroutine_info {
  my $self       = shift;
  my $subroutine = shift;

  my $orig_subroutine_info = $self->{_conf}->{subroutines}->{$subroutine};
  my $subroutine_info = $self->_copy ($orig_subroutine_info);

  return $subroutine_info;
}

=pod

=head2 get_namespace_info

  my $namespace_info = $self->get_namespace_info ($namespace);

This method returns a hash containing name/value pairs for the config 
variables from the namespace entry, C<$namespace>, in the config file.

=cut

sub get_namespace_info {
  my $self      = shift;
  my $namespace = shift;

  my $namespace_info;
  if (defined $namespace) {
    my $orig_namespace_info = $self->{_conf}->{namespaces}->{$namespace};
    $namespace_info = $self->_copy ($orig_namespace_info);
  }

  return $namespace_info;
}

=pod

=head2 get_element_info

  my $element_info = $self->get_element_info ($namespace, $type);

This method returns a hash containing name/value pairs for the config 
variables from the element entry, C<$type>, in the namespace entry, 
C<$namespace>, in the config file.

=cut

sub get_element_info {
  my $self = shift;
  my ($namespace, $type) = @_;

  my $element_info;
  if (defined $namespace && defined $type) {
    my $orig_element_info = $self->{_conf}->{namespaces}->{$namespace}->{element}->{$type};
    $element_info = $self->_copy ($orig_element_info);
  }

  return $element_info;
}

=pod

=head2 get_source

  my $source = $self->get_source ($sourcename);

This method returns the data source, C<$sourcename>, from the config file.

Data source references are stored in a private hash.  If a requested data
source has already been loaded, the stored reference to it is returned.

=cut

sub get_source {
  my $self       = shift;
  my $sourcename = shift;

  my $source;
  if (defined $sourcename) {
    # If source already requested, return stored reference.
    if (defined $self->{_source}->{$sourcename}) {
      $source = $self->{_source}->{$sourcename};

    # Create and return a reference to a source object.
    } else {
      my $source_info = $self->get_source_info ($sourcename);
      if (defined $source_info) {
        # Load the source module.
        my $source_module = $source_info->{module};
        XML::Template::Config->load ($source_module)
          || return $self->error (XML::Template::Config->error);

        # Get password.
        my $pwdfile = $source_info->{pwdfile};
        open (PWDFILE, $pwdfile)
          || return $self->error ("Could not open password file '$pwdfile' for data source '$sourcename': $!");
        my $pwd = <PWDFILE>;
        chomp $pwd;
        close PWDFILE;

        # Create a new data source object.
        $source_info->{password} = $pwd;
        $source = $source_module->new ($source_info)
          || return $self->error ($source_module->error ());

        # Cache the data source object.
        $self->{_source}->{$sourcename} = $source;

      } else {
        return $self->error ("Source '$sourcename' not defined.");
      }
    }
  }

  return $source;
}


1;


__END__

=pod

=head1 AUTHOR

Jonathan Waxman
jowaxman@bbl.med.upenn.edu

=head1 COPYRIGHT

Copyright (c) 2002 Jonathan A. Waxman
All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
