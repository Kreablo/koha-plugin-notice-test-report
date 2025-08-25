#!/bin/perl -w

use Modern::Perl;
use C4::Context;
use C4::Letters qw(GetPreparedLetter);

use Koha::Plugin::NoticeTestReport::LetterCodes qw(letter_queries);
use Koha::Patrons;
use Koha::Notice::Templates;

binmode(STDOUT, ':encoding(UTF-8)');

sub parse_letter {
    my $letter_branchcode = shift;
    my $params = shift;

    foreach my $required ( qw( letter_code borrowernumber ) ) {
        return unless exists $params->{$required};
    }

    my %table_params = ( 'borrowers' => $params->{'borrowernumber'} );

    if ( my $p = $params->{'branchcode'} ) {
        $table_params{'branches'} = $p;
    }
    if ( my $p = $params->{'itemnumber'} ) {
        $table_params{'issues'} = $p;
        $table_params{'items'} = $p;
    }
    if ( my $p = $params->{'biblionumber'} ) {
        $table_params{'biblio'} = $p;
        $table_params{'biblioitems'} = $p;
    }
    if ( my $p = $params->{'hold'}) {
        $table_params{'reserves'} = $p;
    }

    my $module = 'circulation';
    my $letter_code = $params->{'letter_code'};
    my $branchcode = $letter_branchcode;
    my $mtt = $params->{'message_transport_type'};
    my $lang = $params->{'lang'};

    my $unprepared_letter = Koha::Notice::Templates->find_effective_template(
        {
            module                 => $module,
            code                   => $letter_code,
            branchcode             => $branchcode,
            message_transport_type => $mtt,
            lang                   => $lang
        }
    );
    my $prepared_letter = C4::Letters::GetPreparedLetter (
        module => $module,
        letter_code => $letter_code,
        branchcode => $branchcode,
        lang => $lang,
        substitute => $params->{'substitute'},
        tables     => \%table_params,
        ( $params->{itemnumbers} ? ( loops => { items => $params->{itemnumbers} } ) : () ),
        message_transport_type => $mtt,
    );
    return { unprepared => $unprepared_letter, prepared => $prepared_letter };
}

sub TestNotice {
    my $letter_branchcode = shift;
    my $params = shift;

    my $parse;

    my $warning;
    local $SIG{__WARN__} = sub{ $warning = $_[0]; };

    eval {
        $parse = parse_letter($letter_branchcode, $params);
    };

    my $letter = $parse->{'prepared'};

    my $res = {
        'lang' => $params->{'lang'},
        'message_transport_type' => $params->{'message_transport_type'},
        'warning' => $warning
    };

    if ($@) {
        $res->{error} = "ERROR: $@\n";
    } elsif ($letter) {
        $res->{ok} = $letter;
        $res->{template} = $parse->{'unprepared'};
        $res->{parsed_branchcode} = $res->{template}->get_column('branchcode');
        $res->{wrapped} = C4::Letters::_wrap_html(
            $letter->{'content'},
            'Preview for ' . $res->{'message_transport_type'} . ' ' . $res->{'lang'}
        );
    }

    return $res;
}

sub _TestNotices {
    my $letter_branchcode = shift;
    my $letter_code = shift;
    my $params = shift;

    my $queryfun = $Koha::Plugin::NoticeTestReport::LetterCodes::letter_queries{$letter_code};
    unless ($queryfun) {
        return;
    }
    my $codequery = $queryfun->($params);

    if (exists $codequery->{error}) {
        return $codequery;
    }

    my %code_results = ();

    my $href = $codequery->{href};
    my $rest_params = $codequery->{params};

    if ( ! defined $href ) {
        $code_results{error} = 'Cannot prepare letter with code ' . $letter_code;
        return \%code_results;
    }

    my @transport_types = ( 'email', 'print', 'sms' );

    my @languages = ('default', (split ",", C4::Context->preference('StaffInterfaceLanguages')));

    my $lang_result = [];
    foreach my $lang (@languages) {
        my $transport_results = [];

        foreach my $message_transport_type (@transport_types) {
            my $params = {
                'borrowernumber'         => $href->{borrowernumber},
                'branchcode'             => $href->{branchcode},
                'itemnumber'             => $href->{itemnumber},
                'biblionumber'           => $href->{biblionumber},
                'message_transport_type' => $message_transport_type,
                'letter_code'            => $letter_code,
                'lang'                   => $lang,
                %$rest_params,
            };

            my $result = TestNotice($letter_branchcode, $params);
            my $fallback = $letter_branchcode && !($result->{parsed_branchcode} eq $letter_branchcode);
            if ($fallback) {
                my $msg = "$letter_branchcode $letter_code $message_transport_type '$lang' is a fallback message but there are some other messages defined for this branch.";
                $result->{warning} = (defined $result->{warning}) ? $result->warning . "<br>$msg" : $msg;
            }

            push @{$transport_results}, {
                transport => $message_transport_type,
                result => $result,
                fallback => $fallback
            };
        }
        push @{$lang_result}, { lang => $lang, result => $transport_results};
    }
    $code_results{ok} = { letter_code => $letter_code, result => $lang_result };
    return \%code_results;
}

sub TestNotices {
    my $letter_code = shift;
    my $rest = @_;

    my $_branch_q = Koha::Notice::Templates->search(
        {
            code => $letter_code
        },
        {
            distinct => 1
        }
    );
    my @branchcodes = $_branch_q->get_column('branchcode');

    my $results = [];

    foreach my $branch (@branchcodes) {
        push @{$results}, { branch => $branch, result => _TestNotices($branch, $letter_code, $rest) };
    }

    return $results;
}
