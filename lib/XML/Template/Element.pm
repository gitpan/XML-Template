# XML::Template::Element
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@bbl.med.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element;
use base qw(XML::Template::Base);

use strict;
use XML::Template::Config;


=pod

=head1 NAME

XML::Template::Element - XML::Template plug-in element base class.

=head1 SYNOPSIS

package XML::Template::Element::MyElement;

use base qw(XML::Template::Element);
use XML::Template::Element;

=head1 DESCRIPTION

This module provides base functionality for XML::Template plug-in element
modules.

=head1 CONSTRUCTOR

The first parameter of the constructor is hash containing namespace
prefix/expanded namespace name/value pairs.  The second parameter is the
current namespace.  The remaining named parameters are passed to the
C<XML::Template::Base> constructor.  The constructor returns a reference
to a new element object or undef if an error occurred.  If undef is
returned, you can use the method C<error> to retrieve the error.  For
instance:

  my $element = XML::Template::Element->new ($namespaces, $namespace, %params)
    || die XML::Template::Element->error;

=cut

sub new {
  my $proto      = shift;
  my $namespaces = shift;
  my $namespace  = shift;

  my $class = ref ($proto) || $proto;

  my $self = $class->SUPER::new (@_);

  $self->{_namespaces} = $namespaces;
  $self->{_namespace}  = $namespace;

  return $self;
}

=pod

=head1 PUBLIC METHODS

=head2 namespace

  my $namespace = $self->namespace;

This method returns the current namespace.

=cut

sub namespace {
  my $self = shift;

  return $self->{_namespace};
}

=pod

=head2 generate_named_params

  my $attribs_named_params = $self->generate_named_params (\%attrbs);

This method generates Perl code for a named parameter list.  The first 
parameter is a reference to a hash containing parameter name/value pairs.  
For instance,

  my $attribs_named_params = $self->generate_named_params ({
                               type		=> "'newsletter'",
                               date		=> "'2002%'",
                               'map.num'	=> 3});

would return the following string

  'type' => 'newsletter', 'date' => '2002%', 'map.num' => 3

=cut

sub generate_named_params {
  my $self = shift;
  my ($hash, $quotes) = @_;

  my $named_params;
  while (my ($key, $val) = each %$hash) {
    $named_params .= ', ' if defined $named_params;
    $named_params .= "'$key' => ";
    if ($quotes) {
      $named_params .= "'$val'";
    } else {
      $named_params .= $val;
    }
  }

  return $named_params;
}

=pod

=head2 generate_xmlinfo_code

  my $xmlinfo_code = $self->generate_xmlinfo_code ($self->{_xmlinfo});

This method generates Perl code that creates the data structure that store
current XML information (currently declared namespaces.  This is necessary
for passing current XML information from the parse-time to run-time.  For
instance, sometimes it is necessary to make the XML information current
when an element module is called available when the code the element
module generates is later evaluated.

=cut

sub generate_xmlinfo_code {
  my $self    = shift;
  my $xmlinfo = shift;

  my $xmlinfo_code = "my \@xmlinfo;\n";
  my $i = 0;  
  foreach my $el (@$xmlinfo) {
    $xmlinfo_code .= "  \$xmlinfo[$i]->{base}   = '$el->{base}';\n";
    $xmlinfo_code .= "  \$xmlinfo[$i]->{prefix} = '$el->{prefix}';\n";
    $xmlinfo_code .= "  \$xmlinfo[$i]->{nsname} = '$el->{nsname}';\n";
    while (my ($key, $val) = each %{$el->{loaded_nsnames}}) {
      $xmlinfo_code .= "  \$xmlinfo[$i]->{loaded_nsnames}->{$key} = '$val';\n";
    }
    $i++;
  }

  return $xmlinfo_code;
}

=pod

=head2 get_attrib

  my $field = $self->get_attrib ($attribs, ['field', 'fields']) || 'undef';
  my $name = $self->get_attrib ($attribs, 'name'], 0) || '"default"';

This method returns an attribute value.  The first parameter is a
reference to a hash containing attribute/value pairs.  The second
parameter is a scalar or a reference to an array of attribute names to
look for.  The value of the first attribute name found is returned.

Unless the optional third parameter is true, the attribute is deleted from 
the attribute hash.

=cut

sub get_attrib {
  my $self = shift;
  my ($attribs, $attribnames, $delete) = @_;

  $delete = 1 if ! defined $delete;
  my @attribnames = ref ($attribnames) ? @$attribnames : ($attribnames);

  my $value;

  # Look up "<namespace>\01<attribname>" in attrib hash.
  foreach (@attribnames) {
    my $attrib = "$self->{_namespace}\01$_";
    if (exists $attribs->{$attrib}) {
      $value = $attribs->{$attrib};
      delete $attribs->{$attrib} if $delete;
    }
  }

  # Look up "\01<attribname>" in attrib hash.
  if (! defined $value) {
    foreach (@attribnames) {
      my $attrib = "\01$_";
      if (exists $attribs->{$attrib}) {
        $value = $attribs->{$attrib};
        delete $attribs->{$attrib} if $delete;
        return $value;
      }
    }
  }

  return $value;
}

sub strip {
  my $self  = shift;
  my $value = shift;

  $value =~ s/^['"]//;
  $value =~ s/['"]$//;

  return $value;
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

