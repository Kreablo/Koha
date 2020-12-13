[% BLOCK options_for_libraries %]
   [% IF Koha.Preference('IntranetGroupedLibrarySelect') %]
     [% PROCESS grouped_options_for_libraries groups => Branches.all_grouped(params) %]
   [% ELSE %]
     [% PROCESS ungrouped_options_for_libraries libraries => Branches.all(params) %]
   [% END %]
[% END %]

[% BLOCK ungrouped_options_for_libraries %]
    [% FOREACH l IN libraries %]
        [% IF l.selected %]
            <option value="[% prefix | html %][% l.branchcode | html %]" selected="selected">[% l.branchname | html %]</option>
        [% ELSE %]
            <option value="[% prefix | html %][% l.branchcode | html %]">[% l.branchname | html %]</option>
        [% END%]
    [% END %]
[% END %]

[% BLOCK grouped_options_for_libraries %]
    [% FOREACH g IN groups %]
        [% IF g.name %]
        <optgroup label="[% g.name %]">
        [% END %]
        [% FOREACH l IN g.libraries %]
            [% IF l.selected %]
                <option value="[% prefix | html %][% l.branchcode | html %]" selected="selected">[% l.branchname | html %]</option>
            [% ELSE %]
                <option value="[% prefix | html %][% l.branchcode | html %]">[% l.branchname | html %]</option>
            [% END%]
        [% END %]
        [% IF g.name %]
        </optgroup>
        [% END %]
    [% END %]
[% END %]

[% BLOCK options_for_authorised_value_categories %]
    [% FOREACH avc IN authorised_value_categories %]
        [% IF avc.selected %]
            <option value="[% avc.category | html %]" selected="selected">[% avc.category | html %]</option>
        [% ELSE %]
            <option value="[% avc.category | html %]">[% avc.category | html %]</option>
        [% END %]
    [% END %]
[% END %]

[% BLOCK options_for_item_types %]
    [% FOREACH itemtype IN itemtypes %]
        [% IF itemtype.itemtype == selected_itemtype %]
            <option value="[% itemtype.itemtype | html %]" selected="selected">
        [% ELSE %]
            <option value="[% itemtype.itemtype | html %]">
        [% END %]
            [% itemtype.translated_description | html %]
        </option>
    [% END %]
[% END %]
