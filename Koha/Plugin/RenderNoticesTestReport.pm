package Koha::Plugin::RenderNoticesTestReport;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use Koha::Plugin::RenderNoticesTestReport::TestMessages qw(TestMessages);

our $VERSION = "0.1.0";
our $MINIMUM_VERSION = "24";

our $metadata = {
    name            => 'RenderNoticesTestReport',
    author          => 'Robin Jonsson',
    date_authored   => '2025-07-10',
    date_updated    => '2025-07-10',
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'A Koha report plugin for viewing rendered messages.',
    namespace       => 'rendernoticestestreport',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## The existance of a 'report' subroutine means the plugin is capable
## of running a report. This example report can output a list of patrons
## either as HTML or as a CSV file. Technically, you could put all your code
## in the report method, but that would be a really poor way to write code
## for all but the simplest reports
sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $template = $self->get_template({ file => 'test-messages.tt' });

    $template->param(
        code_results => TestMessages()
        );

    $self->output_html( $template->output() );
}

1;
