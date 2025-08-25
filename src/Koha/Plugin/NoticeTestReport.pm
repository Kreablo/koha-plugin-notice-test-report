package Koha::Plugin::NoticeTestReport;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use Koha::Plugin::NoticeTestReport::TestNotices qw(TestNotices);
use Koha::Plugin::NoticeTestReport::LetterCodes qw(letter_codes);

our $VERSION = "0.3.0";
our $MINIMUM_VERSION = "24";

our $metadata = {
    name            => 'NoticeTestReport',
    author          => 'Robin Jonsson',
    date_authored   => '2025-07-10',
    date_updated    => '2025-08-25',
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
    my $selected_code = $cgi->param('code');
    my $selected_categorycode = $cgi->param('categorycode');
    my $branch_results = TestNotices($selected_code, { categorycode => $selected_categorycode });

    my $template = $self->get_template({ file => 'test-notices.tt' });
    my $sms_send_driver = C4::Context->preference('SMSSendDriver') =~ s/\s//gr;

    $template->param(
        class => scalar $cgi->param('class'),
        method => scalar $cgi->param('method'),
        branch_results => $branch_results,
        selected_code => $selected_code,
        letter_codes => \@Koha::Plugin::NoticeTestReport::LetterCodes::letter_codes,
        sms_send_driver => $sms_send_driver,
        selected_categorycode => $selected_categorycode,
    );
    $self->output_html( $template->output() );
}

1;
