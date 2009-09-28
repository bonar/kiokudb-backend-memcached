
package KiokuDB::Backend::Memcached;
use Moose;

use Carp qw/croak/;
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
    my ($self, $uuid) = @_;
    return $self->serializer->deserialize(
        $self->memcached->get($uuid));
}

sub insert {
    my ($self, @entries) = @_;
    foreach my $entry (@entries) {
        my $key = $entry->id;
        my $val = $self->serializer->serialize($entry);
        $self->memcached->set($key, $val);
    }
}

sub delete {
}

sub exists {

}

__PACKAGE__->meta->make_immutable;
__PACKAGE__;

__END__

=head1 NAME

KiokuDB::Backend::Memcached - memcached backend

=head1 AUTHOR

nakano kyohei (bonar), bonar at cpan.org

=cut

