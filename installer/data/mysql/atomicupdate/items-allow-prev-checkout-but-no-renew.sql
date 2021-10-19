INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type`) VALUES
('ItemsAllowPrevCheckoutButNoRenew', '', '', 'Comma separated list of itemtypes for which SIP-checkouts on prevoisly checked out items should be granted, although no renewal is made on the issue.', 'multiple'),
('ItemsAllowPrevCheckoutButNoRenewMessage', '', '', 'Reply message when previously issued item is checked out without renewal.', '');

