# XML::Template::Element::Email
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::Email;
use base qw(XML::Template::Element);

use strict;
use XML::Template::Element;
use Mail::Mailer;


sub send {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $from_addr = $self->get_attrib ($attribs, 'from_addr') || 'undef';
  my $to_addr   = $self->get_attrib ($attribs, 'to_addr') || 'undef';
  my $subject   = $self->get_attrib ($attribs, 'subject') || 'undef';

  my $outcode = qq!
do {
  \$vars->create_context ();

  my \$mailer = Mail::Mailer->new ('sendmail');
  if (\! \$mailer->open ({From  => $from_addr,
                        To      => $to_addr,
                        Subject => $subject})) {
    print "<h3>Sending Email Failed.</h3>";
  } else {
    select \$mailer;
    $code
    select STDOUT;
    \$mailer->close ();
    print "Email Successfully Sent.";
  }

  \$vars->delete_context ();
};
  !;

  return $outcode;
}


1;
