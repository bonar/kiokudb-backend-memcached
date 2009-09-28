
use strict;
use warnings;

use Test::More tests => 22;

use_ok('Test::MockObject');
use_ok('KiokuDB');
use_ok('KiokuDB::TypeMap::Entry::Naive');

{ # create memcached mock object for tests without server
    my $mock = Test::MockObject->new();
    our (%mock_attr);
    $mock->mock('mocked', sub { 1 });
    $mock->mock('set', sub { $mock_attr{$_[1]} = $_[2]; });
    $mock->mock('get', sub {
        return unless defined $mock_attr{$_[1]};
        return $mock_attr{$_[1]}; });
    $mock->mock('delete', sub { delete $mock_attr{$_[1]}; });
    $mock->set_isa('Cache::Memcached');
    $mock->fake_new('Cache::Memcached');

    my $cache = Cache::Memcached->new();
    isa_ok($cache, 'Cache::Memcached');
    is($cache->mocked, 1, 'mocked flag');
    $cache->set('foo', 'bar');
    is($cache->get('foo'), 'bar', 'mock: set and get');
    $cache->delete('foo');
    ok(!$cache->get('foo'), 'mock: delete');
}

my ($db);
{ # backend object and db object
    use_ok('KiokuDB::Backend::Memcached');
    my $backend = KiokuDB::Backend::Memcached->new(
        servers => ["10.0.0.17:11211"],
        debug   => 0,
        compress_threshold => 10_000,
    );
    ok($backend, 'backend: response');
    isa_ok($backend, 'KiokuDB::Backend::Memcached');
    
    my $cache = $backend->memcached;
    isa_ok($cache, 'Cache::Memcached');

    # type constraints
    undef $@; eval { $backend->memcached({}); };
    ok($@, 'invalid: plain hashref');
    undef $@; eval { $backend->memcached($backend); };
    ok($@, 'invalid: not Cache::Memcached');

    $db = KiokuDB->new(
        backend => $backend,
        typemap => KiokuDB::TypeMap->new(
            entries => {
                ARRAY => KiokuDB::TypeMap::Entry::Naive->new(),
        }),
    );
    ok($db, 'KiokuDB instance');
    isa_ok($db, 'KiokuDB');
}

# practical tests:
#   1. create NoteList object
#   2. create Note objects and push them to the NoteList object
#   3. store NoteList object
#   4. check result (data in mocked memcached object)
{ # NoteList is a Collection of Notes
    package NoteList;
    use Moose;
    use MooseX::AttributeHelpers;
    has 'notes' => (
        metaclass => 'Collection::Array',
        is        => 'rw',
        isa       => 'ArrayRef[Note]',
        required  => 1,
        default   => sub { [] },
        provides  => {
            push  => 'push',
            clear => 'clear',
        },
    );
    __PACKAGE__->meta->make_immutable;
}
{
    package Note;
    use Moose;

    has name => (is => 'rw', isa => 'Str');
    has body => (is => 'rw', isa => 'Str');

    __PACKAGE__->meta->make_immutable;
}

my ($uuid);
{
    # setup and store objects
    my $notelist = NoteList->new();
    isa_ok($notelist, 'NoteList');

    $notelist->push(
        Note->new(name => 'note A', body => 'foo'),
        Note->new(name => 'note B', body => 'bar'),
        Note->new(name => 'note C', body => 'buzz'),
    );
    my $notes = $notelist->notes;
    is(ref($notes), 'ARRAY', 'notes is an arrayref');
    is(scalar(@$notes), 3, 'push 3, and contains 3');

    my $scope = $db->new_scope;
    $uuid = $db->store($notelist);
    ok($uuid, "uuid:returned [$uuid]");

}

{
    # restore object
    my $scope = $db->new_scope;
    my $notelist = $db->lookup($uuid);
    isa_ok($notelist, 'NoteList');
    my $notes = $notelist->notes;
    is(ref($notes), 'ARRAY', '(retored) notes is an arrayref');
    is(scalar(@$notes), 3, '(restore) push 3, and contains 3');
}




