# XML::Template::Element::Core
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Core;
use base qw(XML::Template::Element);

use strict;
use XML::Template::Element;


sub element {
  my $self = shift;
  my ($code, $attribs) = @_;

  # Protect variables in code.
  $code =~ s/([\\\$%@])/\\$1/g;

  my $tag = $self->get_attrib ($attribs, 'name') || 'undef';

  my $ns_named_params = $self->generate_named_params ($self->{_namespaces}, 1);
  my $attribs_named_params = $self->generate_named_params ($attribs);

  # Construct a hash containing the namespace information present at the
  # point this subroutine was called during parsing.
  my $xmlinfo_code = $self->generate_xmlinfo_code ($self->{_xmlinfo});

  my $outcode = qq{
do {
  my \%attribs = ($attribs_named_params);

  my \%namespaces = ($ns_named_params);

#no strict;
#\%values;
#use strict;

  my \$tag = $tag;
  \$tag =~ /^([^:]+):(.*)\$/;
  my (\$prefix, \$type) = (\$1, \$2);
  my \$namespace = \$namespaces{\$prefix};
  my \$namespace_info = \$process->get_namespace_info (\$namespace);

  if (defined \$namespace_info) {
    eval "use \$namespace_info->{module}";
    die \$@ if \$@;
    my \$object = \$namespace_info->{module}->new (undef, \$namespace);
    my \$tcode = qq{
$code
    };
    my \%tattribs;
    while (my (\$key, \$val) = each \%attribs) {
      \$tattribs{\$key} = "'\$val'";
    }
    my \$code = \$object->\$type (\$tcode, \\\%tattribs);
    eval \$code;
    die \$\@ if \$\@;
  }
};
  };

#  } else {
#    print "<\$tag";
#    while (my (\$attrib, \$val) = each \%attribs) {
#      print qq\! \$attrib="\$val"\!;
#    }
#    print ">\n";
#    $code
#    print "</\$tag>\n";
#  }
#};
#  !;
#print $outcode;

  return $outcode;
}


1;
