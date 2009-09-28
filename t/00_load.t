
use strict;
use warnings;

use Test::More tests => 6;

use_ok('KiokuDB');
use_ok('Cache::Memcached');
use_ok('Test::More');
use_ok('Test::MockObject');
use_ok('IO::Socket::INET');
use_ok('MooseX::AttributeHelpers');

