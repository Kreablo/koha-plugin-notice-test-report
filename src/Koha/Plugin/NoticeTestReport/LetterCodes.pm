package Koha::Plugin::NoticeTestReport::LetterCodes;

our %letter_queries = (
    'HOLD_SLIP' => \&hold_slip,
    'PREDUE' => \&predue,
    'PREDUEDGST' => \&preduedgst,
    'HOLDDGST' => \&holddgst,
);

our @letter_codes = sort(keys %letter_queries);

=head2 holddgst
Since Kohas implementation of HOLDDGST is concatenation of unsent messages this might as well just call hold_slip
=cut
sub holddgst {
    return hold_slip(@_);
}

sub hold_slip {
    my $params = shift;
    my $sth;
    if ($params->{cateogrycode}) {
        my $q = 'SELECT * FROM reserves JOIN borrowers USING (borrowernumber) WHERE itemnumber IS NOT NULL AND categorycode = ? LIMIT 1';
        $sth = runquery($q, $params->{categorycode});
    } else {
        my $q = 'SELECT * FROM reserves WHERE itemnumber IS NOT NULL LIMIT 1';
        $sth = runquery($q);
    }
    my $href = $sth->fetchrow_hashref;

    return { href => $href, params => { 'hold' => $href } };
}

sub predue {
    my $params = shift;
    my $sth;
    if ($params->{categorycode}) {
        my $q = 'SELECT * FROM issues INNER JOIN items USING (itemnumber) JOIN borrowers USING(borrowernumber) WHERE categorycode = ? LIMIT 1';
        $sth = runquery($q, $params->{categorycode});
    } else {
        my $q = 'SELECT * FROM issues INNER JOIN items USING (itemnumber) LIMIT 1';
        $sth = runquery($q);
    }
    my $href = $sth->fetchrow_hashref;

    return { href => $href, params => {} };
}

my $itemscontent = join(',',qw( date_due title author barcode ));
# The fields that will be substituted into <<items.content>>
my @item_content_fields = split(/,/,$itemscontent);

sub preduedgst {
    my $params = shift;

    my $q = 'SELECT biblio.*, items.*, issues.* FROM issues,items,biblio WHERE biblio.biblionumber = items.biblionumber AND issues.itemnumber = items.itemnumber AND borrowernumber = ?';
    my $borrowernumber = multi_loan_borrower($params);

    if (!defined $borrowernumber) {
        return { error => "Could not find borrower with several loans." };
    }

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
    my $params = shift;
    my $sth;

    if ($params->{categorycode}) {
        $sth = runquery('SELECT borrowernumber FROM issues JOIN borrowers USING(borrowernumber) WHERE categorycode=? GROUP BY borrowernumber HAVING COUNT(*) >= 2 LIMIT 1', $params->{categorycode});
    } else {
        $sth = runquery('SELECT borrowernumber FROM issues GROUP BY borrowernumber HAVING COUNT(*) >= 2 LIMIT 1');
    }

    my $href = $sth->fetchrow_hashref;
    return $href->{borrowernumber};
}

1;
