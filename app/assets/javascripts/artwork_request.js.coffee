@initializeSummernote = ->
  $(".summernote").summernote height: 300

@initializeArtworkRequestDateTimePicker = ->
  $("#artwork-request-deadline-widget").datetimepicker()

@initializeJobsChosen = ->
  $("#jobs-tokenfield").chosen
    placeholder_text_multiple: "Select all jobs for this request"
    no_results_text: "No results matched"
    width: "400px"

@summernoteArtworkRequest = ->
  $(".summernote").closest("form").submit ->
    $(".summernote").val $(".summernote").code()

@setNewArtworkRequestSelect = ->
  $(".artwork-status-select").hide()
  $(".artwork-status-select").val "Pending"

$(document).ready ->
  $(document).on "change", "#artwork_imprint_method_fields", (e) ->
    if $(this).find(":selected").attr("value")?
      ajax = $.ajax
        url: $(this).data("url") + "/" + $(this).find(":selected").attr("value")
        dataType: "script"
      ajax.done () ->
        $("input").iCheck
          checkboxClass: "icheckbox_minimal-grey"
          radioClass: "iradio_minimal-grey"
          increaseArea: "20%"