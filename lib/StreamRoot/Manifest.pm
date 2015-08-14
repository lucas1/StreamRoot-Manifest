package StreamRoot::Manifest;

use strict;
use warnings;
use WWW::Curl::Easy;
use JSON;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = {};
    $self->{token} = shift||undef;
    $self->{curl} = WWW::Curl::Easy->new;
    $self->{curl}->setopt(CURLOPT_TIMEOUT, 180);
    $self->{curl}->setopt(CURLOPT_HEADER, 0);
    $self->{curl}->setopt(CURLOPT_USERAGENT, 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)');
    $self->{curl}->setopt(CURLOPT_AUTOREFERER, 1);
    $self->{curl}->setopt(CURLOPT_FOLLOWLOCATION, 1);
    $self->{curl}->setopt(CURLOPT_SSL_VERIFYPEER, 0);
    $self->{curl}->setopt(CURLOPT_VERBOSE, 0);
    return bless $self, $class;
}

sub curl {
    my ( $self, $url, $data, $referer ) = @_;
    my $params = "";
    if ($data) {
        if (ref($data) eq 'HASH') {
            for(keys %$data){
                $params .= "&" if $params;
                $params .= "$_=$data->{$_}";
            }
        }else{
            $params = "$data";
        }
    }
    $self->{curl}->setopt(CURLOPT_POSTFIELDS, $params);
    $self->{curl}->setopt(CURLOPT_URL, $url);
    my $content = "";
    open(my $writedata, ">", \$content);
    $self->{curl}->setopt(CURLOPT_WRITEDATA, $writedata);
    if ($self->{curl}->perform == 0) {
        if ($self->{curl}->getinfo(CURLINFO_HTTP_CODE) =~ /^2/) {
            decode_json($content) if $content !~ /^$/;
        }else{
            die($content);
        }
    }
}

sub setToken {
    my $self = shift;
    $self->{token} = shift||undef;
}

sub getToken {
    my $self = shift;
    return $self->{token};
}

sub authenticate {
    my ( $self, $username, $password ) = @_;
    my $data = {
        'username' => $username,
        'password' => $password
    };
    $self->{curl}->setopt(CURLOPT_CUSTOMREQUEST, 'POST');
    my $content = $self->curl('https://api.streamroot.io/v0/auth/login', $data);
    $self->setToken($content->{token});
    return $content->{token};
}

sub addManifest {
    my $self = shift;
    my %params = @_;
    my $data = {};
    $data->{url} = $params{url};
    $data->{status} = $params{status} if $params{status};
    $data->{ttl} = $params{ttl} if $params{ttl};
    $self->{curl}->setopt(CURLOPT_CUSTOMREQUEST, 'POST');
    $self->{curl}->setopt(CURLOPT_HTTPHEADER(), ['Authorization:Bearer '.$self->getToken]);
    my $content = $self->curl('https://manifests.streamroot.io', $data);
    return $content;
}

sub updateManifest {
    my $self = shift;
    my %params = @_;
    my $data = {};
    $data->{status} = $params{status} if $params{status};
    $data->{live} = $params{live} if $params{live};
    $self->{curl}->setopt(CURLOPT_CUSTOMREQUEST, 'PUT');
    $self->{curl}->setopt(CURLOPT_HTTPHEADER(), ['Authorization:Bearer '.$self->getToken]);
    my $content = $self->curl('https://manifests.streamroot.io/' . $params{id}, $data);
    return $content;
}

sub removeManifest {
    my ( $self, $id ) = @_;
    $self->{curl}->setopt(CURLOPT_CUSTOMREQUEST, 'DELETE');
    $self->{curl}->setopt(CURLOPT_HTTPHEADER(), ['Authorization:Bearer '.$self->getToken]);
    my $content = $self->curl('https://manifests.streamroot.io/' . $id);
    return $content;
}

sub showManifest {
    my ( $self, $id ) = @_;
    $self->{curl}->setopt(CURLOPT_CUSTOMREQUEST, 'GET');
    $self->{curl}->setopt(CURLOPT_HTTPHEADER(), ['Authorization:Bearer '.$self->getToken]);
    my $content = $self->curl('https://manifests.streamroot.io/' . $id);
    return $content;
}

sub showAllManifests {
    my ( $self, $pattern ) = @_;
    my $data = {};
    $data->{pattern} = $pattern if $pattern;
    $self->{curl}->setopt(CURLOPT_CUSTOMREQUEST, 'GET');
    $self->{curl}->setopt(CURLOPT_HTTPHEADER(), ['Authorization:Bearer '.$self->getToken]);
    my $content = $self->curl('https://manifests.streamroot.io', $data);
    return $content;
}

1;

__END__

=encoding utf8

=head1 NAME

StreamRoot::Manifest - StreamRoot Manifest API

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

    use StreamRoot::Manifest;
    
    my $manifest = StreamRoot::Manifest->new;
    
    # To get your Auth token, you need to autheticate with your account credentials
    $manifest->authenticate($username, $password);
    
    # Add a new manifest to your account
    my $result = $manifest->AddManifest(
        url => 'http://foo.com/file.mpd', # need to be a valid url pointing to a valid manifest
        ttl => 5 # time to live before becoming inactive, in days
    );
    
=head1 DESCRIPTION

StreamRoot Manifest API documentation with full description of API methods L<https://streamroot.readme.io/docs/api-overview>.

=head2 C<new>

    my $manifest = StreamRoot::Manifest->new;
    
or

    my $manifest = StreamRoot::Manifest->new($token);

The token param is optional, but it is better to avoid to do authentication calls before each request, 
and keep the auth token in memory instead.

=head2 C<getToken>

    $manifest->getToken;
    
Gets the authentication token.

=head2 C<setToken>

    $manifest->setToken($token);

Sets the auth token, to avoid reauthentications on each request (if you already have a valid token, you can set it with this method)

=head2 C<authentication>

    $manifest->authenticate($username, $password);
    
To get your token, you need to do first execute the authenticate method. This method sets the token property, and returns the token.
The username and password are the same you use to sign in to the streamroot portal website.

=head2 C<addManifest>

    $manifest->addManifest(
        url => 'http://foo.com/file.mpd',
        status => 'active',
        ttl => 5 
    );
    
This method creates a new manifest in StreamRoot database.
Returns perl hash with StreamRoot response.

=head4 Parameters

B<url> - This parameter is required, valid url pointing to a valid manifest.

B<status> - This parameter is optional, current status of the manifest file, defaults to active
    
B<ttl> - This parameter is optional, time to live in days before becoming inactive, defaults to 5 days

=head2 C<updateManifest>

    $manifest->updateManifest(
        id => $manifest_id,
        status => 'inactive',
        live => 'true' 
    );
    
This method updates a manifest, returns perl hash with StreamRoot response.

=head4 Parameters

B<id> - This parameter is required, manifest id will be changed.

B<status> - This parameter is optional, should be 'active' or 'inactive'.

B<live> - This parameter is optional, should be 'true' or 'false'.

=head2 C<removeManifest>

    $manifest->removeManifest($manifest_id);
    
This method deletes the manifest with the given manifest id from the streamroot database, the id parameter is required. 
Returns perl hash with StreamRoot response.

=head2 C<showingAManifest>

    $manifest->showManifest($manifest_id);
    
This method returns information on a manifest in StreamRoot, the id parameter is required.
Returns perl hash with StreamRoot response.

=head2 C<showAllManifests>

    $manifest->showAllManifests($pattern);
    
This method returns information of all your manifests in StreamRoot, with an optional pattern to match the manifests url (Minimum of 10 characters to match and search on the manifest's URL). 
Returns perl arrayref with StreamRoot response.

=head1 SEE ALSO

L<https://streamroot.readme.io>

=head1 AUTHOR

Lucas Tiago de Moraes, C<< <lucastiagodemoraes@gmail.com> >>

=head1 CREDITS

Nikolay Rodionov, C<< <nikolay@streamroot.io> >>

Team StreamRoot, C<< <contact@streamroot.io> >>

=head1 LICENSE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it under the terms of the the Artistic License (2.0).

You may obtain a copy of the full license at: L<http://www.perlfoundation.org/artistic_license_2_0>

=cut