# XML::Template::Element::Test
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Test;

# The base class for any element module is typically XML::Template::Element.
# If the element is a database element, the base class will typically be 
# XML::Template::Element::DB.
# If the element needs to use iteration, add to the list of base classes 
# XML::Template::Element::Iterator.
use base qw(XML::Template::Element);

use strict;
use XML::Template::Element;


sub test {
  my $self = shift;

  # If 'content' for this element is set in the configuration to 
  # 'xml', the first argument will contain this element's  content 
  # translated into Perl code.  If 'content' is set to 'text', the 
  # first argument will contain the unparsed content of this element.
  my $code    = shift;
#  my $text    = shift;

  # The second argument is a reference to a hash containing attribute 
  # name/value pairs.  Attribute names are in the form 
  # "<namespace>\01<name>".  If the attribute is not associated with a 
  # namespace, <namespace> will be empty.
  # If 'parse' for an attribbute is set to 'yes', the attribute value will 
  # be parsed with the standard string parrser or by the parser given by 
  # 'parser' for the attribute.  If 'parse' is set to 'no', the values 
  # will be a string containing the unparsed attribute value.
  my $attribs = shift;

  # The class variable, parser, is a reference to the XML::Template parser 
  # currenly parsing the XML document.
  my $parser    = $self->{_parser};

  # Get the the XML namespace this element is associated with.
  my $namespace = $self->namespace ();

  # The method, generate_named_params, will generate a comma-separated 
  # list of named params for the attribute names and values.
  my $attribs_named_params = $self->generate_named_params ($attribs);

  # Get an attribute.  get_attrib will first look for the attributes 
  # associated with this element's namespace, then for attributes not 
  # associated with any attribute.
  # Note that get_attrib will remove the attribute from the attribute hash 
  # if it finds it.  To prevent this, pass 0 as the last argument.
  my $test = $self->get_attrib ($attribs, 'test');

  # Create the code for this element.
  my $outcode = qq{
# The code for the element should generally be enclosed in a do block to 
# give a context for local variables.
do {
  # Create a new variable context for any XML::Template variables that 
  # get created in this element's code.
  \$vars->create_context ();

  # Create a hash containing attribute name/value pairs.
  # This is necessary for checking attribute value types and may be 
  # necessary for other purposes in the element code.
  my \%attribs = ($attribs_named_params);

  # Check the attribute value types against the types given in the 
  # configuration.
#  \$process->{_parser}->check_attrib_types ('$namespace', 'test', \\\%attribs);

  # If code was generated for the element's content, insert it.
  $code

  # Delete the variable context.
  \$vars->delete_context ();
};
  };

  # Return the element's code.
  return $outcode;
}


1;
