
use strict;
use warnings;

use Test::More;
use Cache::Memcached;
use IO::Socket::INET;

my $serverport = 'localhost:11211';
my $msock = IO::Socket::INET->new(
    PeerAddr => $serverport,
    Timeout  => 3,
);
if (!$msock) {
    plan skip_all => "No memcached instance running at $serverport\n";
    exit 0;
} else {
    plan tests => 22;
}

sub _make_key {
    my $key = shift;
    return sprintf(
        'KiokuDB::Backend::Memcached:Test::%d:%s', $$, $key);
}

{ note('memcached basics'); 
    my $memd = Cache::Memcached->new({servers => [$serverport]});
    ok($memd, 'memcached instance');
    isa_ok($memd, 'Cache::Memcached');

    my $key1 = _make_key('key1');
    ok(!$memd->get($key1), 'key1 empty');
    $memd->set($key1, 'val1');
    ok($memd->get($key1), 'after set, key1 not empty');
    $memd->delete($key1);
    ok(!$memd->get($key1), 'after delete, key1 empty');
}

my ($db);
{ note('Backend::Memcached on memcached');

    use_ok('KiokuDB');
    use_ok('KiokuDB::Backend::Memcached');
    use_ok('KiokuDB::TypeMap::Entry::Naive');

    my $backend = KiokuDB::Backend::Memcached->new(
        servers => [$serverport],
    );
    isa_ok($backend, 'KiokuDB::Backend::Memcached');
    my $cache = $backend->memcached;
    isa_ok($cache, 'Cache::Memcached');

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

# TODO: tests below is copied from t/10_basic_mock.t.
# these lines must be structured and shared.
{
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
{ note('setup and store objects');
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
    ok($db->exists($uuid), 'key exists');
    
    $db->live_objects->clear();
    ok($db->exists($uuid), 'key exists after live_object cleared');
}
{ note('restore object');
    my $scope = $db->new_scope;
    my $notelist = $db->lookup($uuid);
    isa_ok($notelist, 'NoteList');
    my $notes = $notelist->notes;
    is(ref($notes), 'ARRAY', '(retored) notes is an arrayref');
    is(scalar(@$notes), 3, '(restore) push 3, and contains 3');

    $db->delete($uuid);
    $db->live_objects->clear();
    ok(!$db->lookup($uuid), 'key deleted');
}



