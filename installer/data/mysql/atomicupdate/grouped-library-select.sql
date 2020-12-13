INSERT IGNORE INTO systempreferences (variable, value, explanation, options, type)
VALUES
('OPACGroupedLibrarySelect', '0', 'Dropdowns for library selection will be grouped by library group in the OPAC.', NULL, 'YesNo'),
('IntranetGroupedLibrarySelect', '0', 'Dropdowns for library selection will be grouped by library group in the staff client.', NULL, 'YesNo')
;
