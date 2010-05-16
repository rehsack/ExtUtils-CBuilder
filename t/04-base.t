#! perl -w

use strict;
use Test::More qw(no_plan); # tests => 7;
BEGIN { 
  if ($^O eq 'VMS') {
    # So we can get the return value of system()
    require vmsish;
    import vmsish;
  }
}
use Config;
use Cwd;
use File::Temp qw( tempdir );
use ExtUtils::CBuilder::Base;
#use Data::Dumper;$Data::Dumper::Indent=1;

my ( $base, $phony, $cwd );

$base = ExtUtils::CBuilder::Base->new();
ok( $base, "ExtUtils::CBuilder::Base->new() returned true value" );
isa_ok( $base, 'ExtUtils::CBuilder::Base' );

$phony = 'foobar';
$base = ExtUtils::CBuilder::Base->new(
    config  => { cc => $phony },
);
ok( $base, "ExtUtils::CBuilder::Base->new() returned true value" );
isa_ok( $base, 'ExtUtils::CBuilder::Base' );
is( $base->{config}->{cc}, $phony,
    "Got expected value when 'config' argument passed to new()" );

{
    $phony = 'barbaz';
    local $ENV{CC} = $phony;
    $base = ExtUtils::CBuilder::Base->new();
    ok( $base, "ExtUtils::CBuilder::Base->new() returned true value" );
    isa_ok( $base, 'ExtUtils::CBuilder::Base' );
    is( $base->{config}->{cc}, $phony,
        "Got expected value \$ENV{CC} set" );
}

{
    my $path_to_perl = File::Spec->catfile( '', qw| usr bin perl | );
    local $^X = $path_to_perl;
    is(
        ExtUtils::CBuilder::Base::find_perl_interpreter(),
        $path_to_perl,
        "find_perl_interpreter() returned expected absolute path"
    );
}

{
    my $path_to_perl = 'foobar';
    local $^X = $path_to_perl;
    # %Config is read-only.  We cannot assign to it and we therefore cannot
    # simulate the condition that would occur were its value something other
    # than an existing file.
    if ($Config::Config{perlpath}) {
        is(
            ExtUtils::CBuilder::Base::find_perl_interpreter(),
            $Config::Config{perlpath},
            "find_perl_interpreter() returned expected file"
        );
    }
    else {
        is(
            ExtUtils::CBuilder::Base::find_perl_interpreter(),
            $path_to_perl,
            "find_perl_interpreter() returned expected name"
        );
    }
}

{
    $cwd = cwd();
    my $tdir = tempdir();
    chdir $tdir;
    $base = ExtUtils::CBuilder::Base->new();
    ok( $base, "ExtUtils::CBuilder::Base->new() returned true value" );
    isa_ok( $base, 'ExtUtils::CBuilder::Base' );
    is( scalar keys %{$base->{files_to_clean}}, 0,
        "No files needing cleaning yet" );

    my $file_for_cleaning = File::Spec->catfile( $tdir, 'foobar' );
    open my $IN, '>', $file_for_cleaning
        or die "Unable to open dummy file: $!";
    print $IN "\n";
    close $IN or die "Unable to close dummy file: $!";

    $base->add_to_cleanup( $file_for_cleaning );
    is( scalar keys %{$base->{files_to_clean}}, 1,
        "One file needs cleaning" );

    $base->cleanup();
    ok( ! -f $file_for_cleaning, "File was cleaned up" );

    chdir $cwd;
}

$base = ExtUtils::CBuilder::Base->new();
ok( $base, "ExtUtils::CBuilder::Base->new() returned true value" );
isa_ok( $base, 'ExtUtils::CBuilder::Base' );
eval {
    $base->compile(foo => 'bar');
};
like(
    $@,
    qr/Missing 'source' argument to compile/,
    "Got expected error message when lacking 'source' argument to compile()"
);

$base = ExtUtils::CBuilder::Base->new( quiet => 1 );
ok( $base, "ExtUtils::CBuilder::Base->new() returned true value" );
isa_ok( $base, 'ExtUtils::CBuilder::Base' );

my ($source_file, $object_file, $lib_file);
$source_file = File::Spec->catfile('t', 'compilet.c');
{
  local *FH;
  open FH, "> $source_file" or die "Can't create $source_file: $!";
  print FH "int boot_compilet(void) { return 1; }\n";
  close FH;
}
ok(-e $source_file, "source file '$source_file' created");
$object_file = File::Spec->catfile('t', 'my_special_compilet.o' );
is( $object_file,
    $base->compile(
        source      => $source_file,
        object_file => $object_file,
    ),
    "compile() completed, returned object file with specified name"
);

$lib_file = $base->lib_file($object_file);
ok( $lib_file, "lib_file() returned true value" );

my ($lib, @temps) = $base->link(
    objects     => $object_file,
    module_name => 'compilet',
);
$lib =~ tr/"'//d; #"
is($lib_file, $lib, "Got expected value for $lib");

{
    local $ENV{PERL_CORE} = '';
    my $include_dir = $base->perl_inc();
    ok( $include_dir, "perl_inc() returned true value" );
    ok( -d $include_dir, "perl_inc() returned directory" );
}

for ($source_file, $object_file, $lib_file) {
  tr/"'//d; #"
  1 while unlink;
}

pass("Completed all tests in $0");

if ($^O eq 'VMS') {
   1 while unlink 'COMPILET.LIS';
   1 while unlink 'COMPILET.OPT';
}
