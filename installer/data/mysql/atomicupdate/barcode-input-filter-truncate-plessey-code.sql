UPDATE systempreferences SET options = concat(options,'|truncate-plessey') WHERE variable = 'itemBarcodeInputFilter' AND options NOT LIKE '%truncate-plessey%';
