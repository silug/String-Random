use Test::More tests => 16;

# 1: Make sure we can load the module
BEGIN { use_ok('String::Random'); }

# 2: Make sure we can create a new object
$foo=new String::Random;
$bar=new String::Random; # A spare for later
ok(defined($foo) && defined($bar), "new()");

# 3: Test function interface to randpattern()
$abc=String::Random::random_string("012", ['a'], ['b'], ['c']);
ok($abc eq 'abc', "random_string()");

# 4: Make sure the function didn't pollute $foo
ok(!defined($foo->{'0'}), "pollute object");

# Try the object method...
$foo->{'x'}=['a'];
$foo->{'y'}=['b'];
$foo->{'z'}=['c'];

# 5: passing a scalar, in a scalar context
$abc=$foo->randpattern("xyz");
ok($abc eq 'abc', "randpattern()");

# 6: Make sure the from_pattern() interface still works
$abc=$foo->from_pattern("xyz");
ok($abc eq 'abc', "from_pattern()");

# 7: passing an array, in a scalar context
@foo=qw(x y z);
$abc=$foo->randpattern(@foo);
ok($abc eq 'abc', "randpattern() (scalar)");

# 8: passing an array, in an array context
@bar=$foo->randpattern(@foo);
$failed8=0;
for ($n=0;$n<@foo;$n++) {
    if ($bar[$n] ne $foo->{$foo[$n]}->[0]) {
	$failed8=1;
	$failed++;
	last;
    }
}
ok(!$failed8, "randpattern() (list)");

# 9: Check one of the built-in patterns to make
# sure it contains what we think it should
@upcase=("A".."Z");
$failed9=0;
for ($n=0;$n<26;$n++) {
    if (!defined($foo->{'C'}->[$n]) || ($upcase[$n] ne $foo->{'C'}->[$n])) {
	$failed9=1;
	$failed++;
	last;
    }
}
ok(!$failed9, "patterns");

# 10: Test modifying one of the built-in patterns
$foo->{'C'}=['n'];
ok($foo->randpattern("C") eq "n", "modify patterns");

# 11: Make sure we haven't clobbered anything in an existing object
ok($bar->randpattern("C") ne "n", "pollute pattern");

# 12: Make sure we haven't clobbered anything in a new object
$baz=new String::Random;
ok(defined($baz) && ($baz->randpattern("C") ne "n"), "pollute new object");

# 13: Test regex support
@patterns=('\d\d\d', '\w\w\w', '[ABC][abc]', '[012][345]', '...', '[a-z][0-9]',
           '[aw-zX][123]', '[a-z]{5}', '0{80}', '[a-f][nprt]\d{3}',
           '\t\n\r\f\a\e', '\S\S\S', '\s\s\s', '\w{5,10}', '\w?', '\w+', '\w*');
$failed13=0;
for (@patterns) {
    my $ret=$foo->randregex($_);
    if ($ret !~ /^$_$/) {
	$failed13++;
	print "'$_' failed, '$ret' does not match.\n" if ($ENV{VERBOSE});
    }
}
ok(!$failed13, "randregex()");

# 14: Test function interface to randregex()
ok(String::Random::random_regex("[a][b][c]") eq "abc", "random_regex()");

# 15: Test regex support, but this time pass an array.
my @ret=$foo->randregex(@patterns);
$failed15=0;
for ($n=0;$n<@patterns;$n++) {
    if ($ret[$n] !~ /^$patterns[$n]$/) {
	$failed15++;
	print "'$patterns[$n]' failed, '$ret[$n]' does not match.\n"
	    if ($ENV{VERBOSE});
    }
}
ok(!$failed15, "randregex() (list)");

# 16: Test random_regex, this time passing an array.
@ret=String::Random::random_regex(@patterns);
$failed16=0;
for ($n=0;$n<@patterns;$n++) {
    if ($ret[$n] !~ /^$patterns[$n]$/) {
	$failed16++;
	print "'$patterns[$n]' failed, '$ret[$n]' does not match.\n"
	    if ($ENV{VERBOSE});
    }
}
ok(!$failed16, "random_regex() (list)");
