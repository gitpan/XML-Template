# XML::Template::Vars
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Vars;
use base qw(XML::Template::Base);

use strict;
use Data::Dumper;


sub _init {
  my $self   = shift;
  my %params = @_;

  print ref ($self) . "->_init\n" if $self->{_debug};

  $self->{_contexts} = [];

  return 1;
}

sub create_context {
  my $self = shift;

  # Push a new context onto the context stack.
  my %context = ();
  unshift (@{$self->{_contexts}}, \%context);

  return (\%context);
}

sub delete_context {
  my $self = shift;

  # Pop the context stack.
  my $context = shift (@{$self->{_contexts}});

  return $context;
};

sub _set {
  my $self = shift;
  my ($context, %vars) = @_;

  # Set the given variables.
  while (my ($var, $value) = each (%vars)) {
    my $hash = $context;
    my $i = 1;
    my @varparts = split ('\.', $var);
    foreach my $varpart (@varparts) {
      if ($i == scalar (@varparts)) {
        $hash->{$varpart} = $value;
      } else {
        if (defined $hash->{$varpart}) {
          $hash = $hash->{$varpart};
        } else {
          $hash = $hash->{$varpart} = {};
        }
      }
      $i++;
    }
  }

  return 1;
}

sub set {
  my $self = shift;
  my %vars = @_;

  # Get the current context, or create one if there are none.
  my $context;
  if ($self->{_contexts}) {
    $context = $self->{_contexts}->[0];
  } else {
    $context = $self->create_context ();
  }

  $self->_set ($context, %vars);

  return 1;
}

sub set_global {
  my $self = shift;
  my %vars = @_;

  my $top = scalar (@{$self->{_contexts}});
  my $context = $self->{_contexts}->[$top - 1];

  $self->_set ($context, %vars);

  return 1;
}

sub _unset {
  my $self = shift;
  my ($hash, @varparts) = @_;

  my $varpart = shift @varparts;
  my $thash = $hash->{$varpart};
  $self->_unset ($thash, @varparts) if ref ($thash) eq 'HASH';
  delete $hash->{$varpart};
}

sub unset {
  my $self = shift;
  my @vars = @_;

  foreach my $var (@vars) {
    foreach my $context (@{$self->{_contexts}}) {
      $self->_unset ($context, split ('\.', $var));
    }
  }

  return ('');
}

sub backslash {
  my $self = shift;
  my ($patt, $text) = @_;

  $text =~ s/(?<!\\)([$patt])/\\$1/g;
  return $text;
}

sub _get {
  my $self = shift;
  my $var  = shift;

warn "\nvar: $var\n";
#  $var =~ s/'([^"]*)'/backdot ($1)/gem;
  my @varparts = split (/(?<!\\)\./, $var);
  @varparts = map { $_ =~ s/\\\./\./g; $_ } @varparts;

  # Look for the variable starting at the top of the context stack.
  my $value;
  foreach my $context (@{$self->{_contexts}}) {
    $value = $context;
    foreach my $tvarpart (@varparts) {
      my $varpart = $tvarpart; # xxx
#warn "varpart: $varpart";
      my ($index, $xpath);
      if ($varpart =~ m[(?<!\\)/]) {
        $varpart =~ s[(?<!\\)/(.*)][];
        $xpath = "/$1";
      }
#      $varpart =~ s/^'//; $varpart =~ s/'$//;
      $varpart =~ s[\\/][/]g;
      if ($varpart =~ /\[\d+\]$/) {
        $varpart =~ s/\[(\d+)\]$//;
        $index = $1;
      }
      if (exists $value->{$varpart}) {
        if (defined $index) {
          $value = $value->{$varpart}->[$index];
        } else {
          $value = $value->{$varpart};
        }
        if (defined $xpath) {
          my $xp = XML::XPath->new (xml => $value);
          my @nodes = $xp->findnodes ($xpath);
          $value = scalar (@nodes) > 1 ? \@nodes : $nodes[0];
        }
      } else {
        undef $value;
        last;
      }
    }
    last if defined $value;
  }

  return ($value);
}

sub get {
  my $self = shift;
  my @vars = @_;

  my @values;

  foreach my $var (@vars) {
    my $value = $self->_get ($var);
    push (@values, $value);
  }

  if (wantarray) {
    return (@values);
  } else {
    # This is necessary to return undef properly.
    if (scalar (@values) == 1) {
      if (ref ($values[0]) eq 'XML::XPath') {
        my ($node) = $values[0]->findnodes ('/');
        return ($node->toString);
      } elsif (ref ($values[0]) eq 'XML::XPath::Node::Element') {
        return ($values[0]->toString);
      } elsif (ref ($values[0]) eq 'XML::XPath::Node::Text') {
        return ($values[0]->toString);
      } elsif (ref ($values[0]) eq 'XML::XPath::Node::Attribute') {
        return ($values[0]->string_value);
      } else {
        return ($values[0]);
      }
    } else {
      return (join (',', @values));
    }
  }
}

sub push {
  my $self = shift;
  my %vars = @_;

  while (my ($var, $push_values) = each (%vars)) {
    my $value = $self->_get ($var);
    if (ref ($value) eq 'ARRAY') {
      CORE::push (@$value, @$push_values);
    } else {
      $self->set ($var => $push_values);
    }
  }

  return '';
}

sub pop {
  my $self = shift;
  my $var  = shift;

  my $value = $self->_get ($var);
  if (ref ($value) eq 'ARRAY') {
    return (CORE::pop (@$value));
  } else {
    return '';
  }
}

sub dump {
  my $self = shift;

  my $i = 0;
  foreach my $context (@{$self->{_contexts}}) {
    print "Context $i:<br>\n";
    while (my ($var, $value) = each (%$context)) {
      print "$var: " . Dumper ($value);
    }
    $i++;
  }
}


1;
