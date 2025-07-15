package Koha::Plugin::NoticeTestReport;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use Koha::Plugin::NoticeTestReport::TestNotices qw(TestNotices);

our $VERSION = "0.1.0";
our $MINIMUM_VERSION = "24";

our $metadata = {
    name            => 'NoticeTestReport',
    author          => 'Robin Jonsson',
    date_authored   => '2025-07-10',
    date_updated    => '2025-07-15',
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'A Koha report plugin for previewing notices.',
    namespace       => 'noticetestreport',
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}

sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'test-notices.tt' });

    $template->param(
        code_results => TestNotices()
        );

    $self->output_html( $template->output() );
}

1;
