# XML::Template::Process
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Process;
use base qw(XML::Template::Base);

use strict;
use CGI qw(header);
use IO::String; # XXX
use Mail::Mailer; # XXX
use XML::XPath;


sub _init {
  my $self   = shift;
  my %params = @_;

  print "XML::Template::Process::_init\n" if $self->{_debug};

  # Whether to print a CGI header.
  $self->{_cgi_header} = 1;
  $self->{_cgi_header} = $params{CGIHeader} if defined $params{CGIHeader};
  $self->{_cgi_header_printed} = 0;

  # Whether to print at all.
  $self->{_print} = 1;

  # Create the load Chain of Responsibility list.
  $self->{_load} = [];

  $self->{_nocache} = defined $params{NoCache} ? $params{NoCache} : 0;
  my $cache;
  if (! $self->{_nocache}) {
    $cache = $params{Cache} || XML::Template::Config->cache (%params)
      || return $self->error (XML::Template::Config->error);
    push (@{$self->{_load}}, $cache);
  }

  $self->{_nofilecache} = defined $params{NoFileCache} ? $params{NoFileCache} : 0;
  my $file_cache;
  if (! $self->{_nofilecache}) {
    $file_cache = $params{FileCache} || XML::Template::Config->file_cache (%params)
      || return $self->error (XML::Template::Config->error);
    push (@{$self->{_load}}, $file_cache);
  }

  push (@{$self->{_load}}, @{$params{Load}}) if defined $params{Load};

  # Get parser.
  $self->{_parser} = $params{Parser} || XML::Template::Config->parser (%params)
                     || return $self->error (XML::Template::Config->error);

  $self->{_subroutine} = $params{Subroutine} || XML::Template::Config->subroutine (%params)
    || return $self->error (XML::Template::Config->error);

  # Create the put Chain of Responsibility list.
  $self->{_put} = [];
  push (@{$self->{_put}}, $cache) if ! $self->{_nocache};
  push (@{$self->{_put}}, $file_cache) if ! $self->{_nofilecache};
  push (@{$self->{_put}}, @{$params{Put}}) if defined $params{Put};

  # Get vars.
  $self->{_vars} = $params{Vars} || XML::Template::Config->vars (%params)
                   || return $self->error (XML::Template::Config->error);

  return 1;
}

sub print {
  my $self = shift;
  my $text = join ('', @_);

  my $print = 0;

  my $cfh = select;
  if ($self->{_cgi_header} &&
      ! $self->{_cgi_header_printed}) {
    if ($text !~ /^\s*$/) {
      $self->{_cgi_header_printed} = 1;
      print CGI::header;
      print $text if $self->{_print};
    }
  } else {
    print $text if $self->{_print};
  }

  return 1;
}

sub set_print {
  my $self  = shift;
  my $print = shift;

  my $oprint = $self->{_print};
  $self->{_print} = $print if defined $print;
  return $oprint;
}

sub subroutine {
  my $self = shift;
  my ($subroutine, $var, @params) = @_;

  my $value = $self->{_vars}->get ($var);

  my $subroutine_info = $self->get_subroutine_info ($subroutine);
  my $module = defined $subroutine_info ? $subroutine_info->{module}
                                        : $self->{_subroutine};

  eval "use $module";
  die $@ if $@;
  return ($module->$subroutine ($self, $var, $value, @params));
}

sub get_hostvar {
  my $self = shift;
  my $var  = shift;

  my $value = $self->{_conf}->{hosts}->{host}->{$self->{_hostname}}->{$var};

  return $value;
}

sub process {
  my $self   = shift;
  my ($name, $vars) = @_;

  print ref ($self) . "::process\n" if $self->{_debug};

  # Load XML, calling each method in the load chain of command.
  my $document;
  foreach my $load (@{$self->{_load}}) {
    next if ! $load->{_enabled};

    print "XML::Template::Process::process : Calling " . ref ($load) . "->load.\n" if $self->{_debug};

    $document = eval { $load->load ($name) };
    return $self->error ("ERROR [process]: Could not load document '$name': $@") if $@;
#    return $self->error ($load->error) if $load->error;
    last if defined $document;
  }
#  return $self->error ('Error: No document loaded.') if ! defined $document;

  if (defined $document) {
    # Add passed vars.
    $self->{_vars}->create_context ();
    while (my ($var, $value) = each %$vars) {
      $self->{_vars}->set ($var => $value);
    }

    # If document not yet compiled, compile.
    if (! $document->compiled) {
      # Parse.
      $self->{_parser}->parse ($document)
        || return $self->error ($self->{_parser}->error);
    }

    # Put code, calling each method in the put chain of command.
    foreach my $put (@{$self->{_put}}) {
      print "XML::Template::Process::process : Calling " . ref ($put) . "->put.\n" if $self->{_debug};

      eval { $put->put ($name, $document) };
      return $self->error ("ERROR [process]: Could not put document '$name': $@") if $@;
      return $self->error ($put->error) if $put->error;
    }

    # Run code.
    my $code = eval $document->{_code};
    return $self->error ("ERROR [process - eval]: $@") if $@;
    eval { &$code ($self) };
    if ($@) {
      my $error = ref ($@) ? $@->type . ':' . $@->info : $@;
      return $self->error ("ERROR [process - runtime]: $error");
    }

    # Remove variable context.
    $self->{_vars}->delete_context ();
  }
  
  return 1;
}

sub get_load {
  my $self = shift;
  my @modules = @_;

  # Slurp current load modules into a hash indexed by module name.
  my %modules;
  foreach my $module (@{$self->{_load}}) {
    $modules{ref ($module)} = $module;
  }
  @modules = keys %modules if ! scalar (@modules);

  my %loaded;
  foreach my $module (@modules) {
    $loaded{$module} = defined $modules{$module} ? $modules{$module}->{_enabled}
                                                 : undef;
  }

  return %loaded;
}

sub set_load {
  my $self = shift;
  my %params = @_;

  # Slurp current load modules into a hash indexed by module name.
  my %modules;
  foreach my $module (@{$self->{_load}}) {
    $modules{ref ($module)} = $module;
  }

  my %delete;
  while (my ($module, $loaded) = each %params) {
    my $module_params = {};
    ($loaded, $module_params) = @$loaded if ref ($loaded);

    if (defined $loaded) {
      if (defined $modules{$module}) {
        $modules{$module}->{_enabled} = $loaded;
      } else {
        if ($loaded) {
          XML::Template::Config->load ($module)
            || return $self->error (XML::Template::Config->error ());
          push (@{$self->{_load}}, $module->new (%$module_params));
        }
      }
    } else {
      $delete{$module} = 1;
    }
  }
  if (scalar (keys %delete)) {
    my @new_load;
    foreach my $module (@{$self->{_load}}) {
      push (@new_load, $module) if ! $delete{ref ($module)};
    }
    $self->{_load} = \@new_load;
  }

  return 1;
}

=pod

=head2 generate_where

  my $where = $self->generate_where (\%attribs, $table);

This method returns the where clause of an SQL statement.  The first
parameter is a reference to a hash containing attributes which are the
column names/values to be matched in the where clause.  The second
parameter is the name of the default table to use for columns given in
C<%attribs>.  If column names do not have "." in them, they are prepended
by C<$table>.  If column values have "%" in them, "like" is used for the
comparison test.  Otherwise "=" is used.  For instance,

  my $where = $self->generate_where ({type      => 'newsletter',
                                      'map.num' => 5,
                                      date      => '2002%'},
                                     'items')

will return the following SQL where clause:

  items.type='newsletter' and map.num='5' and items.date like '2002%'

Note that attrib names must be in the format
C<attrib_namespace\01attrib_name>.

=cut

sub generate_where {
  my $self = shift;
  my ($attribs, $table) = @_;

  my $where;
  while (my ($attrib, $value) = each %$attribs) {
    my ($attrib_namespace, $attrib_name) = split (/\01/, $attrib);

    $where .= ' and ' if defined $where;
    $where .= '(';
    my $twhere;
    foreach my $tvalue (split (/\s*,\s*/, $value)) {
      $twhere .= ' or ' if defined $twhere;
      $twhere .= "$table." if $attrib_name !~ /\./;
die if $value =~ /;/;
      $value =~ s/;/\\;/g;
      $value =~ s/'/\\'/g;
      if ($value =~ /%/) {
        $twhere .= "$attrib_name like '$value'";
      } else {
        $twhere .= "$attrib_name='$value'";
      }
    }
    $where .= "$twhere)";
  }

  return $where;
}

sub load {
  my $self = shift;
  my @load = @_;

  my $pos = 0;
  $pos++ if ! $self->{_nocache};
  $pos++ if ! $self->{_nofilecache};
  my @old_load = splice (@{$self->{_load}}, $pos);
  push (@{$self->{_load}}, @load);

  return @old_load;
}


1;
