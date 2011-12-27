package Net::API::Gett::File;

=head1 NAME

Net::API::Gett::File - Gett file object

=cut

use Moo;
use Sub::Quote;
use Carp qw(croak);
use MooX::Types::MooseLike qw(Int Str);

our $VERSION = '0.02';

=head1 PURPOSE

Encapsulate Gett files.  You normally shouldn't instantiate this class on 
its own, as the library will create and return this object as appropriate.

=head1 ATTRIBUTES

These are read only attributes. 

=over 

=item filename

Scalar string

=item fileid

Scalar integer

=item downloads

Scalar integer. The number of times this particular file has been downloaded

=item readystate

Scalar string. Signifies the state a particular file is in. See the 
L<Gett developer docs|http://ge.tt/developers> for more information.

=item url

Scalar string. The URL to use in a browser to access a file.

=item download

Scalar string. The URL to use to get the file contents.

=item size

Scalar integer. The size in bytes of this file.

=item created

Scalar integer. The Unix epoch time when this file was created in Gett. This value is suitable
for use in C<localtime()>.

=item sharename

Scalar string.  The share in which this file lives inside.

=item put_upload_url

Scalar string.  The url to use to upload the contents of this file using the PUT method. (This
attribute is only populated during certain times.)

=item post_upload_url

Scalar string. This url to use to upload the contents of this file using the POST method. (This
attribute is only populated during certain times.)

=back

=cut

has 'filename' => (
    is => 'ro',
    isa => 'Str',
);

has 'fileid' => (
    is => 'ro',
    isa => 'Int',
);

has 'downloads' => (
    is => 'ro',
    isa => 'Int',
);

has 'readystate' => (
    is => 'ro',
    isa => 'Str',
);

has 'url' => (
    is => 'ro',
    isa => 'Str',
);

has 'download' => (
    is => 'ro',
    isa => 'Str',
);

has 'size' => (
    is => 'ro',
    isa => 'Int',
);

has 'created' => (
    is => 'ro',
    isa => 'Int',
);

has 'sharename' => (
    is => 'ro',
    isa => 'Str',
);

has 'put_upload_url' => (
    is => 'ro',
    isa => 'Str',
);

has 'post_upload_url' => (
    is => 'ro',
    isa => 'Str',
);

=over

=item user

L<Net::API::Gett::User> object. C<has_user()> predicate.

=back

=cut

has 'user' => (
    is => 'rw',
    predicate => 'has_user',
    isa => sub { die "$_[0] is not Net::API::Gett::User" unless ref($_[0]) =~ /User/ },
    lazy => 1,
);

=over

=item request

L<Net::API::Gett::Request> object.

=back

=cut

has 'request' => (
    is => 'rw',
    isa => sub { die "$_[0] is not Net::API::Gett::Request" unless ref($_[0]) =~ /Request/ },
    default => sub { Net::API::Gett::Request->new() },
    lazy => 1,
);

=over

=item send_file()

This method actually uploads the file to the Gett service. This method is normally invoked by the
C<upload_file()> method, but it's a public method which might be useful in combination with 
C<get_upload_url()>. It takes the following parameters:

=over

=item * 

a PUT based Gett upload url

=item * 

a scalar representing the file contents which can be one of: a buffer, an L<IO::Handle> object, a FILEGLOB, or a 
file pathname.

=item *

an encoding scheme. By default, it uses C<:raw> (see C<perldoc -f binmode> for more information.)

=back

Returns a true value on success.

=back

=cut

sub send_file {
    my $self = shift;
    my $url = shift;
    my $contents = shift;
    my $encoding = shift || ":raw";

    my $data = read_file($contents, { binmode => $encoding });

    return 0 unless $data;

    my $response = $self->request->put($url, Content => $data);

    if ( $response ) {
        return 1;
    }
    else {
        return undef;
    }
}

=over

=item get_upload_url()

This method returns a scalar PUT upload URL for the specified sharename/fileid parameters. 
Potentially useful in combination with C<send_file()>.

=back

=cut

sub get_upload_url {
    my $self = shift;
    croak "Cannot get_upload_url() without a Net::API::Gett::User object." unless $self->has_user;

    my $sharename = $self->sharename;
    my $fileid = $self->fileid;

    $self->user->login unless $self->user->has_access_token;

    my $endpoint = "/files/$sharename/$fileid/upload?accesstoken=".$self->user->access_token;

    my $response = $self->request->get($endpoint);

    if ( $response && exists $response->{'puturl'} ) {
        return $response->{'puturl'};
    }
    else {
        croak "Could not get a PUT url from $endpoint";
    }
}

=over

=item destroy_file()

This method destroys a file specified by the given sharename/fileid parameters. Returns a true value.

=back

=cut

sub destroy {
    my $self = shift;
    croak "Cannot destroy() without a Net::API::Gett::User object." unless $self->has_user;

    my $sharename = $self->sharename;
    my $fileid = $self->fileid;

    $self->user->login unless $self->user->has_access_token;

    my $endpoint = "/files/$sharename/$fileid/destroy?accesstoken=".$self->access_token;

    my $response = $self->request->post($endpoint);

    if ( $response ) {
        return 1;
    }
    else {
        return undef;
    }
}
        
sub _file_contents {
    my $self = shift;
    my $endpoint = shift;

    my $response = $self->request->ua(GET $endpoint);

    if ( $response->is_success ) {
        return $response->content();
    }
    else {
        croak "$endpoint said " . $response->status_line;
    }
}

=over

=item contents()

This method retrieves the contents of a this file in the Gett service.  You are responsible for 
outputting the file (if desired) with any appropriate encoding.

=back

=cut

sub contents {
    my $self = shift;
    my $sharename = $self->sharename;
    my $fileid = $self->fileid;

    return $self->_file_contents("/files/$sharename/$fileid/blob");
}

=over

=item thumbnail()

This method returns a thumbnail if the file in Gett is an image. Requires a
sharename and fileid.

=back

=cut

sub thumbnail {
    my $self = shift;
    my $sharename = $self->sharename;
    my $fileid = $self->fileid;

    return $self->_file_contents("/files/$sharename/$fileid/blob/thumb");
}

=head1 SEE ALSO

L<Net::API::Gett>

=cut

1;
