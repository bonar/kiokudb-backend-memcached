
package KiokuDB::Backend::Memcached;
use Moose;

use Cache::Memcached;
use namespace::clean -except => 'meta';

our $VERSION = '0.01';

with qw/
    KiokuDB::Backend
    KiokuDB::Backend::Serialize::Delegate
/;

has memcached => (
    is       => 'rw',
    isa      => 'Cache::Memcached',
    required => 1,
);

sub BUILDARGS {
    my ($self, %arg) = @_;
    my $cache = Cache::Memcached->new(\%arg);
    return {
        memcached  => $cache,
        serializer => $arg{serializer} || 'storable',
    };
}

sub get {
    my ($self, @ids) = @_;
    return map { $self->serializer->deserialize(
        $self->memcached->get($_)) } @ids;
}

sub insert {
    my ($self, @entries) = @_;
    foreach my $entry (@entries) {
        my $key = $entry->id;
        my $val = $self->serializer->serialize($entry);
        $self->memcached->set($key, $val);
    }
    return;
}

sub delete {
    my ($self, @ids_or_entries) = @_;
    my @uids = map { ref($_) ? $_->id : $_ } @ids_or_entries;
    foreach my $uid (@uids) {
        $self->memcached->delete($uid)
    }
    return;
}

sub exists {
    my ($self, @uids) = @_;
    return map { $self->memcached->get($_) } @uids;
}

__PACKAGE__->meta->make_immutable;
__PACKAGE__;

__END__

=head1 NAME

KiokuDB::Backend::Memcached - memcached backend

=head1 SYNOPSIS

    my $backend = KiokuDB::Backend::Memcached->new(
        servers => ["localhost:11211"],
        debug   => 0,
        compress_threshold => 10_000,
    );
    $db = KiokuDB->new(backend => $backend);

=head1 DESCRIPTION

This backend provides memcached based backend using L<Cache::Memcached>.
Note that this backend does NOT support transaction for now.

and this module is alpha version. don't use this module 
in production softwares.

=head1 Constructor options

you can specify same options as Cache::Memcached constructor to
KiokuDB::Backend::Memcached#new. such as servers, debug. see whole 
options at L<Cache::Memcached>.

you can also specify serializer.

    my $backend = KiokuDB::Backend::Memcached->new(
        servers    => ["localhost:11211"],
        serializer => "yaml",
    );

"storable" is the default.

=head1 VERSION CONTROL

L<http://github.com/bonar/kiokudb-backend-memcached>

=head1 AUTHOR

nakano kyohei (bonar), bonar at cpan.org

=cut

