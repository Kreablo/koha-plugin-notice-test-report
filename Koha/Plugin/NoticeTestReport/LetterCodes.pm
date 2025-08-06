package Koha::Plugin::NoticeTestReport::LetterCodes;

my $preduedgst = 'SELECT biblio.*, items.*, issues.* FROM issues,items,biblio WHERE biblio.biblionumber = items.biblionumber AND issues.itemnumber = items.itemnumber AND borrowernumber = ?';

our %letter_queries = ('HOLD_SLIP' => 'SELECT * FROM reserves WHERE itemnumber IS NOT NULL LIMIT 1',
                    'PREDUE' => 'SELECT * FROM issues INNER JOIN items USING (itemnumber) LIMIT 1',
                       'PREDUEDGST' => $preduedgst
    );

our @letter_codes = sort(keys %letter_queries);

1;
