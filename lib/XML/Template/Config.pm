# XML::Template::Config
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@bbl.med.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Config;
use base qw(XML::Template::Base);

use strict;
use vars qw($AUTOLOAD $CONFIGFILE $PROCESS $CACHE $FILE_CACHE $PARSER 
            $VARS 
            $STRING $SUBROUTINE $HOSTNAME $CACHE_SLOTS $CACHE_DIR_SLOTS 
            $CACHE_DIR $ADMIN_DIR
            $CONFIG $XMLCONFIG);
use XML::Template::Base;
use XML::Simple;

use constant PACKAGE	=> 0;
use constant VAR	=> 1;


=pod

=head1 NAME

XML::Template::Config - Configuration module for XML::Template modules.

=head1 SYNOPSIS

  use base qw(XML::Template::Base);
  use XML::Template::Base;

=head1 DESCRIPTION

This module is the XML::Template configuration module.  It contains 
the default values of many configuration variables used by 
many XML::Template modules.

=head1 CONFIGURATION VARIABLES

Configuration variables and their default values are defined at the top of
C<Config.pm>.  The variable name must be all uppercase.  Variable values
are actually array reference tuples.  The first element is the type of
configuration variable (C<VAR> or C<PACKAGE>), and the second element is
the value.  For instance,

  $CONFIGFILE	= [VAR, '/usr/local/xml-template/xml-template.conf'];
  $PROCESS	= [PACKAGE, 'XML::Template::Process'];

A configuration variable value is obtained by a calls to an 
C<XML::Template::Config> subroutine that has the same name as the 
configuration variable but is lowercase.  For instance, to get the values 
of the configuration variables above,

  my $configfile = XML::Template::Config->configfile;
  my $process    = XML::Template::Config->process (%params);

For configuration variables of the type VAR, the value is simply returned.  
If the type is PACKAGE, the module given by the configuration variable
value is required, and an object is instantiated and returned.  
Parameters passed to the C<XML::Template::Config> subroutine are passed to
the module constructor.

=cut

$CONFIGFILE	= [VAR, '/usr/local/xml-template/xml-template.conf'];

$PROCESS	= [PACKAGE, 'XML::Template::Process'];
$CACHE		= [PACKAGE, 'XML::Template::Cache'];
$FILE_CACHE	= [PACKAGE, 'XML::Template::Cache::File'];
$PARSER		= [PACKAGE, 'XML::Template::Parser'];
$VARS           = [PACKAGE, 'XML::Template::Vars'];
$STRING		= [PACKAGE, 'XML::Template::Parser::String'];

$SUBROUTINE	= [VAR, 'XML::Template::Util'];

$HOSTNAME	= [VAR, 'localhost'];

$CACHE_SLOTS	= [VAR, 5];
$CACHE_DIR_SLOTS = [VAR, 10];
$CACHE_DIR      = [VAR, '/tmp/xmlt-cache'];

$ADMIN_DIR	= [VAR, '/usr/local/xml-template/admin'];

$CONFIG		= [VAR, {namespaces  => {
                           'http://syrme.net/xml-template/config/v1' => {
                             module  => 'XML::Template::Element::Config'}}}];
$XMLCONFIG	= [VAR, {config		=> '',
                         hosts		=> '',
                         host		=> '+name',
                         sources	=> '',
                         source		=> '-name',
                         subroutines	=> '',
                         subroutine	=> '-name',
                         namespaces	=> '',
                         namespace	=> '-name',
                         element	=> '+name',
                         nestedin	=> '+name',
                         attrib		=> '+name',
                         relatedto	=> '+name'
                        }];

my $CONFIG;


=pod

=head1 PUBLIC METHODS

=head2 config

  my $config = XML::Template::Config->config ($configfile);

This method returns a hash containing the configuration information in the 
XML config file.  The first call to C<config> loads the config file and 
stores it in the package global variable C<$CONFIG>.  Subsequent calls to 
C<config> will simply return C<$CONFIG>.

An optional parameter may be given naming the config file.  If no 
parameter is given, the config file is named by the configuration variable 
C<$CONFIGFILE>.

See the documentation in C<xml-template.conf> for information on the 
format and contents of the config file.

=cut

sub config2 {
  my $self       = shift;
  my $configfile = shift || $self->configfile;

  my $hostname = $ENV{HTTP_HOST} || $self->hostname
    || return $self->error ("ERROR [config]: No hostname specified.");
  
  # Load configuration.
  if (! defined $CONFIG) {
    my $xml;
    if (! open (CONFIG, $configfile)) {
      return $self->error ("ERROR [config]: Could not open config file '$configfile': $!");
    }
    while (<CONFIG>) {
      next if $_ =~ /^\s*#/;
      $xml .= $_;
    }      
    close (CONFIG);

    $CONFIG = eval { XML::Simple::XMLin ($xml,
                       forcearray => ['host', 'source', 
                                      'subroutine', 'namespace', 
                                      'relatedto', 'element', 'nestedin',
                                      'attrib'],
                       keyattr	=> {host	=> '+name',
                                    source	=> '+name',
                                    subroutine	=> '+name',
                                    namespace	=> '+name',
                                    relatedto	=> '+name',
                                    element	=> '+name',
                                    nestedin	=> '+name',
                                    attrib	=> '+name'}) }
              || return $self->error ("ERROR [config]: Could not read config file '$configfile': $@");

    $CONFIG->{namespaces} = $CONFIG->{namespaces}->{namespace};

    # Insert host specific vars at the top config level, overwriting top level
    # config vars of the same name.
    while (my ($var, $value) = each %{$CONFIG->{hosts}->{host}->{$hostname}}) {
      $CONFIG->{$var} = $value;
    }
#use Data::Dumper;
#print Dumper $CONFIG;
  }

  return $CONFIG;
}

=pod

=head2 load

  XML::Template::Config->load ($module)
    || return $self->error (XML::Template::Config->error);

This method requires the module, C<$module>.

=cut

sub load {
  my $self = shift;
  my $module = shift;

  $module =~ s[::][/]g;
  $module .= '.pm';
  eval {require $module};

  return $@ ? $self->error ($@) : 1;
}

sub AUTOLOAD {
  my $self   = shift;
  my %params = @_;

  if ($AUTOLOAD !~ /DESTROY$/) {
    my $varname = uc ($AUTOLOAD);
    $varname =~ s/.*:://;

no strict 'refs';
    my $var = $$varname;
use strict;
    if (! defined $var) {
      $self->error ("ERROR [config]: No configuration variable for '$varname'.\n");
    } else {
      if ($var->[0] == PACKAGE) {
        if ($self->load ($var->[1])) {
          my $package = $var->[1];
          return $package->new (%params)
                   || $self->error ("ERROR [config]: Could not load module '$package': " . $package->error);
        }
      } else {
       return $var->[1];
      }
    }

    return undef;
  }
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
