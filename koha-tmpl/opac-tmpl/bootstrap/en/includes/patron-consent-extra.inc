<fieldset class="patron-consent-extra">
    <legend><h2>Mandatory information</h2></legend>
    <p> You must select a PIN code for borrowing material using self service terminals. </p>
    <div class="has-validation">
        <label for="password">PIN code:</label>
        <input class="form-control" type="password" id="password" size="10" name="pce_password" value="" autocomplete="off" />
        <div id="passwordFeedback" class="invalid-feedback"> Please specify PIN code </div>
    </div>
    <div class="has-validation">
        <label for="password">PIN code repeat:</label>
        <input class="form-control" type="password" id="password2" size="10" name="pce_password2" value="" autocomplete="off" />
        <div id="password2Feedback" class="invalid-feedback"> Please specify PIN code </div>
    </div>
    <div class="has-validation">
        <label for="language">Language for receiving messages:</label>
        [% FOREACH languages_loo IN languages_loop %]
            [% IF ( languages_loo.group_enabled ) %]
                [% IF ( languages_loo.plural ) %]
                    [% FOREACH sublanguages_loo IN languages_loo.sublanguages_loop %]
                        [% IF ( sublanguages_loo.enabled ) %]
                            <div>
                                <input
                                    type="radio"
                                    name="pce_language"
                                    value="[% sublanguages_loo.rfc4646_subtag | html %]"
                                    id="language-[% sublanguages_loo.rfc4646_subtag | html %]"
                                    [% IF ( sublanguages_loo.sublanguage_current ) %]checked[% END %]
                                />
                                <label for="language-[% sublanguages_loo.rfc4646_subtag | html %]">
                                    [% sublanguages_loo.native_description | html %] [% sublanguages_loo.script_description | html %] [% sublanguages_loo.region_description | html %]
                                    [% sublanguages_loo.variant_description | html %]
                                </label>
                            </div>
                        [% END # / IF sublanguages_loo.enabled %]
                    [% END # / FOREACH sublanguages_loo %]
                [% ELSE %]
                    [% IF ( languages_loo.group_enabled ) %]
                        <div>
                            <input type="radio" name="pce_language" value="[% languages_loo.rfc4646_subtag | html %]" id="language-[% languages_loo.rfc4646_subtag | html %]" [% IF ( languages_loo.current ) %]checked[% END %] />
                            <label for="language-[% languages_loo.rfc4646_subtag | html %]">
                                [% languages_loo.native_description | html %] [% languages_loo.script_description | html %] [% languages_loo.region_description | html %]
                                [% languages_loo.variant_description | html %]
                            </label>
                        </div>
                    [% END # / IF languages_loo.group_enabled %]
                [% END # / IF ( languages_loo.plural ) %]
            [% END # / IF ( languages_loo.group_enabled ) %]
        [% END # / FOREACH languages_loo IN languages_loop %]
    </div>
</fieldset>
<script>
    (() => {
        "use strict";

        // Fetch all the forms we want to apply custom Bootstrap validation styles to
        const forms = document.querySelectorAll(".needs-validation");

        // Loop over them and prevent submission
        Array.from(forms).forEach(form => {
            form.addEventListener(
                "submit",
                event => {
                    if (!form.checkValidity()) {
                        event.preventDefault();
                        event.stopPropagation();
                    }

                    form.classList.add("was-validated");
                },
                false
            );
        });

        const password1 = document.querySelector('.patron-consent-extra input[name="pce_password"]');
        const password2 = document.querySelector('.patron-consent-extra input[name="pce_password2"]');

        if (password1 && password2) {
            const validatePassword = () => {
                const feedback1 = document.querySelector("#passwordFeedback");
                const feedback2 = document.querySelector("#password2Feedback");

                let msg = "";
                let valid = false;
                if (!password1.value.match(/^\d{4}\d*$/)) {
                    msg = _("PIN code must consist of at least four digits and only digits.");
                    password1.classList.add("is-invalid");
                    feedback1.textContent = msg;
                } else if (password1.value !== password2.value) {
                    msg = _("PIN codes don't match");
                    password1.setCustomValidity(msg);
                    password1.classList.add("is-invalid");
                    feedback1.textContent = msg;
                    password2.setCustomValidity(msg);
                    password2.classList.add("is-invalid");
                    feedback2.textContent = msg;
                } else {
                    valid = true;
                    password1.setCustomValidity(msg);
                    password1.classList.remove("is-invalid");
                    password2.setCustomValidity(msg);
                    password2.classList.remove("is-invalid");
                }
                if (valid) {
                    const button = document.querySelector("#saveconsent");
                    if (button) {
                        button.disabled = false;
                    }
                }
            };
            password1.addEventListener("blur", validatePassword);
            password2.addEventListener("blur", validatePassword);
        }
    })();
</script>
