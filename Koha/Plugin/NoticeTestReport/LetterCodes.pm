package Koha::Plugin::NoticeTestReport::LetterCodes;

our %letter_queries = (
    'HOLD_SLIP' => \&hold_slip,
    'PREDUE' => \&predue,
    'PREDUEDGST' => \&preduedgst,
);

our @letter_codes = sort(keys %letter_queries);

sub hold_slip {
    my $q = 'SELECT * FROM reserves WHERE itemnumber IS NOT NULL LIMIT 1';
    my $sth = runquery($q);
    my $href = $sth->fetchrow_hashref;

    return { href => $href, params => {} };
}

sub predue {
    my $q = 'SELECT * FROM issues INNER JOIN items USING (itemnumber) LIMIT 1';
    my $sth = runquery($q);
    my $href = $sth->fetchrow_hashref;

    return { href => $href, params => {} };
}

my $itemscontent = join(',',qw( date_due title author barcode ));
# The fields that will be substituted into <<items.content>>
my @item_content_fields = split(/,/,$itemscontent);

sub preduedgst {
    my $q = 'SELECT biblio.*, items.*, issues.* FROM issues,items,biblio WHERE biblio.biblionumber = items.biblionumber AND issues.itemnumber = items.itemnumber AND borrowernumber = ?';
    my $borrowernumber = &multi_loan_borrower;
    my $sth = runquery($q, $borrowernumber);
    my $href;

    my @itemnumbers = ();

    my $titles = "";

    while ( my $item_info = $sth->fetchrow_hashref ) {
        $href = $item_info;
        $titles .= C4::Letters::get_item_content(
            { item => $item_info, item_content_fields => \@item_content_fields }
        );
        push @itemnumbers, $item_info->{'itemnumber'};
    }
    my $params = {
        'substitute'             => {
            'count'         => scalar @itemnumbers,
            'items.content' => $titles,
        },
        'itemnumbers'            => \@itemnumbers,
        'borrowernumber' => $borrowernumber,
    };
    return {
        href => $href,
        params => $params
    }
}

sub runquery {
    my ($query, @args) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($query);
    $sth->execute(@args);
    return $sth;
}

sub multi_loan_borrower {
    my $sth = runquery('SELECT borrowernumber FROM issues GROUP BY borrowernumber HAVING COUNT(*) >= 2 LIMIT 1');
    my $href = $sth->fetchrow_hashref;

    return $href->{borrowernumber};
}

1;
