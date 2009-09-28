
use inc::Module::Install;

name     'KiokuDB-Backend-Memcached';
license  'perl';
version  '0.01';
abstract_from 'lib/KiokuDB/Backend/Memcached.pm';

requires      'Moose'            => '0';
requires      'KiokuDB'          => '0.24';
requires      'Cache::Memcached' => '0';
test_requires 'Test::More'       => '0.94';
test_requires 'Test::MockObject' => '1.09';
test_requires 'MooseX::AttributeHelpers' => '0.22';

WriteAll;

