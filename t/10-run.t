#!/usr/bin/env perl

use strict;
use warnings;

use Capture::Tiny;
use Test::Exception;
use Test::Git;
use Test::More;

use App::GitHooks::Test qw( ok_add_files ok_setup_repository );


## no critic (RegularExpressions::RequireExtendedFormatting)

# List of tests to perform.
my $tests =
[
    # Make sure the plugin correctly analyzes Ruby files.
    {
        name     => 'Fail compilation check.',
        files    =>
        {
            'test.rb' => "invalid_command 'Hello world\n",
        },
        expected => qr/x The file passes ruby -c/,
    },
    {
        name     => 'Pass compilation check.',
        files    =>
        {
            'test.rb' => "puts 'Hello world'\n",
        },
        expected => qr/o The file passes ruby -c/,
    },
    # Make sure the correct file times are analyzed.
    {
        name     => 'Skip non-Ruby files',
        files    =>
        {
            'test.txt' => 'A text file.',
        },
        expected => qr/^(?!.*\QThe file passes ruby -c\E)/,
    },
];

# Bail out if Git isn't available.
has_git();
plan( tests => scalar( @$tests ) );

foreach my $test ( @$tests )
{
    subtest(
        $test->{'name'},
        sub
        {
            plan( tests => 4 );

            my $repository = ok_setup_repository(
                cleanup_test_repository => 1,
                config                  => $test->{'config'},
                hooks                   => [ 'pre-commit' ],
                plugins                 => [ 'App::GitHooks::Plugin::RubyCompile' ],
            );

            # Set up test files.
            ok_add_files(
                files      => $test->{'files'},
                repository => $repository,
            );

            # Try to commit.
            my $stderr;
            lives_ok(
                sub
                {
                    $stderr = Capture::Tiny::capture_stderr(
                        sub
                        {
                            $repository->run( 'commit', '-m', 'Test message.' );
                        }
                    );
                    note( $stderr );
                },
                'Commit the changes.',
            );

            like(
                $stderr,
                $test->{'expected'},
                "The output matches expected results.",
            );
        }
    );
}
