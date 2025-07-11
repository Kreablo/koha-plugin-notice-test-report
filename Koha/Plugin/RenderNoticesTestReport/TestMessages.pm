#!/bin/perl -w

use Modern::Perl;
use C4::Context;
use C4::Letters qw(GetPreparedLetter);

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init({
                          level => $DEBUG,
                          file => ">>testmessages.log",
                         });

binmode(STDOUT, ':encoding(UTF-8)');

sub TestMessage {
    my ($letter_code, $lang, $transport, $tables) = @_;
    my $letter;

    my $warning;
    local $SIG{__WARN__} = sub{ $warning = $_[0]; };

    eval {
      $letter = C4::Letters::GetPreparedLetter
        (
         module => 'circulation',
         letter_code => $letter_code,
         # branchcode => $reserve->{branchcode},
         lang => $lang,
         message_transport_type => $transport,
         tables => $tables,
        );
    };

    my $res = { lang => $lang, message_transport_type => $transport, warning => $warning };

    if ($@) {
        $res->{error} = "ERROR: $@\n";
    } elsif ($letter) {
        $res->{ok} = $letter;
    }

    return $res;
}

sub TestLettersWithCode {
  my ($letter_code, $tables, $errormsg) = @_;

    my $lang_results = [];

    if ($tables->{href}) {
        for my $lang ('default', 'sv-SE', 'en') {
            my $results = [];
            for my $transport ('email', 'print', 'sms') {
                push @{$results}, TestMessage($letter_code, $lang, $transport, $tables);
            }
            push @{$lang_results}, { lang => $lang, results => $results };
        }
    } else {
        push @{$lang_results}, { error => $errormsg . $letter_code };
    }
    return $lang_results;
}

sub TestMessages {
    my $dbh = C4::Context->dbh;

    my $sth = $dbh->prepare('SELECT * FROM reserves WHERE itemnumber IS NOT NULL LIMIT 1');
    $sth->execute();

    my $href =  $sth->fetchrow_hashref;
    DEBUG "reserve: " . $href ;

    my $tables = { 'href' => $href, };

    if ($href) {
      $tables = {   'href'     => $href,
                    # 'reserves'    => $href,
                    'branches'    => $href->{branchcode},
                    'borrowers'   => $href->{borrowernumber},
                    'biblio'      => $href->{biblionumber},
                    'biblioitems' => $href->{biblionumber},
                    'items'       => $href->{itemnumber},
                };
    }

    my $letter_code = 'HOLD_SLIP';

    return TestLettersWithCode($letter_code, $tables, "No reservations have been made, cannot test ");
}
