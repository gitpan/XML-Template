#**************************************************************************
#
# XML::Template
# A simple template parsing system using XML "shortcut" tags
#
# Inspired by all the other template systems out there...
#
# Copyright (c) 1999 Geoffrey R. Hutchison <ghutchis@wso.williams.edu>
#
# <legal>
# You may distribute under the terms of either the GNU General Public 
# License or the Artistic License, as specified in the Perl README file.
# For use with Apache httpd and mod_perl, see also Apache copyright.
#
# THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED 
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF 
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# </legal>
#
#**************************************************************************
package XML::Template;

use strict;
use POSIX qw(strftime);

use vars qw($VERSION);

$VERSION = '1.0.1';


#####
# Pre: None
# Post: Return the version
sub version { $XML::Template::VERSION }


#####
# New (constructor)
#
# Pre: Argument is a path context for the template
# Post: Creates a new Template object
sub new {
    my($self, $path) = @_;

    bless { path => $path }, $self;
}


#####
# Compose: This reads in the file and hands it off to interpret_text
#
# Pre: Argument is a hash of the data to fill the template and a filename
# Post: Forms the template itself, printing it out
sub compose {
    my($self, $data, $file) = @_;

    if (!defined $file) {
        return "<!-- Template file not defined -->\n";
    }
    if (!defined $self->{path}) {
	return "<!-- Template path not defined -->\n";
    }

    # This will construct the text to be returned
    $self->{out} = "";

    my $filename = "$self->{path}/$file";
    if (-f $filename) {
	unless( open (FILE, $filename) ) {
	    return "<!-- Template file $filename not readable: $! -->\n";
	}
	local($/) = undef;
	my $text = <FILE>;
	close(FILE);
	
	# Split into tokens based on <template></template> tags
	# Doesn't really require it to be well-formed, just that it begins...
	my @tokens = split /(<\/?template>)/sixo, $text;

	my $in_context = 0;

	while ( scalar(@tokens) ) {
	    
	    my $token = @tokens->[0];

	    if ( $token eq "<template>" ) {
		$in_context = 1;
	    } elsif ( $token eq "<\/template>" ) {
		$in_context = 0;
	    } else {
		if ( $in_context ) { 	    # pass this to be interpreted
		    $self->recursive_interpret($token, $data);
		} else {	    # uninterpreted text
		    $self->{out} .= $token;
		}
	    } # end if($token)

	    shift @tokens;
	} # end while

	# Join the warnings and the output from the recursive_interpret
	my $out = $self->{out};
	$self->{out} = undef;
	return $out;
    } # end if(file)

    return "<!-- Template file $filename not readable: $! -->\n";
} # end compose


######
# Recursive_Interpret: Passes contexts recursively to be parsed
#
# Pre: Accepts a (multi-line) string of text and a hash
# Post: Places the parsed text and/or appropriate error messages into $self->{out}
sub recursive_interpret{
    my($self, $text, $data) = @_;

    my @tokens = $self->tokenize($text);

    while ( scalar(@tokens) ) {
    
	my $token = @tokens->[0];
	my $tokenMatch; # The part of the token that we want (usually an attribute)

	if ( $tokenMatch = $self->match_variable($token) ) {
	    # $tokenMatch contains the name of the variable
	    $self->do_variable($data, $tokenMatch);
	    shift @tokens;

	} elsif ( $tokenMatch = $self->match_assign($token) ) {
	    # Now we have to match the value, the name is in tokenMatch
	    $self->do_assign($data, $tokenMatch, $token);
	    shift @tokens;

	} elsif ( $tokenMatch = $self->match_include($token) ) {
	    # $tokenMatch contains the filename to include
	    $self->do_include($data, $tokenMatch);
            shift @tokens;

	} elsif ( $tokenMatch = $self->match_variableInclude($token) ) {
	    # $tokenMatch contains the variable name containing the file
	    $self->do_variableInclude($data, $tokenMatch);
            shift @tokens;

	} elsif ( $tokenMatch = $self->match_repeat($token) ) {
	    # First we have to find the ending </repeat> tag
	    # Right now this happens by joining then splitting
	    shift @tokens;
	    $text = join '', @tokens;
	    my @context = split /<\/repeat>/iso, $text;
	    # Perform the repeat
	    $self->do_repeat(@context->[0], $data->{$tokenMatch});
	    # Restore token list at the point *after* the </repeat>
	    shift @context;
	    $text = join '</repeat>', @context;
	    @tokens = $self->tokenize($text);

	} elsif ( $tokenMatch = $self->match_with($token) ) {
	    # First we have to find the ending </with> tag
	    # Right now this happens by joining, then splitting for it.
	    shift @tokens;
	    $text = join '', @tokens;
	    my @context = split /<\/with>/iso, $text;
	    # Perform the with
	    $self->do_with(@context->[0], $data->{$tokenMatch}, $tokenMatch);
	    # Restore the token list at the point *after* the </with>
	    shift @context;
	    $text = join '</with>', @context;
	    @tokens = $self->tokenize($text);

	} else {
	    # plain text (here it's something we couldn't figure out)
	    $self->{out} .= $token;
	    shift @tokens;

	} # end if($token)	
    } # end while(tokens)
} # end recursive parse


#####
# Tokenize: Helper for recursive_interpret to split the text into tokens
#
# Pre: Text input is to be split into tokens to be parsed
# Post: Returns the list of tokens
sub tokenize{
    my ($self, $text) = @_;
    split ( /(
	      # variable
	      \$\([^)]*\)
	      # variable
	      | \${[^}]*}
	      # assign tag
	      | <assign [^\/]*\/>
	      # include tag
	      | <include [^\/]*\/>
	      # variableInclude tag
	      | <variableInclude [^\/]*\/>
	      # repeat context
	      | <repeat [^>]*>
	      # with context
	      | <with [^>]*>
	      )/isxo, $text );
}


#####
# Match_Variable: Does the token match $(variable) or ${variable} ?
#
# Pre: Passed to token to check
# Post: Returns the variable name if it matches, undef otherwise
sub match_variable{
    my ($self, $token) = @_;

    # token must match $ then { or ( a variable name and ) or }
    if ( $token =~ /^\$[{\(](\w+)[}\)]$/io) {
	return $1;
    } else {
	return undef;
    }
}


#####
# Do_Variable: Perform variable substitution
#
# Pre: Passed the data in a hash and the variable name
# Post: Places the recursively-parsed text or an error message into $self->{out}
sub do_variable{
    my ($self, $data, $variable) = @_;

    if (defined $data->{$variable}) {
	$self->{out} .= $data->{$variable};
    } else { 
	# not in the namespace, 
	# so try to match "magic" tokens NOW, DATE, and TIME
	if ( $variable =~ /^now$/i ) {
	    $self->{out} .= localtime;
	} elsif ( $variable =~ /^date$/i ) {
	    $self->{out} .= strftime("%x",localtime);
	} elsif ( $variable =~ /^time$/i ) {
	    $self->{out} .= strftime("%X",localtime);
	} else {
	    $self->{out} .= "<!-- Variable $variable not found -->\n";
	    $self->{out} .= $variable;
	} #if NOW, DATE, TIME
    }
}

#####
# Match_Assign: Does the token match an <assign ...> tag?
#
# Pre: Passed the toekn to check
# Post: Returns the variable name if it matches, undef otherwise
sub match_assign{
    my ($self, $token) = @_;
    
    # token must start with <assign then "stuff" then name="..."  ... />
    if ( $token =~ /^<assign.*?\s+name=\"(\w+)\"[^\/]*\/>$/io) {
	return $1;
    } else {
  	return undef;
    }
}


#####
# Do_Assign: Self-explanatory (hopefully?)
#
# Pre: Passed the data in a hash, the variable and the token (for finding the value)
# Post: Assigns the value found in the token into the hash or writes an error
sub do_assign{
    my ($self, $data, $variable, $token) = @_;

    if ( $token =~ /^<assign.*?\s+value=\"(.+?)\".*?\/>$/io) {
	$data->{$variable} = $1;
    } else {
	$self->{out} .= "<!-- Assign to $variable didn't have a value --> \n";
	$self->{out} .= $token;
    }
}


#####
# Match_Include: Does the token match an <include ...> tag?
#
# Pre: Passed the token to check
# Post: Returns the filename to include if it matches, undef otherwise
sub match_include{
    my ($self, $token) = @_;
    
    # token must start with <include ... src="..."  ... />
    if ( $token =~ /^<include.*?\s+src=\"(.+)\"[^\/]*\/>$/io) {
	return $1;
    } else {
  	return undef;
    }
  }


#####
# Do_Include: Includes the filename specified as a parsed template
#
# Pre: Passed the data as a hash and a filename
# Post: Places the recursively-parsed text or an error message into $self->{out}
sub do_include{
    my ($self, $data, $rawFilename) = @_;

    # match_include is pretty liberal about includes for speed reasons
    # But we never want to go outside of the defined $self->{path} 'jail'
    # for security reasons (even if we want to allow subdirectories of it)
    if ( $rawFilename =~ /^\//o) {
	$self->{out} .= "<!-- Template file $rawFilename not allowed -->\n";
	return;
    } elsif ( $rawFilename =~ /\.\./o) {
	$self->{out} .= "<!-- Template file $rawFilename not allowed -->\n";
	return;
    }

    # OK, we're safe now, we don't have an absolute path or a .. sequence
    my $filename = $self->{path} . "/" . $rawFilename;
    
    if ( (-f $filename) && (open (FILE, $filename)) ) {
	local($/) = undef;
	my $include_text = <FILE>;
	close(FILE);
	
	# recurse on the included file
	$self->recursive_interpret($include_text, $data);
    } else {
	$self->{out} .= "<!-- Template file $filename not readable: $! -->\n";
    }
}

#####
# Match_VariableInclude: Does the token match an <variableInclude ...> tag?
#
# Pre: Passed the token to check
# Post: Returns the varible of the filename to include if it matches, undef otherwise
sub match_variableInclude{
    my ($self, $token) = @_;
    
    # token must start with <variableInclude ... name="$..."  ... />
    if ( $token =~ /^<variableInclude.*?\s+name=\"(\w+)\"[^\/]*\/>$/io) {
	return $1;
    } else {
  	return undef;
    }
}


#####
# Do_VariableInclude: Includes the variable filename specified as a parsed template
#
# Pre: Passed the data as a hash and a variable of a filename
# Post: Places the recursively-parsed text or an error message into $self->{out}
sub do_variableInclude{
    my ($self, $data, $variable) = @_;

    my $filename;

    if (defined $data->{$variable}) {
	$filename = $data->{$variable};

	$self->do_include($data, $filename);
    } else { 
	$self->{out} .= "<!-- VariableInclude variable $variable not found -->\n";
    }
}


#####
# Match_Repeat: Does it match a <repeat ...> tag?
#
# Pre: Passed the token to check
# Post: Returns the namespace if it matches, undef otherise
sub match_repeat{
    my ($self, $token) = @_;
    
    # token must start with <repeat ... name="..." ...>
    if ( $token =~ /^<repeat.*?\s+name=\"(\w+)\"[^>]*>$/io) {
	return $1;
    } else {
  	return undef;
    }
}


#####
# Do_Repeat: Repeat the text given as a parsed template
#
# Pre: Passed the text to repeat and the data to use for the repeat
# Post: Places the recursively-parsed text or an error message into $self->{out}
sub do_repeat{
    my ($self, $text, $data) = @_;

    if ( defined $text ) {
	# pick out the data to repeat and recurse
	if ( defined $data && ref($data) eq "HASH" ) {
	    my $key;
	    foreach $key ( sort (keys %{$data} ) ) {
		$self->recursive_interpret($text, $data->{$key});
	    }
	#-- feh : 17.07.1999 : added ARRAY support
	#
	} elsif ( defined $data && ref($data) eq "ARRAY" ) {
	    foreach my $hash_data ( @{$data} ) {
		$self->recursive_interpret($text, $hash_data);
	    }
	} else {
	    $self->{out} .= "<!-- Repeat namespace does not exist! -->\n";
	    $self->{out} .= $text;
	}
    } else {
	$self->{out} .= "<!-- Repeat context left empty -->\n";
	$self->{out} .= $text;
    }
    
}


#####
# Match_With: Does the token match a <with...> tag?
#
# Pre: Passed a token to check
# Post: Returns the hash context to use if it matches, undef otherwise
sub match_with{
    my ($self, $token) = @_;

    # token must start with <with ... name="..." ...>
    if ( $token =~ /^<with.*?\s+name=\"(\w+)\"[^>]*>$/io) {
	return $1;
    } else {
  	return undef;
    }
}


#####
# Do_With: Enter the nested hash and interpret by calling recursive_interpret
#
# Pre: Passed the text to be used, a hash of data and the context name
# Post: Places the recursively-parsed text or an error message into $self->{out}
sub do_with{
    my ($self, $text, $data, $tokenMatch) = @_;

    if ( defined $text ) {
	# do we actually have a hash to enter?
	if ( defined $data && ref($data) eq "HASH" ) {
	    $self->recursive_interpret($text, $data);
	} elsif ( $tokenMatch =~ /^env$/i ) {
	    # OK, so it wasn't defined, but maybe it's the magic "ENV" namespace
	    $self->recursive_interpret($text, \%ENV);
	} else {
	    # Nope, we don't have anything useful...
	    $self->{out} .= "<!-- With namespace does not exist -->\n";
	    $self->{out} .= $text;
	}
    } else {
	$self->{out} .= "<!-- With context left empty. -->\n";
	$self->{out} .= $text;
    }

}


1;
__END__
# This is the documentation. Use with perldoc and/or pod2* utilities.

=head1 NAME

XML::Template - Perl XML template instantiation

=head1 SYNOPSIS

  use XML::Template;
  my %namespace = (
	      foo => "bar",
  );

 my $interp = XML::Template->new("examples");
 print $interp->compose(\%namespace, "example.xmlt");

 <template>
    $(var) or ${var}
    ${DATE}
    ${TIME}
    ${NOW}

    <assign name="not_ok" value="ok"/>
    <include src="foobar.xmlt"/>
    <variableInclude name="foobar"/>

    <repeat name="RESULTS">
      ${NUMBER}: ${RESULT}
    </repeat>
    
    <with name="nested_hash">
    ${result}
    </with>

    <with name="ENV">
    ${SCRIPT_NAME}
    </with>
 </template>

=head1 DESCRIPTION

The XML::Template module provides for assembling templates using a
simple XML tag markup. The code is not limited to parsing XML
documents. It works on any text document, including (of course) HTML, 
but is labeled as an XML template system because it uses XML tags for
the markup used.

I don't pretend that this is a unique idea. There are *many* Perl
template systems. What separates this one from the pack (AFAIK) is
that it supports more than just variable substituion. Using XML
markup, you can include other template files, perform simple variable
assignment, nested namespaces, and best of all, perform simple looping
constructs. For kicks, it also offers the CGI environment variables as
builtins, as well as the server's current date, time and date/time string.

In short the module offers what I see as the 80/20 rule. It doesn't
allow full Perl constructs (see something like ePerl or HTML::Embperl
for that) but implements the 20% of the features that make up 80% of
the needs for templates. It also serves as an excellent pre-processor
for either ePerl or HTML::Embperl or the like. ;-)

To call it, simply call as shown in the synopsis. Pass it a directory
when calling new() and data and a file when calling
compose. Any text inside any <template></template> tags will be
interpreted. The remaining text will be completely ignored, useful for
those situations where you want to use '$' characters, or simply want
the parser to run faster.

The template language supports the following syntax:

<template></template> -- Define the sections of the file to interpret

$(variable) or ${variable} -- identifiers are word characters
(including the underscore)

<include src="filename" /> -- filename is rooted by the path given at new()

<variableInclude name="variable"/> -- include the file pointed to by variable

<assign name="variable" value="..."/> -- assign "..." to identifier "variable"
<assign value="..." name="variable"/>

<with name="nested"></with> -- use the nested hash for variable substitution

<repeat name="repeated"></repeat> -- repeat for every item in nested hash

In addition, the <with> tag supports ENV for including environment
variables, and variable substitution supports DATE, TIME, and NOW,
the system's default date, time, and date-time strings.

=head1 AUTHOR

Geoff Hutchison <ghtuchis@wso.williams.edu>

=head1 SEE ALSO

ePerl(1), HTML::Embperl

=cut
