# String::Random - Generates a random string from a pattern
# Copyright (C) 1999-2002 Steven Pritchard <steve@silug.org>
#
# This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# $Id: Random.pm,v 1.14 2002/07/26 04:53:11 steve Exp $

package String::Random;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

use Exporter ();

@ISA = qw(Exporter);
@EXPORT_OK = qw(random_string random_regex);
$VERSION = '0.1992';

use Carp;

use vars qw(@upper @lower @digit @punct @any @salt @binary);
use vars qw(%old_patterns %patterns %regch);

# These are the various character sets.
@upper=("A".."Z");
@lower=("a".."z");
@digit=("0".."9");
@punct=map { chr($_); } (33..47,58..64,91..96,123..126);
@any=(@upper, @lower, @digit, @punct);
@salt=(@upper, @lower, @digit, ".", "/");
@binary=map { chr($_) } (0..255);

# What's important is how they relate to the pattern characters.
# These are the old patterns for randpattern/random_string.
%old_patterns = (
    'C' => [ @upper ],
    'c' => [ @lower ],
    'n' => [ @digit ],
    '!' => [ @punct ],
    '.' => [ @any ],
    's' => [ @salt ],
    'b' => [ @binary ],
);

# These are the regex-based patterns.
%patterns = (
    # These are the regex-equivalents.
    '.' => [ @any ],
    '\d' => [ @digit ],
    '\D' => [ @upper, @lower, @punct ],
    '\w' => [ @upper, @lower, @digit, "_" ],
    '\W' => [ grep { $_ ne "_" } @punct ],
    '\s' => [ " ", "\t" ], # Would anything else make sense?
    '\S' => [ @upper, @lower, @digit, @punct ],

    # These are translated to their double quoted equivalents.
    '\t' => [ "\t" ],
    '\n' => [ "\n" ],
    '\r' => [ "\r" ],
    '\f' => [ "\f" ],
    '\a' => [ "\a" ],
    '\e' => [ "\e" ],
);

# These characters are treated specially in randregex().
%regch = (
   "\\" => sub
           {
               my ($self, $ch, $chars, $string)=@_;
               if (@{$chars})
               {
                   my $tmp=shift(@{$chars});
                   if ($tmp eq "x")
                   {
                       # This is supposed to be a number in hex, so
                       # there had better be at least 2 characters left.
                       $tmp=shift(@{$chars}) . shift(@{$chars});
                       push(@{$string}, [chr(hex($tmp))]);
                   }
                   elsif ($tmp=~/[0-7]/)
                   {
                       carp "octal parsing not implemented.  treating literally.";
                       push(@{$string}, [$tmp]);
                   }
                   elsif (defined($patterns{"\\$tmp"}))
                   {
                       $ch.=$tmp;
                       push(@{$string}, $patterns{$ch});
                   }
                   else
                   {
                       carp "'\\$tmp' being treated as literal '$tmp'";
                       push(@{$string}, [$tmp]);
                   }

		   # I originally had a fall-through to this.  It looks bogus,
		   # since all cases should have been caught above.  If nothing
		   # obvious breaks in the next version, I'll remove it.
		   #
                   #else
                   #{
                   #    push(@{$string}, [$tmp]);
                   #}
               }
               else
               {
                   croak "regex not terminated";
               }
           },
    '.' => sub
           {
               my ($self, $ch, $chars, $string)=@_;
	       push(@{$string}, $patterns{$ch});
           },
    '[' => sub
           {
               my ($self, $ch, $chars, $string)=@_;
               my @tmp;
               while (defined($ch=shift(@{$chars})) && ($ch ne "]"))
               {
                   if (($ch eq "-") && @{$chars} && @tmp)
                   {
                       $ch=shift(@{$chars});
                       for (my $n=ord($tmp[$#tmp]);$n<ord($ch);$n++)
                       {
                           push(@tmp, chr($n+1));
                       }
                   }
                   else
                   {
                       carp "'$ch' will be treated literally inside []"
                           if ($ch=~/\W/);
                       push(@tmp, $ch);
                   }
               }
               croak "unmatched []" if ($ch ne "]");
               push(@{$string}, \@tmp);
           },
    '{' => sub
           {
               my ($self, $ch, $chars, $string)=@_;
               my ($n, $closed);
               for ($n=0;$n<scalar(@{$chars});$n++)
               {
                   if ($chars->[$n] eq "}")
                   {
                       $closed++;
                       last;
                   }
               }
               if ($closed)
               {
                   my $tmp;
                   while (defined($ch=shift(@{$chars})) && ($ch ne "}"))
                   {
                       croak "'$ch' inside {} not supported" if ($ch!~/[\d,]/);
                       $tmp.=$ch;
                   }
		   if ($tmp=~/,/)
		   {
		       if (my ($min,$max) = $tmp =~ /^(\d*),(\d*)$/)
		       {
			   $min = 0 if (!length($min));
			   $max = 10 if (!length($max)); # FIXME $ass->{number}
			   croak "bad range {$tmp}" if ($min>$max);
			   if ($min == $max)
			   {
			       $tmp = $min;
			   }
			   else
			   {
		               $tmp = $min + int(rand($max - $min +1));
			   }
		       }
		       else
		       {
		           croak "malformed range {$tmp}";
		       }
		   }
		   if ($tmp)
		   {
                       my $last=$string->[$#{$string}];
                       for ($n=0;$n<($tmp-1);$n++)
                       {
                           push(@{$string}, $last);
                       }
		   }
		   else
		   {
		       pop(@{$string});
		   }
               }
               else
               {
                   # { isn't closed, so treat it literally.
                   push(@{$string}, [$ch]);
               }
           },
);

sub new
{
    my $proto=shift;
    my $class=ref($proto) || $proto;
    my $self;
    $self={ %old_patterns }; # makes $self refer to a copy of %old_patterns
    return bless($self, $class);
}

# Returns a random string for each regular expression given as an
# argument, or the strings concatenated when used in a scalar context.
sub randregex
{
    my $self=shift;
    croak "called without a reference" if (!ref($self));

    my @strings;

    while (my $pattern=shift)
    {
        my ($ch, @string, $string);

        # Split the characters in the pattern
        # up into a list for easier parsing.
        my @chars=split(//, $pattern);

        while (defined($ch=shift(@chars)))
        {
            if (defined($regch{$ch}))
	    {
	        $regch{$ch}->($self, $ch, \@chars, \@string);
	    }
            elsif ($ch=~/[\$\^\*\(\)\+\{\}\]\|\?]/)
            {
                # At least some of these probably should have special meaning.
                carp "'$ch' not implemented.  treating literally.";
                push(@string, [$ch]);
            }
            else
            {
                push(@string, [$ch]);
            }
        }

        foreach $ch (@string)
        {
            $string.=$ch->[int(rand(scalar(@{$ch})))];
        }

	push(@strings, $string);
    }

    return wantarray ? @strings : join("", @strings);
}

# For compatibility with an ancient version, please ignore...
sub from_pattern
{
    my $self=shift;
    croak "called without a reference" if (!ref($self));

    return $self->randpattern(@_);
}

sub randpattern
{
    my $self=shift;
    croak "called without a reference" if (!ref($self));

    my @strings;

    while (my $pattern=shift)
    {
        my $string;

        for my $ch (split(//, $pattern))
        {
            if (defined($self->{$ch}))
            {
                $string.=$self->{$ch}->[int(rand(scalar(@{$self->{$ch}})))];
            }
            else
            {
                croak qq(Unknown pattern character "$ch"!);
            }
        }
        push(@strings, $string);
    }

    return wantarray ? @strings : join("", @strings);
}

sub random_regex
{
    my %foo=%patterns;
    return randregex(\%foo, @_);
}

sub random_string
{
    my($pattern,@list)=@_;

    my($n,%foo);

    %foo=%old_patterns;

    for ($n=0;$n<=$#list;$n++)
    {
        @{$foo{$n}}=@{$list[$n]};
    }

    return randpattern(\%foo, $pattern);
}

1;
__END__

=head1 NAME

String::Random - Perl module to generate random strings based on a pattern

=head1 SYNOPSIS

  use String::Random;
  $foo = new String::Random;
  print $foo->randregex('\d\d\d'); # Prints 3 random digits
  print $foo->randpattern("...");  # Prints 3 random printable characters

I<or>

  use String::Random qw(random_regex random_string);
  print random_regex('\d\d\d'); # Also prints 3 random digits
  print random_string("...");   # Also prints 3 random printable characters

=head1 DESCRIPTION

This module makes it trivial to generate random strings.

As an example, let's say you are writing a script that needs to generate a
random password for a user.  The relevant code might look something like
this:

  use String::Random;
  $pass = new String::Random;
  print "Your password is ", $pass->randpattern("CCcc!ccn"), "\n";

This would output something like this:

  Your password is UDwp$tj5

For another example, let's say you were going to generate a 

  use String::Random;
  $pass = new String::Random;
  print "Your password is ", $pass->randpattern("CCcc!ccn"), "\n";


=head2 Patterns

The pre-defined patterns (for use with C<randpattern()> and C<random_pattern()>)
are as follows:

  c        Any lowercase character [A-Z]
  C        Any uppercase character [a-z]
  n        Any digit [0-9]
  !        A punctuation character [~`!@$%^&*()-_+={}[]|\:;"'.<>?/#,]
  .        Any of the above
  s        A "salt" character [A-Za-z0-9./]
  b        Any binary data

These can be modified, but if you need a different pattern it is better to
create another pattern, possibly using one of the pre-defined as a base.
For example, if you wanted a pattern C<A> that contained all upper and lower
case letters (C<[A-Za-z]>), the following would work:

  $foo = new String::Random;
  $foo->{'A'} = [ 'A'..'Z', 'a'..'z' ];

I<or>

  $foo = new String::Random;
  $foo->{'A'} = [ @{$foo->{'C'}}, @{$foo->{'c'}} ];

The random_string function, described below, has an alternative interface
for adding patterns.

=head2 Methods

=over 8

=item randpattern LIST

The randpattern method returns a random string based on the concatenation
of all the pattern strings in the list.

Please note that in a future revision, it will return a list of random
strings corresponding to the pattern strings when used in list context.  In
other words, using this method in a list context is currently not
recommended.

=item randregex LIST

The randregex method returns a random string that will match the regular
expression passed in the list argument.

Please note that the arguments to randregex are not real regular
expressions.  Only a small subset of regular expression syntax is actually
supported.  So far, the following regular expression elements are
supported:

  []    Character classes
  {}    Repetition
  \w    Alphanumeric + "_".
  \d    Digits.
  \W    Printable characters other than those in \w.
  \D    Printable characters other than those in \d.

Regular expression support is still very experimental.  Currently special
characters inside [] are not supported (with the exception of "-" to denote
ranges of characters).  The parser doesn't care for spaces in the "regular
expression" either.

=back

=head2 Functions

=over 8

=item random_string PATTERN,LIST

=item random_string PATTERN

When called with a single scalar argument, random_string returns a random
string using that scalar as a pattern.  Optionally, references to lists
containing other patterns can be passed to the function.  Those lists will
be used for 0 through 9 in the pattern (meaning the maximum number of lists
that can be passed is 10).  For example, the following code:

  print random_string("0101",
                      ["a", "b", "c"],
                      ["d", "e", "f"]), "\n";

would print something like this:

  cebd

=back

=head1 BUGS

This is Bug Free(TM) code.  (At least until somebody finds one...)

=head1 AUTHOR

Steven Pritchard <steve@silug.org>

=head1 SEE ALSO

perl(1).

=cut
