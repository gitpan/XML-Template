#!/usr/bin/perl


use strict;
use ExtUtils::MakeMaker;

require 5.8.0;


my $INSTALL_XMLT	= '/usr/local/xml-template';
my $INSTALL_XMLT_CONFIG	= '';
my $INSTALL_XMLT_ADMIN	= 'admin';
my $XMLT_ADMIN_FILES	= 'admin_header.xhtml admin.xhtml login.xhtml \
                          admin_login.xhtml  admin_xmlt.xhtml logout.xhtml';

my %opts = (
  NAME          => 'XML-Template',
  VERSION_FROM  => 'lib/XML/Template.pm',
  PREREQ_PM	=> {
    'CGI'		=> 2.81,
    'Data::Dumper'	=> 2.12,
    'XML::Simple'	=> 1.08,
    'XML::Parser'	=> 2.31,
    'IO::String'	=> 1.01,
    'Mail::Mailer'	=> 1.47,
    'Parse::RecDescent'	=> 1.80,
    'DBI::Wrap'		=> 1.00
  }
);
if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
  $opts{AUTHOR}   = 'Jonathan Waxman <jowaxman@bbl.med.upenn.edu>';
  $opts{ABSTRACT} = 'a highly configurable X(HT)ML document processing framework';
}

sub MY::install {
  package MY;
  my $inherited = shift->SUPER::install (@_);

  $inherited =~ s/^(install :: .*)$/$1 inst_xmlt/gm;

  $inherited;
}

sub MY::postamble {
  qq{
INSTALL_XMLT		= $INSTALL_XMLT
INSTALL_XMLT_CONFIG	= \$(INSTALL_XMLT)
INSTALL_XMLT_ADMIN	= \$(INSTALL_XMLT)/$INSTALL_XMLT_ADMIN
XMLT_ADMIN_FILES	= $XMLT_ADMIN_FILES
  } . q{
inst_xmlt: $(INSTALL_XMLT_CONFIG)/xml-template.conf $(INSTALL_XMLT_ADMIN)

$(INSTALL_XMLT_CONFIG)/xml-template.conf: xml-template.conf
	mkdir -p $(INSTALL_XMLT_CONFIG)
	$(CP) xml-template.conf $(INSTALL_XMLT_CONFIG)/xml-template.conf

$(INSTALL_XMLT_ADMIN):
	mkdir -p $(INSTALL_XMLT_ADMIN)
	$(CP) admin/* $(INSTALL_XMLT_ADMIN)
  };
}

WriteMakefile (%opts);
