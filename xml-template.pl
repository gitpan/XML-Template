#!/usr/bin/perl5.8.0


use XML::Template;
use XML::Template::Config;
use XML::Template::Element::File::Load;
use XML::Template::Element::Block::Load;


my %vars;

my $path = $ENV{PATH_INFO} || 'index.xhtml';
$path =~ s[^/][];

my $xmlt = XML::Template->new (
             Load => [
               XML::Template::Element::File::Load->new (
                 IncludePath	=> [XML::Template::Config->admin_dir]),
               XML::Template::Element::Block::Load->new (
                 StripPattern	=> '\/?([^\/]+)\..*$')
             ])
  || die XML::Template->error . "\n";
$xmlt->process ($path, \%vars)
  || die $xmlt->error . "\n";
