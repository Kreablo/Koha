[% USE Asset %]
[% Asset.js("js/ajax.js") %]
[% Asset.js("js/form-completer.js") %]
<script type="text/javascript">
    //<![CDATA[
        var MSG_FETCHING_BORROWER_DATA = _("Fetching borrower data ...");
    //]]>
    $(document).ready(function() {
      new FormCompleter({
	"modal": "#fetch-borrower-data-modal",
	"form_id": "entryform",
	"url": "/api/v1/borrower_completion",
	"fetch_msg": MSG_FETCHING_BORROWER_DATA
      });
    });
</script>
<form>
  <div id="fetch-borrower-data-modal" class="modal fade" tabindex="-1" role="dialog">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
	<div class="modal-header">
          <button type="button" class="closebtn" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title">Fetch borrower data</h4>
	</div>
	<div class="modal-body">
      	  <div>
            <label for="recipient-name" class="control-label">Personal number:</label>
            <input type="text" class="form-control" id="personal-number" required pattern="(\d{10})|(\d{12})|(\d{6}-\d{4})|(\d{8}-\d{4})" title="A valid personal number (yymmdd-xxxx, yyyymmdd-xxxx, yymmddxxxx, or yyyymmddxxxx).">
	  </div>
	</div>
	<div class="modal-footer">
          <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
          <button type="button" class="btn btn-primary">Fetch borrower data</button>
	</div>
      </div><!-- /.modal-content -->
    </div><!-- /.modal-dialog -->
  </div><!-- /.modal -->
</form>  
