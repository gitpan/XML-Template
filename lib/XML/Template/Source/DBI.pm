package XML::Template::Source::DBI;
use base 'XML::Template::Base';


use base 'DBI::Wrap';


sub new {
  my $proto      = shift;
  my $sourceinfo = shift;

  my $class = ref ($proto) || $proto;
  my $source = DBI::Wrap->new (DSN	=> $sourceinfo->{dsn},
                               User	=> $sourceinfo->{user},
                               Password	=> $sourceinfo->{password})
    || return $proto->error ("ERROR [source - DBI]: " . DBI::Wrap->error ());
  bless ($source, $class);

  return $source;
}

sub is_modified {
  my $self = shift;
  my ($cache_mtime, $table) = @_;

  my ($table_status) = $self->show (Action	=> 'table_status',
                                    Table	=> $table,
                                    Format	=> 'unix');
#warn "$table: $table_status->{Update_time} <> $cache_mtime\n";
  return ($table_status->{Update_time} > $cache_mtime) ? 1 : 0;
}


1;
