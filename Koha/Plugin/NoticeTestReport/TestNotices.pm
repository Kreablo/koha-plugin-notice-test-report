#!/bin/perl -w

use Modern::Perl;
use C4::Context;
use C4::Letters qw(GetPreparedLetter);

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
                          level => $DEBUG,
                          file => ">>/kohadevbox/plugins/testnotices.log",
                         });
use Koha::Plugin::NoticeTestReport::LetterCodes qw(letter_queries);
use Koha::Patrons;

binmode(STDOUT, ':encoding(UTF-8)');

my $itemscontent = join(',',qw( date_due title author barcode ));

# The fields that will be substituted into <<items.content>>
my @item_content_fields = split(/,/,$itemscontent);

sub parse_letter {
    my $params = shift;

    foreach my $required ( qw( letter_code borrowernumber ) ) {
        return unless exists $params->{$required};
    }

    my %table_params = ( 'borrowers' => $params->{'borrowernumber'} );

    if ( my $p = $params->{'branchcode'} ) {
        $table_params{'branches'} = $p;
        # DEBUG 'BRANCHES ' . $p;
    }
    if ( my $p = $params->{'itemnumber'} ) {
        $table_params{'issues'} = $p;
        $table_params{'items'} = $p;
        # DEBUG 'ITEMNUMBER ' . $p;
    }
    if ( my $p = $params->{'biblionumber'} ) {
        $table_params{'biblio'} = $p;
        $table_params{'biblioitems'} = $p;
        # DEBUG 'BIBLIO ' . $p;
    }

    return C4::Letters::GetPreparedLetter (
                                           module => 'circulation',
                                           letter_code => $params->{'letter_code'},
                                           branchcode => $table_params{'branches'},
                                           lang => $params->{'lang'},
                                           substitute => $params->{'substitute'},
                                           tables     => \%table_params,
                                           ( $params->{itemnumbers} ? ( loops => { items => $params->{itemnumbers} } ) : () ),
                                           message_transport_type => $params->{message_transport_type},
                                          );
}

sub TestNotice {
    my $params = shift;

    my $letter;

    my $warning;
    local $SIG{__WARN__} = sub{ $warning = $_[0]; };

    eval {
        $letter = parse_letter($params);
    };

    my $res = { 'lang' => $params->{'lang'}, 'message_transport_type' => $params->{'message_transport_type'}, 'warning' => $warning };

    if ($@) {
        $res->{error} = "ERROR: $@\n";
    } elsif ($letter) {
        $res->{ok} = $letter;
        $res->{wrapped} = C4::Letters::_wrap_html( $letter->{'content'}, 'Preview for ' . $res->{'message_transport_type'} . ' ' . $res->{'lang'});
    }

    return $res;
}

sub TestNotices {
    my $letter_code = shift;

    my $dbquery = %Koha::Plugin::NoticeTestReport::LetterCodes::letter_queries{$letter_code};
    unless ($dbquery) {
        return;
    }
    my $dbh = C4::Context->dbh;
    my $sth;
    my $href;

    my @itemnumbers = ();
    my $titles = "";

    my @transport_types = ( 'email', 'print', 'sms' );
    my @languages = ( 'default', 'sv-SE', 'en');

    my %code_results = ();

    # keys %letter_codes;
    # while (( my $letter_code, my $dbquery ) = each(%letter_codes)) {

        # DEBUG 'letter code ' . $letter_code;

        if ($letter_code eq 'PREDUEDGST') {
            # select a user with multiple loans
            $sth = $dbh->prepare('SELECT borrowernumber FROM issues GROUP BY borrowernumber HAVING COUNT(*) >= 2 LIMIT 1');
            $sth->execute();

            my $prehref =  $sth->fetchrow_hashref;

            $sth = $dbh->prepare($dbquery);
            $sth->execute($prehref->{'borrowernumber'});

            while ( my $item_info = $sth->fetchrow_hashref ) {
                $href = $item_info;
                $titles .= C4::Letters::get_item_content( { item => $item_info, item_content_fields => \@item_content_fields } );
                # DEBUG 'TITLES ' . $titles;
                push @itemnumbers, $item_info->{'itemnumber'};
            }
        } else {
            $sth = $dbh->prepare($dbquery);
            $sth->execute();
            $href = $sth->fetchrow_hashref;
        }

        if (not $href) {
            $code_results{error} = 'Cannot prepare letter with code ' . $letter_code;
        }

        my $lang_result = [];
        foreach my $lang (@languages) {
            # DEBUG 'language ' . $lang;

            my $transport_results = [];
            foreach my $message_transport_type (@transport_types) {
                # DEBUG 'transport_type ' . $message_transport_type;

                my $params = {
                              'borrowernumber'         => $href->{borrowernumber},
                              'branchcode'             => $href->{branchcode},
                              'itemnumber'             => $href->{itemnumber},
                              'biblionumber'           => $href->{biblionumber},
                              'message_transport_type' => $message_transport_type,
                              'letter_code'            => $letter_code,
                              'lang'                   => $lang,
                              'substitute'             => {
                                                           'count'         => scalar @itemnumbers,
                                                           'items.content' => $titles,
                                                          },
                              'itemnumbers'            => \@itemnumbers,
                             };

                my $result = TestNotice($params);

                push @{$transport_results}, {
                                             transport => $message_transport_type,
                                             result => $result
                                            };
            }
            push @{$lang_result}, { lang => $lang, result => $transport_results};
        }
    $code_results{ok} = { letter_code => $letter_code, result => $lang_result };
    # }
    return \%code_results;
}

