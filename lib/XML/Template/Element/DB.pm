# XML::Template::Element::DB
#
# Copyright (c) 2002 Jonathan A. Waxman <jowaxman@law.upenn.edu>
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.


package XML::Template::Element::DB;
use base qw(XML::Template::Element XML::Template::Element::Iterator);

use strict;
use XML::Template::Element::Iterator;
use IO::String;

use vars qw($AUTOLOAD);


sub select {
  my $self = shift;
  my ($code, $attribs) = @_;

  # Get attribs.
  my $name   = $self->get_attrib ($attribs, 'name')              || 'undef';
  my $fields = $self->get_attrib ($attribs, ['fields', 'field']) || 'undef';

  # Generate named params assignments for the remaining atttribs.
  my $attribs_named_params = $self->generate_named_params ($attribs);

  # Get database info.
  my $namespace = $self->namespace ();
  my $namespace_info = $self->get_namespace_info ($namespace);
  my $dbname = $namespace_info->{sourcename};
  my $keys   = $namespace_info->{key};
  my $table  = $namespace_info->{table};

  my $outcode = qq!
do {
  \$vars->create_context ();

  my \%attribs = ($attribs_named_params);
  \$vars->set (\%attribs);

  my \$tables = '$table';
  my \$where;

  if (defined $name) {
    my \@names = split (/\\s*,\\s*/, $name);
    my \$i = 0;
    foreach my \$key (split (',', '$keys')) {
      \$where .= ' and ' if defined \$where;
      \$where .= "$table.\$key='\$names[\$i]'";
      \$i++;
    }
  }
  my \$twhere = \$process->generate_where (\\\%attribs, '$table');
  if (defined \$where && defined \$twhere) {
    \$where .= " and \$twhere";
  } elsif (defined \$twhere) {
    \$where = \$twhere;
  }

no strict;
  my \$parent_namespace = \$__parent_namespace;
  my \@parent_names     = \@__parent_names;
use strict;

  if (defined \$parent_namespace) {
    my \$parent_namespace_info = \$process->get_namespace_info (\$parent_namespace);
    if (defined \$parent_namespace_info->{relatedto} &&
        defined \$parent_namespace_info->{relatedto}->{'$namespace'}) {
      \$tables .= ",\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}";

      my \$i = 0;
      foreach my \$key (split (',', '$keys')) {
        \$where .= ' and ' if defined \$where;
        \$where .= "$table.\$key=\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}.\$key";
        \$i++;
      }

      \$i = 0;
      foreach my \$key (split (',', \$parent_namespace_info->{key})) {
        \$where .= ' and ' if defined \$where;
        \$where .= "\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}.\$key='\$parent_names[\$i]'";
        \$i++;
      }
    }
  }

  my \$result;
#  if (defined \$where) {
    my \$db = \$process->get_source ('$dbname');
    if (defined \$db) {
      \$result = \$db->select (Table	=> \$tables,
                             Where	=> \$where);
      die XML::Template::Exception->new ('DB', \$db->error ()) if defined \$db->error ();
      if (defined \$result) {
        if (defined $fields) {
          my \$fields = $fields;
          if (\$fields eq '*') {
            \$vars->set (\%\$result);
          } else {
            foreach my \$field (split (/\\s*,\\s*/, \$fields)) {
              \$vars->set (\$field => \$result->{\$field});
            }
          }
        }
      }
    }
#  }

  my \$__parent_namespace = '$namespace';
  my \@__parent_names;
  if (defined $name) {
    \@__parent_names = split (/\\s*,\\s*/, $name);
  } else {
    if (defined \$result) {
      foreach my \$key (split (/\s*,\s*/, '$keys')) {
        push (\@__parent_names, \$result->{\$key});
      }
    }
  }

  $code

  \$vars->delete_context ();
};
  !;
#print "$outcode";

  return $outcode;
}

sub update {
  my $self = shift;
  my ($code, $attribs) = @_;

  # Get attribs.
  my $name   = $self->get_attrib ($attribs, 'name')   || 'undef';
  my $insert = $self->get_attrib ($attribs, 'insert') || 'undef';

  # Generate named params assignments for the remaining atttribs.
  my $attribs_named_params = $self->generate_named_params ($attribs);

  # Get database info.
  my $namespace = $self->namespace ();
  my $namespace_info = $self->get_namespace_info ($namespace);
  my $dbname = $namespace_info->{sourcename};
  my $keys   = $namespace_info->{key};
  my $table  = $namespace_info->{table};

  my$outcode = qq!
do {
  \$vars->create_context ();

  my \%attribs = ($attribs_named_params);
  \$vars->set (\%attribs);

  my \$tables = '$table';
  my (\%values, \$where);

  if (defined $name) {
    my \@names = split (/\\s*,\\s*/, $name);
    my \$i = 0;
    foreach my \$key (split (',', '$keys')) {
      \$where .= ' and ' if defined \$where;
      \$where .= "$table.\$key='\$names[\$i]'";
      \$i++;
    }
  }
  my \$twhere = \$process->generate_where (\\\%attribs, '$table');
  if (defined \$where && defined \$twhere) {
    \$where .= " and \$twhere";
  } elsif (defined \$twhere) {
    \$where = \$twhere;
  }
  my \$select_where = \$where;

no strict;
  my \$parent_namespace = \$__parent_namespace;
  my \@parent_names     = \@__parent_names;
use strict;

  if (defined \$parent_namespace) {
    my \$parent_namespace_info = \$process->get_namespace_info (\$parent_namespace);
    if (defined \$parent_namespace_info->{relatedto} &&
        defined \$parent_namespace_info->{relatedto}->{'$namespace'}) {
      \$tables .= ",\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}";

      my \$i = 0;
      foreach my \$key (split (',', '$keys')) {
        \$select_where .= ' and ' if defined \$where;
        \$select_where .= "$table.\$key=\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}.\$key";
        \$i++;
      }

      \$i = 0;
      foreach my \$key (split (',', \$parent_namespace_info->{key})) {
        \$select_where .= ' and ' if defined \$where;
        \$select_where .= "\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}.\$key='\$parent_names[\$i]'";
        \$i++;
      }
    }
  }

  my (\$__parent_namespace, \@__parent_names);
  if (defined $name) {
    \$__parent_namespace = '$namespace';
    \@__parent_names = split (/\\s*,\\s*/, $name);
  }

  $code

  if (defined $name) {
    my \$db = \$process->get_source ('$dbname');
    if (defined \$db) {
      my \$result = \$db->select (Table	=> \$tables,
                                Where	=> \$select_where);
      die XML::Template::Exception->new ('DB', \$db->error ()) if defined \$db->error ();
      if (defined \$result) {
        \$db->update (Table	=> '$table',
                     Values	=> \\\%values,
                     Where	=> \$where)
          || die XML::Template::Exception->new ('DB', \$db->error ());
      } else {
        my \$insert = $insert;
        if (defined \$insert && \$insert =~ /^yes\$/i) {
          if (defined $name) {
            my \@names = split (/\\s*,\\s*/, $name);
            my \$i = 0;
            foreach my \$key (split (',', '$keys')) {
              \$values{\$key} = \$names[\$i] if \! exists \$values{\$key};
              \$i++;
            }
          }
          \$db->insert (Table	=> '$table',
                       Values	=> \\\%values)
            || die XML::Template::Exception->new ('DB', \$db->error ());

          if (defined \$parent_namespace) {
            my \$parent_namespace_info = \$process->get_namespace_info (\$parent_namespace);
            if (defined \$parent_namespace_info->{relatedto} &&
              defined \$parent_namespace_info->{relatedto}->{'$namespace'}) {
              my \%map_values;
              foreach my \$key (split (',', '$keys')) {
                \$map_values{\$key} = \$values{\$key};
              }

              my \$i = 0;
              foreach my \$key (split (',', \$parent_namespace_info->{key})) {
                \$map_values{\$key} = \$parent_names[\$i];
                \$i++;
              }

              \$db->insert (Table     => \$parent_namespace_info->{relatedto}->{'$namespace'}->{'table'},
                           Values     => \\\%map_values)
                || die XML::Template::Exception->new ('DB', \$db->error ());
            }
          }
        }
      }
    }
  }
};
!;

  return $outcode;
}

sub insert {
  my $self = shift;
  my ($code, $attribs) = @_;

  # Get attribs.
  my $name   = $self->get_attrib ($attribs, 'name')   || 'undef';

  # Get database info.
  my $namespace = $self->namespace ();
  my $namespace_info = $self->get_namespace_info ($namespace);
  my $dbname = $namespace_info->{sourcename};
  my $keys   = $namespace_info->{key};
  my $table  = $namespace_info->{table};

  my $outcode = qq!
do {
  \$vars->create_context ();

  my (\%values, \$where);

  if (defined $name) {
    my \@names = split (/\\s*,\\s*/, $name);
    my \$i = 0;
    foreach my \$key (split (',', '$keys')) {
      \$values{\$key} = \$names[\$i];
      \$where .= ' and ' if defined \$where;
      \$where .= "$table.\$key='\$names[\$i]'";
      \$i++;
    }
  }

  my (\$parent_namespace, \@parent_names);
no strict;
  \$parent_namespace = \$__parent_namespace;
  \@parent_names  = \@__parent_names;
use strict;

  my (\$__parent_namespace, \@__parent_names);
  if (defined $name) {
    \$__parent_namespace = '$namespace';
    \@__parent_names = split (/\\s*,\\s*/, $name);
  }

  $code

  my \$db = \$process->get_source ('$dbname');
  if (defined \$db) {
    if (\! \$db->insert (Table	=> '$table',
                       Values	=> \\\%values)) {
      die XML::Template::Exception->new ('DB', \$db->error ())
        if \! defined \$parent_namespace;
    }

    if (defined \$parent_namespace) {
      my \$parent_namespace_info = \$process->get_namespace_info (\$parent_namespace);
      if (defined \$parent_namespace_info->{relatedto} &&
          defined \$parent_namespace_info->{relatedto}->{'$namespace'}) {
        my \%map_values;
        foreach my \$key (split (',', '$keys')) {
          \$map_values{\$key} = \$values{\$key};
        }

        my \$i = 0;
        foreach my \$key (split (',', \$parent_namespace_info->{key})) {
          \$map_values{\$key} = \$parent_names[\$i];
          \$i++;
        }

        \$db->insert (Table	=> \$parent_namespace_info->{relatedto}->{'$namespace'}->{'table'},
                     Values	=> \\\%map_values)
          || die XML::Template::Exception->new ('DB', \$db->error ());
      }
    }
  }
};
!;
#print $outcode;

  return $outcode;
}

sub delete {
  my $self = shift;
  my ($code, $attribs) = @_;

  # Get attribs.
  my $name = $self->get_attrib ($attribs, 'name') || 'undef';

  # Generate named params assignments for the remaining atttribs.
  my $attribs_named_params = $self->generate_named_params ($attribs);

  # Get database info.
  my $namespace = $self->namespace ();
  my $namespace_info = $self->get_namespace ($namespace);
  my $dbname = $namespace_info->{sourcename};
  my $keys   = $namespace_info->{key};
  my $table  = $namespace_info->{table};

  my $outcode = qq!
do {
  \$vars->create_context ();

  my \%attribs = ($attribs_named_params);

  my \@names;

no strict;
  my \$parent_namespace = \$__parent_namespace;
  my \@parent_names  = \@__parent_names;
use strict;

  my \$table;
  if (defined \$parent_namespace) {
    my \$parent_namespace_info = \$process->get_namespace_info (\$parent_namespace);
    if (defined \$parent_namespace_info->{relatedto} &&
        defined \$parent_namespace_info->{relatedto}->{'$namespace'}) {
      \$table = \$parent_namespace_info->{relatedto}->{'$namespace'}->{table};
    } else {
      \$table = '$table';
    }
  } else {
    \$table = '$table';
  }

  my \$where;

  if (defined $name) {
    \@names = split (/\\s*,\\s*/, $name);
    my \$i = 0;
    foreach my \$key (split (',', '$keys')) {
      \$where .= ' and ' if defined \$where;
      \$where .= "\$table.\$key='\$names[\$i]'";
      \$i++;
    }
  }
  my \$twhere = \$process->generate_where (\\\%attribs, '$table');
  if (defined \$where && defined \$twhere) {
    \$where .= " and \$twhere";
  } elsif (defined \$twhere) {
    \$where = \$twhere;
  }

  if (defined \$parent_namespace) {
    my \$parent_namespace_info = \$process->get_namespace_info (\$parent_namespace);
    if (defined \$parent_namespace_info->{relatedto} &&
        defined \$parent_namespace_info->{relatedto}->{'$namespace'}) {
      my \$i = 0;
      foreach my \$key (split (',', \$parent_namespace_info->{key})) {
        \$where .= ' and ' if defined \$where;
        \$where .= "\$table.\$key='\$parent_names[\$i]'";
        \$i++;
      }
    }
  }

  my (\$__parent_namespace, \@__parent_names);
  if (defined $name) {
    \$__parent_namespace = '$namespace';
    \@__parent_names = split (/\\s*,\\s*/, $name);
  }

  $code

  my \$result;
  if (defined \$where) {
    my \$db = \$process->get_source ('$dbname');
    if (defined \$db) {
      \$db->delete (Table	=> \$table,
                   Where	=> \$where)
        || die XML::Template::Exception->new ('DB', \$db->error ());
    }

    if (defined $name) {
      my \$parent_namespace_info = \$process->get_namespace_info (\$parent_namespace);
      if (\! defined \$parent_namespace ||
          (defined \$parent_namespace &&
           (\! defined \$parent_namespace_info->{relatedto} ||
            \! defined \$parent_namespace_info->{relatedto}->{'$namespace'}))) {
        my \$namespace_info = \$process->get_namespace_info ('$namespace');
        if (defined \$namespace_info->{relatedto}) {
          foreach my \$namespace (keys \%{\$namespace_info->{relatedto}}) {
            my \$map_table = \$namespace_info->{relatedto}->{\$namespace}->{table};
            my \$where;
            \@names = split (/\\s*,\\s*/, $name);
            my \$i = 0;
            foreach my \$key (split (',', '$keys')) {
              \$where .= ' and ' if defined \$where;
              \$where .= "\$map_table.\$key='\$names[\$i]'";
              \$i++;
            }

            if (defined \$db) {
              \$db->delete (Table	=> \$map_table,
                            Where	=> \$where)
                || die XML::Template::Exception->new ('DB', \$db->error ());
            }
          }
        }
      }
    }
  }

  \$vars->delete_context ();
};
  !;

  return $outcode;
}

sub alter {
  my $self = shift;
  my ($code, $attribs) = @_;

  # Get attribs.
  my $values         = $self->get_attrib ($attribs, 'values')   || 'undef';
  my $action         = $self->get_attrib ($attribs, 'action')   || 'undef';
  my $columns        = $self->get_attrib ($attribs, ['columns', 'column']) || 'undef';
  my $new_column     = $self->get_attrib ($attribs, 'new_column') || 'undef';
  my $type           = $self->get_attrib ($attribs, 'type')     || 'undef';
  my $length         = $self->get_attrib ($attribs, 'length')   || 'undef';
  my $decimals       = $self->get_attrib ($attribs, 'decimals') || 'undef';
  my $unsigned       = $self->get_attrib ($attribs, 'unsigned') || 'undef';
  my $zerofill       = $self->get_attrib ($attribs, 'zerofull') || 'undef';
  my $binary         = $self->get_attrib ($attribs, 'binary')   || 'undef';
  my $null           = $self->get_attrib ($attribs, 'null')     || 'undef';
  my $def_default    = $self->get_attrib ($attribs, 'def_default') || 'undef';
  my $autoincrement  = $self->get_attrib ($attribs, 'auto_increment') || 'undef';
  my $def_primarykey = $self->get_attrib ($attribs, 'def_primary_key') || 'undef';
  my $position       = $self->get_attrib ($attribs, 'position') || 'undef';
  my $index          = $self->get_attrib ($attribs, 'index') || 'undef';
  my $primarykey     = $self->get_attrib ($attribs, 'primary_key') || 'undef';
  my $unique         = $self->get_attrib ($attribs, 'unique') || 'undef';
  my $fulltext       = $self->get_attrib ($attribs, 'fulltext') || 'undef';
  my $default        = $self->get_attrib ($attribs, 'default') || 'undef';
  my $new_table      = $self->get_attrib ($attribs, 'new_table') || 'undef';

  # Generate named params assignments for the remaining atttribs.
  my $attribs_named_params = $self->generate_named_params ($attribs);

  # Get database info.
  my $namespace_info = $self->get_namespace_info ($self->namespace ());
  my $dbname = $namespace_info->{sourcename};
  my $table  = $namespace_info->{table};

  my $outcode = qq!;
do {
  \$vars->create_context ();

  my \%attribs = ($attribs_named_params);
  \$vars->set (\%attribs);

  my \$db = \$process->get_source ('$dbname');
  if (defined \$db) {
    my \@values;
    my \$values = $values;
    \@values = split (/\s*,\s*/, \$values) if defined \$values;
    \$db->alter (
       Table		=> '$table',
       Action		=> $action,
       Column		=> $columns,
       Definition	=> {
         Column		=> $new_column,
         Type		=> $type,
         Length		=> $length,
         Decimals	=> $decimals,
         Values		=> \\\@values,
         Unsigned	=> $unsigned,
         ZeroFill	=> $zerofill,
         Binary		=> $binary,
         Null		=> $null,
         Default	=> $def_default,
         AutoIncrement	=> $autoincrement,
         PrimaryKey	=> $def_primarykey,
       },
       Position		=> $position,
       Index		=> $index,
       PrimaryKey	=> $primarykey,
       Unique		=> $unique,
       FullText		=> $fulltext,
       Default		=> $default,
       NewTable		=> $new_table)
       || die XML::Template::Exception->new ('DB', \$db->error ());
  }

  \$vars->delete_context ();
};
  !;

  return $outcode;
}

sub loopinit {
  my $self    = shift;
  my $attribs = shift;

  # Get attribs.
  my $fields  = $self->get_attrib ($attribs, ['fields', 'field']) || 'undef';
  my $query   = $self->get_attrib ($attribs, 'query')   || 'undef';
  my $orderby = $self->get_attrib ($attribs, 'orderby') || 'undef';
  my $limit   = $self->get_attrib ($attribs, 'limit')   || 'undef';
  my $match   = $self->get_attrib ($attribs, 'match')   || 'undef';
  my $round   = $self->get_attrib ($attribs, 'round')   || 'undef';

  # Generate named params assignments for the remaining atttribs.
  my $attribs_named_params = $self->generate_named_params ($attribs);

  # Get database info.
  my $namespace = $self->namespace ();
  my $namespace_info = $self->get_namespace_info ($namespace);
  my $dbname = $namespace_info->{sourcename};
  my $keys   = $namespace_info->{key};
  my $table  = $namespace_info->{table};

  my $outcode = qq!
my %attribs = ($attribs_named_params);

my \$tables = '$table';

my \$db = \$process->get_source ('$dbname')
  || die XML::Template::Exception->new ('DB', \$process->error);

my \$sql;
my \$query = $query;
if (defined \$query && \$query eq 'describe') {
  \$sql = \$db->_prepare_sql ('describe',
            {Table	=> '$table'});
} else {
  my \$where   = \$process->generate_where (\\\%attribs, '$table');

no strict;
  my \$parent_namespace = \$__parent_namespace;
  my \@parent_names = \@__parent_names;
use strict;

  if (defined \$parent_namespace) {
    my \$parent_namespace_info = \$process->get_namespace_info (\$parent_namespace);
    if (defined \$parent_namespace_info->{relatedto} &&
        defined \$parent_namespace_info->{relatedto}->{'$namespace'}) {
      \$tables .= ",\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}";

      my \$i = 0;
      foreach my \$key (split (',', '$keys')) {
        \$where .= ' and ' if defined \$where;
        \$where .= "$table.\$key=\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}.\$key";
        \$i++;
      }

      \$i = 0;
      foreach my \$key (split (',', \$parent_namespace_info->{key})) {
        \$where .= ' and ' if defined \$where;
        \$where .= "\$parent_namespace_info->{relatedto}->{'$namespace'}->{table}.\$key='\$parent_names[\$i]'";
        \$i++;
      }
    }
  }

  \$sql = \$db->_prepare_sql ('select',
            {Fields	=> $fields,
             Table	=> \$tables,
             Where	=> \$where,
             OrderBy	=> $orderby,
             Limit	=> $limit,
             Match	=> $match,
             Round	=> $round})
    || die XML::Template::Exception->new ('DB', \$db->error ());
}

my \$__sth;
if (defined $fields) {
  \$__sth = \$db->{_dbh}->prepare (\$sql)
    || die XML::Template::Exception->new ('DB', \$db->{_dbh}->errstr);
  \$__sth->execute
    || die XML::Template::Exception->new ('DB', \$db->{_dbh}->errstr);
}
  !;

  return $outcode;
}

sub get_first {
  my $self    = shift;
  my $attribs = shift;

  my $outcode = qq!
\$__value = \$__sth->fetchrow_hashref;
if (defined \$__value) {
  if (defined \$query && \$query eq 'describe') {
    my \$type = \$__value->{Type};
    \$type =~ s/\\(([^)]+)\\)\$//;
    \$__value->{Type} = \$type;
    if (\$type eq 'enum' || \$type eq 'set') {
      my \@values = split (/\\s*,\\*/, \$1);
      \$__value->{Values} = \\\@values;
    } else {
      \$__value->{Size} = \$1;
    }
  }
} else {
  \$__sth->finish;
  undef \$__sth;
}
  !;

  return $outcode;
}

sub set_loopvar {
  my $self    = shift;
  my $attribs = shift;

  # Get database info.
  my $namespace = $self->namespace ();
  my $namespace_info = $self->get_namespace_info ($namespace);
  my $keys = $namespace_info->{key};

  my $outcode = qq!
  while (my (\$name, \$val) = each \%\$__value) {
    \$vars->set (\$name => \$val);
  }

  my (\$__parent_namespace, \@__parent_names);
  if (defined \$__value) {
    \$__parent_namespace = '$namespace';
    foreach my \$key (split (/\s*,\s*/, '$keys')) {
      push (\@__parent_names, \$__value->{\$key});
    }
  }

  !;

  return $outcode;
}

sub get_next {
  my $self    = shift;
  my $attribs = shift;

  my $outcode = qq!
  \$__value = \$__sth->fetchrow_hashref;
  if (defined \$__value) {
    if (defined \$query && \$query eq 'describe') {
      my \$type = \$__value->{Type};
      \$type =~ s/\\(([^)]+)\\)\$//;
      \$__value->{Type} = \$type;
      if (\$type eq 'enum' || \$type eq 'set') {
        my \$values = \$1;
        \$values =~ s/^'//;
        \$values =~ s/'\$//;
        my \@values = split (/',\s*'/, \$values);
        \$__value->{Values} = \\\@values;
      } else {
        \$__value->{Size} = \$1;
      }
    }
  } else {
    \$__sth->finish;
    undef \$__sth;
  }
  !;

  return $outcode;
}
  
sub foreach_describe {
  my $self = shift;
  my ($code, $attribs) = @_;

  my $namespace = $self->namespace ();
  $attribs->{"$namespace\01query"} = "'describe'";
  return $self->foreach ($code, $attribs);
}

sub AUTOLOAD {
  my $self = shift;
  my ($code, $attribs) = @_;

  return if $AUTOLOAD =~ /DESTROY$/;

  $AUTOLOAD =~ /([^:]+)$/;
  my $field = $1;

  my $outcode = qq!
  my \$value;
  my \$io = IO::String->new (\$value);
  my \$ofh = select \$io;

  $code

  select \$ofh;
  \$value =~ s/&(?\!amp)/&amp\;/g;
  \$value =~ s/\\\\/\\\\\\\\/g;

no strict;
  \$values{'$field'} = \$value;
use strict;
  !;

  return $outcode;
}


1;
