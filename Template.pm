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

$VERSION = '1.0.2';


#####
# Pre: None
# Post: Return the version
sub version { $XML::Template::VERSION }


#####
# New (constructor)
#
# Pre: Argument is a path context for the template
#      and optionally, a format for the error messages.
# Post: Creates a new Template object
sub new {
    my $self = shift;
    my $path = shift;
    # Default format for XML/HTML applications
    my $format = "<!-- %s -->\n";

    # Any remaining arguments are options
    my $opt;
    while ($opt = shift) {
        if ($opt eq "format") {
            $format = shift;
        }
    }
    
    bless { 
        path => $path,
        format => $format,
    }, $self;
}


#####
# Message: Returns the string message formatted as $self->{format}
#
# Pre: None
# Post: As above
sub message {
    my $self = shift;

    sprintf($self->{format}, @_);
}

#####
# Compose: This reads in the file and hands it off to compose_string
#
# Pre: Argument is a hash of the data to fill the template and a filename
# Post: Forms the template itself, printing it out
sub compose {
    my($self, $data, $file) = @_;

    if (!defined $file) {
        return $self->message("Template file not defined");
    }
    if (!defined $self->{path}) {
        return $self->message("Template path not defined");
    }

    # This will construct the text to be returned
    $self->{out} = "";

    my $filename = "$self->{path}/$file";
    unless (-f $filename) {
	return $self->message("Template file $filename not found: $!");
    }
    unless( open (FILE, $filename) ) {
	return $self->message("Template file $filename not readable: $!");
    }
    local($/) = undef;
    my $text = <FILE>;
    close(FILE);

    return $self->compose_string($data, $text);
	
} # end compose

#####
# Compose_string: parses input text into tokens and hands them off to
#                 recursive_interpret
#
# Pre: Argument is a hash of the data to fill the template and a string
# Post: Forms the template itself, printing it out
sub compose_string {
    my($self, $data, $text) = @_;

    # set top-level context
    $self->{top} = $data;

    # Split into tokens based on <template></template> tags
    # Doesn't really require it to be well-formed, just that it begins...
    my @tokens = split /(<\/?template>)/sio, $text;
    
    my $in_context = 0;
    
    while ( scalar(@tokens) ) {
	
	my $token = shift(@tokens);
	
	if ( $token =~ /^<template>$/io ) {
	    $in_context = 1;
	} elsif ( $token =~ /^<\/template>$/io ) {
	    $in_context = 0;
	} else {
	    if ( $in_context ) { 	    # pass this to be interpreted
		$self->recursive_interpret($token, $data);
	    } else {	    # uninterpreted text
		$self->{out} .= $token;
	    }
	} # end if($token)
	
    } # end while
    
    # Join the warnings and the output from the recursive_interpret
    my $out = $self->{out};
    $self->{out} = undef;
    return $out;

} # end compose_string


######
# Recursive_Interpret: Passes contexts recursively to be parsed
#
# Pre: Accepts a (multi-line) string of text and a hash
# Post: Places the parsed text and/or appropriate error messages into $self->{out}
sub recursive_interpret{
    my($self, $text, $data) = @_;

    my @tokens = $self->tokenize($text);

    while ( scalar(@tokens) ) {
    
	my $token = shift(@tokens);
	my $tokenMatch; # The part of the token that we want (usually an attribute)

	if ( $tokenMatch = $self->match_variable($token) ) {
	    # $tokenMatch contains the name of the variable
	    $self->do_variable($data, $tokenMatch);

	} elsif ( $tokenMatch = $self->match_assign($token) ) {
	    # Now we have to match the value, the name is in tokenMatch
	    $self->do_assign($data, $tokenMatch, $token);

	} elsif ( $tokenMatch = $self->match_include($token) ) {
	    # $tokenMatch contains the filename to include
	    $self->do_include($data, $tokenMatch);

	} elsif ( $tokenMatch = $self->match_variableInclude($token) ) {
	    # $tokenMatch contains the variable name containing the file
	    $self->do_variableInclude($data, $tokenMatch);

	} elsif ( $tokenMatch = $self->match_repeat($token) ) {
	    # First we have to find the ending </repeat> tag
	    # Right now this happens by joining then splitting
	    $text = join '', @tokens;
	    my @context = split /(<\/?repeat[^>]*>)/iso, $text;
	    my $context;
	    ($context, @context) =  $self->context('repeat', @context);
	    # Assign the hash context based on the token
	    my $hash = $self->set_hash($data, $tokenMatch);
            # Perform the repeat
	    $self->do_repeat($context, $hash);
            # Restore token list at the point *after* the </repeat>
	    $text = join '', @context;
	    @tokens = $self->tokenize($text);

	} elsif ( $tokenMatch = $self->match_with($token) ) {
	    # First we have to find the ending </with> tag
	    # Right now this happens by joining, then splitting for it.
	    $text = join '', @tokens;
	    my @context = split /(<\/?with[^>]*>)/iso, $text;
	    my $context;
	    ($context, @context) =  $self->context('with', @context);
	    # Assign the hash context based on the token
	    my $hash = $self->set_hash($data, $tokenMatch);
	    # Perform the with
	    $self->do_with($context, $hash);
	    # Restore the token list at the point *after* the </with>
	    $text = join '', @context;
	    @tokens = $self->tokenize($text);

	} else {
	    # plain text (here it's something we couldn't figure out)
	    $self->{out} .= $token;

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
    split ( m/(
	      # variable
	      \$\([^)]*\)
	      # variable
	      | \${[^}]*}
	      # assign tag
	      | <assign [^\/]*\/>
	      # include tag
	      | <include [^"]+\"[^"]+\"[^\/]*\/>
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
	if ( $variable =~ /^now$/io ) {
	    $self->{out} .= localtime;
	} elsif ( $variable =~ /^date$/io ) {
	    $self->{out} .= strftime("%x",localtime);
	} elsif ( $variable =~ /^time$/io ) {
	    $self->{out} .= strftime("%X",localtime);
	} else {
	    $self->{out} .= $self->message("Variable $variable not found");
	    $self->{out} .= $variable;
	} #if NOW, DATE, TIME
    }
}

#####
# Match_Assign: Does the token match an <assign ...> tag?
#
# Pre: Passed the token to check
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
	$self->{out} .= $self->message("Assign to $variable didn't have a value");
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
    if ( $token =~ /^<include.*?\s+src=\"([^"]+)\"[^\/]*\/>$/io) {
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
	$self->{out} .= $self->message("Template file $rawFilename not allowed");
	return;
    } elsif ( $rawFilename =~ /\.\./o) {
	$self->{out} .= $self->message("Template file $rawFilename not allowed");
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
	$self->{out} .= $self->message("Template file $filename not readable: $!");
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
	$self->{out} .= $self->message("VariableInclude variable $variable not found");
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
		my $hash = $data->{$key};
                # check reference to avoid fatal later on -- AA
                unless (ref($hash) eq "HASH") {
                    $self->{out} .= 
                        $self->message("Nested key '$key' not a hash ref!");
                   $hash = {};
                }
                $self->recursive_interpret($text, { "_" => $key, %{$hash} });
	    }
	#-- feh : 17.07.1999 : added ARRAY support
	#
	} elsif ( defined $data && ref($data) eq "ARRAY" ) {
	    my $key = 0; # Arrays indexed from 0
	    foreach my $hash ( @{$data} ) {
                # check reference to avoid fatal later on -- AA
                unless (ref($hash) eq "HASH") {
                    $self->{out} .= 
                        $self->message("Array element '$key' not a hash ref!");
                    $hash = {};
                }
                $self->recursive_interpret($text, { "_" => $key++, %{$hash} });
	    }
	} else {
	    $self->{out} .= $self->messsage("Repeat namespace does not exist!");
	    $self->{out} .= $text;
	}
    } else {
	$self->{out} .= $self->message("Repeat context left empty");
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
    my ($self, $text, $data) = @_;

    if ( defined $text ) {
	# do we actually have a hash to enter?
	if ( defined $data && ref($data) eq "HASH" ) {
	    $self->recursive_interpret($text, $data);
	} else {
	    # Nope, we don't have anything useful...
	    $self->{out} .= $self->message("With namespace does not exist");
	    $self->{out} .= $text;
	}
    } else {
	$self->{out} .= $self->message("With context left empty.");
	$self->{out} .= $text;
    }

}

#####
# Context: Find the context of data
#
# Pre: Passed the context type and array of splitted data
# Post: Returns the context and remaing data
sub context {
    my ($self, $tag, @tokens) = @_;

    $tag = $1 if $tag =~ m:^\s*</?(\w+):s;
    my $context = "";
    my $sub_lvl = 0;
  WHILE:
    while( @tokens ) {
	my $t = shift @tokens;
	++$sub_lvl if $t =~ m:^\s*<$tag:s;
	if ( $t =~ m:^\s*</$tag>\s*:s ) {
	    if( $sub_lvl ) {
		--$sub_lvl;
	    }else{
		$t =~ s:</$tag>::ms; 
		$context .= $t;
		last WHILE;
	    }
	}
	$context .= $t;
    } # end while
    return ($context, @tokens);
}

#####
# Set_hash: Returns a reference to a hash pointing to the data structure
# relative to path
#
# Pre: Passed the text to be used, a hash of data and the context name
# Post: Places the recursively-parsed text or an error message into $self->{out}
#
# The syntax for a context path is a la XQL/XSL:
#     "/top/mid/bot"   => $namespace->{top}->{mid}->{bot}
#     "this/that"      => $current->{this}->{that}
#     "../above/below" => not supported (yet)
# arrays are supported by using digits in path segments
# (note that initial index array is set to 1 rather than 0):
#     "/foo/2/bar"     => $namespace->{foo}->[1]->{bar}
# Context is reset to top level if path consists of a slash or an empty string
sub set_hash {
    my $self = shift;
    my ($hash, $path) = @_;
    my $context = $hash;

    if ($path =~ /^env$/io) {
        # OK, so it wasn't defined, but maybe it's the magic "ENV" namespace
        $context = \%ENV;
	
    } elsif ($path =~ /^\s*\/\s*$/o) {
        # reset path to top of hash structure
        $context = $self->{top};

    } elsif ($path =~ /^\s*$/o) {
        # assume equivalent to "/" and issue a warning
        $self->{out} .= $self->message("Assuming top-level context for null path");
        $context = $self->{top};

    } elsif ($path) {
        # reset context to top of tree if path begins with "/"
        my @tree = split(m:/+:, $path);
        $context = $tree[0] ? $hash : $self->{top};
        while (@tree and $context and ref($context)) {
            my $el = shift(@tree);
            next unless $el;
            if (ref($context) eq "ARRAY" and $el =~ /^\d+$/o and
                defined($context->[$el-1])) {
                $context = $context->[$el-1];
            } elsif (ref($context) eq "HASH" and 
                     defined($context->{$el})) {
                $context = $context->{$el};
            } else {
                $context = undef;
                last;
            }
        } # end while
    } #end if (type of token)

    if (defined $context and 
        (ref($context) eq "HASH" or ref($context) eq "ARRAY")) {
        return $context;
    } else {       
        # Nope, we don't have anything useful...
        $self->{out} .= $self->message("Context path '$path' does not exist!");
        return undef;
    }   
} # end set_hash

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

 my $interp = XML::Template->new("examples", format => "<!-- %s -->");
 print $interp->compose(\%namespace, "example.xmlt");
 print $interp->compose_string(\%ns,"<template>${foo}</template>");

 <template>
    $(var) or ${var}
    ${DATE}
    ${TIME}
    ${NOW}

    <assign name="not_ok" value="ok"/>
    <include src="foobar.xmlt"/>
    <variableInclude name="foobar"/>

    <repeat name="RESULTS">
    hash key: ${_} 
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

To call it, simply call as shown in the synopsis. 
Arguments to new() are a directory where all XML template files are rooted
possibly followed by an associative array of additional options.  
The ones currently supported are:

 format => FMT   
   use FMT to format output messages produced by the parser; FMT
   is specified using the standard sprintf formats and defaults to 
   "<!-- %s -->\n"

The functions compose() and compose_string() take a hash reference
and a filename (compose) or a string (compose_string) to parse and
interpolate according to the hash.
Any text inside any <template></template> tags will be
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

<with name="nested"></with> -- use the nested hash for variable substitution.

<repeat name="nested"></repeat> -- repeat for every item in nested hash.
If no name attribute is given, the items are selected from the root namespace.

The syntax for the namespaces specified with the "name" 
attribute of the <with> and <repeat> tags follow a syntax similar to XQL/XSL:

  "/"              => root namespace $root
  "/top/mid/bot"   => $root->{top}->{mid}->{bot}
  "this/that"      => $current->{this}->{that}
  "../above/below" => not supported (yet)
  "ENV"            => environment variables

Anonymous arrays in the namespace structure are supported by using
digits in path segments (note that initial index array is 0):

   "/foo/2/bar"    => $root->{foo}->[0]->{bar}

In addition, variable substitution supports DATE, TIME, and NOW,
the system's default date, time, and date-time strings.

=head1 AUTHOR

Geoff Hutchison <ghtuchis@wso.williams.edu>

=head1 SEE ALSO

ePerl(1), HTML::Embperl

=cut
