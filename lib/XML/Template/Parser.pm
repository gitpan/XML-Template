# XML::Template::Parser
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Parser;
use base qw(XML::Template::Base);

use strict;
use XML::Template::Exception;
use XML::Parser;


=pod

=head1 NAME

XML::Template::Parser - Document parsing module for XML::Template.

=head1 SYNOPSIS

  use XML::Template::Parse;

  my $parser = XML::Template::Parse->new ();
  $parser->parse ($document);

=head1 DESCRIPTION

This module provides XML document parsing for XML::Template.  Whenever a
plug-in element type is encountered, a subroutine in the associated
Element module is called.  However, only plug-in elements whose namespaces
have been defined in the document will be processed.  Much of the default
element and attribute processing behavior can be modified in the
XML::Template config file.  See C<xml-template.conf> for more information.

=head1 CONSTRUCTOR

A constructor method C<new> is provided by C<XML::Template::Base>.  A list
of named configuration parameters may be passed to the constructor.  The
constructor returns a reference to a new parser object or undef if an
error occurred.  If undef is returned, you can use the method C<error> to
retrieve the error.  For instance:

  my $parser = XML::Template::Parser->new (%config)
    || die XML::Template::Parser->error;

The following named configuration parameters are supported by this module:

=over 4

=item String

A reference to custom attribute string parser.

=back

=head1 PRIVATE METHODS

=head2 _init

This method is the internal initialization function called from
C<XML::Template::Base> when a new cache object is created.

=cut

sub _init {
  my $self   = shift;
  my %params = @_;

  print ref ($self) . "->_init\n" if $self->{_debug};

  # Store a string parser object.
  $self->{_string} = $params{String} || XML::Template::Config->string (%params)
    || return $self->error (XML::Template::Config->error);

  return 1;
}

=pod

=head1 PUBLIC METHODS

=head2 parse

  $parser->parse ($document)
    || die $parser->error;

This method initiates XML document parsing.  It takes a single parameter, 
a reference to an XML::Template::Document object, which contains the 
actual XML text.

C<parse> returns 1 if the parse was successful, other wise it returns 
C<undef>.

=cut

sub parse {
  my $self     = shift;
  my $document = shift;

  print ref ($self) . "->parse\n" if $self->{_debug};

  # Get XML document.
  my $xml = $document->xml;

  # Replace variable tags with 'core:element' tag.
  $xml =~ s/<\/([^\s]*\${[^}]*}[^\s>]*>)/<\/core:element>/g;
  $xml =~ s/<([^\s>]*\${[^}]*}[^\s>]*)/<core:element core:name="$1"/g;

  # Parse it.
  my $parser = XML::Parser->new (
                 ErrorContext	=> 2,
                 Namespaces	=> 1,
                 Handlers	=> {Start	=> \&StartTag,
                                    End		=> \&EndTag,
                                    Char	=> \&Char});
  $parser->{_self}     = $self;
  $parser->{_content}  = 'xml';
  $parser->{_objects}  = {};
  $parser->{_attribs}  = [];
  $parser->{_code}     = [''];
  $parser->{_text}     = '';
  my $code = eval { $parser->parse ("<__xml>$xml</__xml>") };
  return $self->error ("ERROR [parser]: $@") if $@;

  # Assemble and store the final Perl code.
  my $code = $parser->{_code}->[0];
  $code = qq!
sub {
  my \$process = shift;

  my \$vars = \$process->{_vars};
  \$vars->set ('Config' => \$process->{_conf});

  $code
}
  !;
  $document->code ($code);

  return 1;
}

sub check_attrib_types {
  my $self    = shift;
  my ($namespace, $type, $attribs) = @_;

  my $element_info = $self->get_tag ($namespace, $type);
  if (defined $element_info &&
      defined $element_info->{attrib}) {
    while (my ($attrib, $value) = each %$attribs) {
      my ($attrib_namespace, $attrib_name) = split (/\01/, $attrib);
      if (defined $element_info->{attrib}->{$attrib_name} &&
          defined $element_info->{attrib}->{$attrib_name}->{type}) {
        if ($value !~ /$element_info->{attrib}->{$attrib_name}->{type}/) {
          return $self->error ("Attribute '$attrib' of element '$type' is not of specified type.");
        }
      }
    }
  }
}

sub StartTag {
  my $parser = shift;
  my $type   = shift;

  # Handle any text accumulated by the Char handler.
  Text ($parser);

  # The element type __xml is used to wrap pieces of XML that may 
  # not have a root element.  Skip it.
  return if $type eq '__xml';

  # Get the processor object.
  my $self = $parser->{_self};

  # Not skipping - Process.
  if (! defined $parser->{_skip_until}) {
    # Get namespace info for the current element type.
    my $namespace = $parser->namespace ($type);
    my $namespace_info = $self->get_namespace_info ($namespace);

    # If namespace info is defined, prepare to call the associated 
    # subroutine when the end tag arrives.
    if (defined $namespace_info) {
      # Set the attrib names to "<namespace>\01<attribname>" so they can be
      # uniquely identified in a hash.
      for (my $i = 0; $i < @_; $i += 2) {
        my $attrib = $_[$i];
        my $namespace = $parser->namespace ($attrib);
        $_[$i] = defined($namespace) ? "$namespace\01$attrib"
                                     : "\01$attrib";
      }
      my %attribs = @_;

      # Load element module.
      XML::Template::Config->load ($namespace_info->{module})
        || die $self->error (XML::Template::Config->error ());

      # Get parent element.
      my $parent_type = $parser->current_element ();

      # Find element object if nested.
      # Do some element and attribute checks.
      my $create_object = 1;
      my $element_info = $self->get_element_info ($namespace, $type);
      if (defined $element_info) {
        # The element is designated as a nested element -- use the parent
        # element object.  If no parent element object, complain.
        if (defined $element_info->{nestedin}) {
          if (defined $element_info->{nestedin}->{$parent_type} &&
              $parser->namespace ($parent_type) eq $namespace) {
            $create_object = 0;
          } else {
            $parser->xpcroak ("Element '$type' not properly nested");
          }
        }

        # Determine content type.
        if (defined $element_info->{content} &&
            $element_info->{content} ne 'xml') {
          $parser->{_skip_until} = $parser->depth ();
        }

        # Check attributes.
        if (defined $element_info->{attrib}) {
          while (my ($attrib, $attrib_info) = each %{$element_info->{attrib}}) {
            if ($attrib_info->{required} eq 'yes' &&
                ! exists $attribs{"$namespace\01$attrib"} &&
                ! exists $attribs{"\01$attrib"}) {
              $parser->xpcroak ("Required attribute '$attrib' not present in tag '$type'");
            }
          }
        }
      }

      # Create and cache element object.
      my $object;
      if ($create_object) {
        my %namespaces;
        foreach my $prefix ($parser->current_ns_prefixes ()) {
          $namespaces{$prefix} = $parser->expand_ns_prefix ($prefix);
        }
        $object = $namespace_info->{module}->new (\%namespaces, $namespace);
        unshift (@{$parser->{_objects}->{$namespace_info->{module}}}, $object);

      # Find object on cache.
      } else {
        $object = $parser->{_objects}->{$namespace_info->{module}}->[0];
      }

      # Generate code for attributes.
      while (my ($attrib, $value) = each %attribs) {
        my ($attrib_namespace, $attrib_name) = split (/\01/, $attrib);

        # Value is empty - Set value to empty quotes.
        if ($value eq '') {
          $attribs{$attrib} = '""';

        # Value exists - parse unless config says not to.
        } else {
          my $string_parser = $self->{_string};
          if (defined $element_info->{attrib} &&
              defined $element_info->{attrib}->{$attrib_name}) {
            if ($element_info->{attrib}->{$attrib_name}->{parse} ne 'no') {
              if (defined $element_info->{attrib}->{$attrib_name}->{parser}) {
                eval "use $element_info->{attrib}->{$attrib_name}->{parser}";
                die $@ if $@;
                $string_parser = $element_info->{attrib}->{$attrib_name}->{parser}->new ();
              }
              $attribs{$attrib} = $string_parser->text ($value);
            } else {
# XXX quote escape
              $attribs{$attrib} = qq{"$attribs{$attrib}"};
            }
          } else {
            $attribs{$attrib} = $string_parser->text ($value);
          }
        }
      }

      # Push attribs and new code block.
      unshift (@{$parser->{_attribs}}, \%attribs);
      unshift (@{$parser->{_code}},    '');

    } else {
      # Create text to parse.
      my $text = "<$type";
      while (@_) {
        $text .= ' ' . shift () . '="' . shift () . '"';
      }
      $text .= '>';

      $text = $self->{_string}->text ($text);
#      $text =~ s/@/\\@/g; 
      $parser->{_code}->[0] .= "\$process->print ($text);\n";
    }

  } else {
    # Create text to parse.
    my $text = "<$type";
    while (@_) {
      $text .= ' ' . shift () . '="' . shift () . '"';
    }
    $text .= '>';

    $parser->{_text} .= $text;
  }
}

sub EndTag {
  my ($parser, $type) = @_;
  my $self = $parser->{_self};
  my $vars = $parser->{_vars};

  # Handle any text accumulated by the Char handler.
  Text ($parser);

  # The element type __xml is used to wrap pieces of XML that may
  # not have a root element.  Skip it.
  return if $type eq '__xml';

# xxx what about something like html:br?
  if ($type ne 'br') {
    my $text;
    if (defined $parser->{_skip_until} &&
        $parser->{_skip_until} eq $parser->depth ()) {
      undef $parser->{_skip_until};
      $text = $parser->{_text};
      $parser->{_text} = '';
    }

    if (! defined $parser->{_skip_until}) {
      # Get namespace info for the current element type.
      my $namespace = $parser->namespace ($type);
      my $namespace_info = $self->get_namespace_info ($namespace);

      # If namespace info is defined, call the element subroutine.
      if (defined $namespace_info) {
        # Get element object.  If element is not nested, pop the object
        # out of the cache.
        my $object;
        my $element_info = $self->get_element_info ($namespace, $type);
        if (defined $element_info &&
            defined $element_info->{nestedin}) {
          $object = $parser->{_objects}->{$namespace_info->{module}}->[0];
        } else {
          $object = shift (@{$parser->{_objects}->{$namespace_info->{module}}});
        }

        # pop attribs and code block.
        my $attribs = shift (@{$parser->{_attribs}});
        my $code    = shift (@{$parser->{_code}});

        # Call the module sub.
        if ($element_info->{content} eq 'empty') {
          $parser->{_code}->[0] .= $object->$type (undef, $attribs);
        } elsif ($element_info->{content} eq 'text') {
          $parser->{_code}->[0] .= $object->$type ($text, $attribs);
        } else {
          $parser->{_code}->[0] .= $object->$type ($code, $attribs);
        }
        die $@ if $@;

        undef ($object);

      } else {
        $parser->{_code }->[0] .= "\$process->print ('</$type>');\n";
      }

    } else {
      $parser->{_text} .= "</$type>";
    }
  }
}

sub Char {
  my $parser = shift;
  $parser->{Text} .= shift;
}

sub Text {
  my $parser = shift;

  my $self = $parser->{_self};

  my $text = $parser->{Text};

  if (! defined $parser->{_skip_until}) {
    $text = $self->{_string}->text ($text);
#    $text =~ s/@/\\@/g; 

    # Force $text into a scalar context so variable returning will work
    # properly.
    if ($text ne '') {
      $parser->{_code}->[0] .= "\$process->print (scalar ($text));\n";
    }

  } else {
    $parser->{_text} .= $text;
  }

  $parser->{Text} = '';
}


1;
