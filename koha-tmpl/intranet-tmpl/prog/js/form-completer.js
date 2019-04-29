(function ($) {

  var defaults = {
    "modal": null,
    "form_id": null,
    "url": null,
    "input": "input",
    "button": "button.btn-primary",
    "fetch_msg": null,
    "modal_form_id": null
  };

  function FormCompleter(opts) {

    var keys = Object.keys(opts);
    
    for (var i = 0; i < keys.length; i++) {
      var opt = keys[i];
      if (Object.keys(defaults).indexOf(opt) < 0) {
	throw new Error("Invalid option: " + opt);
      }
    }

    this.opts = $.extend({}, defaults, opts);

    for (var opt in ["modal", "form_id", "url"]) {
      if (this.opts[opt] === null) {
	throw new Error("Missing required option: " + opt);
      }
    }

    this._init();
  }

  var p = FormCompleter.prototype;

  p._init = function _init() {
    var $modal = $(this.opts.modal);
    var $input = $modal.find(this.opts.input);
    var $button = $modal.find(this.opts.button);
    var self = this;
    var $modal_form = this.opts.modal_form_id !== null ? $("#" + this.opts.modal_form_id) : $modal.parents("form");
    $modal.on("shown.bs.modal", function () {
      $input.focus();
    });
    var submit = function submit (event) {
      event.stopPropagation();
      event.preventDefault();
      var valid = true;
      
      $input.each(function(index, element) {
	valid = valid && element.reportValidity();
      });

      if (!valid) {
	return;
      }
      
      var id = $input.val();
      KOHA.AJAX.MarkRunning(self.opts.modal, self.opts.fetch_msg);
      $.ajax({
	"url": self.opts.url + "/" + id.trim(),
	"dataType": "json",
	"statusCode": {
	  400: self.handle400.bind(self),
	  401: self.handle401.bind(self),
	  404: self.handle404.bind(self),
	  500: self.handle500.bind(self),
	  503: self.handle503.bind(self)
	}
      }).always(self.always.bind(self))
	.fail(self.fail.bind(self))
	.done(self.done.bind(self));

    };

    $modal_form.on("submit", submit);
    $button.click(submit);
  }

  p.done = function done (data, textStatus, jqXHR) {
    $(this.opts.modal).modal('hide');
    console.log("form id: " + this.opts.form_id)
    var $form = $('#' + this.opts.form_id);
    for (var i = 0; i < data.form_fields.length; i++) {
      var f = data.form_fields[i];
      console.log('[name="' + f.name + '"]');
      $form.find('[name="' + f.name + '"]').val(f.value);
    }
  };

  p.fail = function fail (jqXHR, textStatus, errorThrown) {
  }

  p.handle400 = function handle400 (jqXHR, textStatus, errorThrown) {
    
  }
  p.handle401 = function handle401 (jqXHR, textStatus, errorThrown) {
    
  }
  p.handle404 = function handle404 (jqXHR, textStatus, errorThrown) {
    
  }
  p.handle500 = function handle500 (jqXHR, textStatus, errorThrown) {
    
  }
  p.handle503 = function handle503 (jqXHR, textStatus, errorThrown) {
    
  }
  
  p.always = function always () {
      KOHA.AJAX.MarkDone(this.opts.modal);
  }

  window.FormCompleter = FormCompleter;

})($);

