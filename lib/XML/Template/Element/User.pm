# XML::Template::Element::User
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::User;
use base qw(XML::Template::Element::DB);

use strict;
use XML::Template::Element;


sub authenticate {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $logintemplate  = $self->get_attrib ($attribs, 'logintemplate') || 'undef';
  my $logouttemplate = $self->get_attrib ($attribs, 'logouttemplate') || 'undef';
  my $logouturl      = $self->get_attrib ($attribs, 'logouturl') || 'undef';
  my $sourcename     = $self->get_attrib ($attribs, 'sourcename');

  my $namespace = $self->namespace ();
  my $namespace_info = $self->get_namespace_info ($namespace);
  $sourcename = "'$namespace_info->{sourcename}'" if ! defined $sourcename;

  my $outcode = qq{
#ServerKeySrc

do {
  use WWW::Auth;
  use WWW::Auth::DB;

  my \$db = \$process->get_source ($sourcename)
    || die XML::Template::Exception->new ('Auth', \$process->error ());

  # Temporarily turn off CGI headers so any authentication templates 
  # (login, logout) do not display them.
  \$process->{_cgi_header} = 0;
  my \$auth = WWW::Auth->new (CGIHeader	=> 0,
                             Auth	=> WWW::Auth::DB->new (DB => \$db),
                             Domain	=> \$process->{_conf}->{domain},
                             Template	=> \$process,
                             LoginTemplate => $logintemplate,
                             LogoutTemplate => $logouttemplate,
                             LogoutURL	=> $logouturl);
  \$process->{_cgi_header} = 1;
  die XML::Template::Exception->new ('Auth', WWW::Auth->error ())
    if ! defined \$auth;

  \$process->{_cgi_header_printed} = 1;
  my (\$success, \$error) = \$auth->login ();
  \$process->{_cgi_header} = 1;
  die XML::Template::Exception->new ('Auth', \$error) if ! \$success;
};
};

  return $outcode;
}



1;
