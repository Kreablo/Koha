[% BLOCK options_for_libraries %]
   [% IF Koha.Preference('OPACGroupedLibrarySelect') %]
     [% IF pickup_locations %]
        [% PROCESS grouped_options_for_libraries groups => Branches.pickup_locations_grouped(params) %]
     [% ELSE %]
        [% PROCESS grouped_options_for_libraries groups => Branches.all_grouped(params) %]
     [% END %]
   [% ELSE %]
     [% IF pickup_locations %]
       [% PROCESS ungrouped_options_for_libraries libraries => Branches.pickup_locations(params) %]
     [% ELSE %]
       [% PROCESS ungrouped_options_for_libraries libraries => Branches.all(params) %]
     [% END %]
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

[% BLOCK koha_news_block %]
    [% IF ( news.content.size > 0 ) %]
        <div id="[% news.location | html %]">
            [% FOREACH n IN news.content %]
                <div class="[% n.lang | html %]_item">
                    [% IF ( n.title && news.blocktitle ) %]
                        <h4 class="[% n.lang | html %]_header">[% n.title | html %]</h4>
                    [% END %]
                    <div class="[% n.lang | html %]_body">[% n.content | $raw %]</div>
                </div>
            [% END %]
        </div>
    [% END %]
[% END %]
