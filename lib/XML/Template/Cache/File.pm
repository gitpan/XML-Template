# XML::Template::Cache::File
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@bbl.med.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Cache::File;
use base qw(XML::Template::Base);

use strict;
use XML::Template::Document;
use File::Spec;


=pod

=head1 NAME

XML::Template::Cache::File - Document caching to files module.

=head1 SYNOPSIS

  use XML::Template::Cache::File;

  my $cache = XML::Template::Cache::File->new (%config)
    || die XML::Template::Cache::File->error;
  my $document = XML::Template::Document->new ();
  $cache->put ($docname, $document);
  $document = $cache->get ($docname);

=head1 DESCRIPTION

This modules provides XML template caching to files. A given number of
parsed (i.e., code has been generated) XML templates are stored in files
in a speficied directory.  When the directory is full, putting a document
in the file cache causes the oldest (access time) entry to be deleted.  
The configuration variable C<$CACHE_DIR_SLOTS> in C<XML::Template::Config>
sets the default size of the file cache directory.

If file caching is turned on, in the initialization of
C<XML::Template::Process>, a file cache object is placed in the load and
put chain of responsiblity lists after the normal cache object.  Hence,
every load and put operation on a document will result in the file cache
being queried right after the normal cache.

=head1 CONSTRUCTOR

A constructor method C<new> is provided by C<XML::Template::Base>.  A list
of named configuration parameters may be passed to the constructor.  The
constructor returns a reference to a new cache object or undef if an error
occurred.  If undef is returned, you can use the method C<error> to
retrieve the error.  For instance:

  my $cache = XML::Template::Cache::File->new (%config)
    || die XML::Template::Cache->error;

The following named configuration parameters are supported by this module:

=over 4

=item CacheDir

The directory to store parsed XML templated in.  This value will override 
the default value C<$CACHE_DIR> in C<XML::Template::Config>.

=item CacheDirSlots

The number of files to keep in the cache directoryt.  This value will
override the default value C<$CACHE_DIR_SLOTS> in
C<XML::Template::Config>.

=back

=head1 PRIVATE METHODS

=head2 _init

This method is the internal initialization function called from
C<XML::Template::Base> when a new cache object is created.

=cut

sub _init {
  my $self   = shift;
  my %params = @_;

  print "XML::Template::Cache::_init\n" if $self->{_debug};

  $self->{_cache_dir} = $params{CacheDir} || XML::Template::Config->cache_dir
    || return $self->error (XML::Template::Config->error);
  $self->{_cache_dir_slots} = $params{CacheDirSlots} || XML::Template::Config->cache_dir_slots
    || return $self->error (XML::Template::Config->error);

  $self->{_enabled} = 1;

  return 1;
}

=pod

=head1 PUBLIC METHODS

=head2 load

  my $document = $cache->load ($docname);

The C<load> method, returns a document stored in the cache named by 
C<$docname>.  If no document is found, C<undef> is returned.

=cut

sub load {
  my $self = shift;
  my $name = shift;

  my $cachefile = File::Spec->catdir ($self->{_cache_dir}, "$self->{_hostname}/$name");
  my $code;

  print "XML::Template::Cache::File::load : Loading $cachefile\n" if $self->{_debug};

  # Find document in cache directory.
  open (FILE, $cachefile)
    || return undef;
  my $sourceinfo = <FILE>;
  chomp ($sourceinfo);
  my ($source, $sourcename, @sourceinfo) = split (':', $sourceinfo);

  # Remove cached file if original template modified.
  my $cache_mtime = (stat ($cachefile))[9];
  my $unlink = 0;
  if ($source eq 'file') {
    if (-e $sourcename) {
      print "XML::Template::Cache::File::load : Checking $sourcename\n" if $self->{_debug};
      my $mtime = (stat ($sourcename))[9];
      $unlink = $mtime > $cache_mtime;
    }

  } elsif ($source eq 'source') {
    print "XML::Template::Cache::File::load : Checking $sourceinfo\n" if $self->{_debug};
    my $source = $self->get_source ($sourcename);
    $unlink = $source->is_modified ($cache_mtime, @sourceinfo);
  }
  if ($unlink) {
    print "XML::Template::Cache::File::load : $cachefile is old - unlinking\n" if $self->{_debug};
    unlink $cachefile;
    return undef;
  }

  # Slurp in file.
  while (<FILE>) { $code .= $_; }
  close (FILE);

  print "XML::Template::Cache::File::load : Loaded $cachefile\n" if $self->{_debug};

  return XML::Template::Document->new (Code => $code);
}

=pod

=head2 put

  my $document = XML::Template::Document->new (Code => $code);
  $cache->put ($docname, $document);

The C<put> method stores a document in the cache.  If the cache is full,
the oldest accessed document is replaced.  The first parameter is the
name of the document.  The second parameter is the document to store.

=cut

sub put {
  my $self     = shift;
  my $name     = shift;
  my $document = shift;

  my $file = "$self->{_cache_dir}/$self->{_hostname}/$name";

  # File exists - update access and modification time.
  if (-e $file) {
#    utime (time, time, $file);

  # File does not exist - create.
  } else {
    require File::Basename;
    require File::Path;

    my ($filename, $filepath) = File::Basename::fileparse ($file);
    File::Path::mkpath ($filepath);

    open (FILE, "> $file")
      || return $self->error ("ERROR [Cache - File]: Could not open $file: $!");
    print FILE $document->source . "\n";
    print FILE $document->code;
    close (FILE);
  }
      
  return 1;
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
