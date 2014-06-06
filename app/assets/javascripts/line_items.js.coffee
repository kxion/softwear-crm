$(window).ready ->
  $('.add-line-item').click ->
    $this = $(this)
    $this.attr 'disabled', 'disabled'
    setTimeout (-> $this.removeAttr 'disabled'), 1000
    # TODO if modal is already present, kill it and return maybe

    ajax = $.ajax
      type: 'GET',
      url: "/jobs/#{$this.attr 'data-id'}/line_items/new"
      dataType: 'html'

    ajax.done (response) ->
      $('body').children().last().after $(response)
      lineItemModal = $('#lineItemModal')
      initializeLineItemModal lineItemModal
      lineItemModal.on 'hidden.bs.modal', (e) ->
        lineItemModal.remove()

    ajax.fail (jqXHR, textStatus) ->
      alert "Internal server error! Can't process request."

initializeLineItemModal = (lineItemModal) ->
  $currentFormDiv = null
  currentForm = -> $currentFormDiv.find('form')

  handler = null

  $('input:radio[name="is_imprintable"]').change ->
    $radio = $(this)
    $radio.attr 'disabled', 'disabled'
    setTimeout (-> $radio.removeAttr 'disabled'), 1000

    $out = null
    $in = null
    if $(this).val() == 'yes'
      $out = $('#li-standard-form')
      $in  = $('#li-imprintable-form')
    else
      $out = $('#li-imprintable-form')
      $in  = $('#li-standard-form')

    $out.fadeOut 400, ->
      handler.clear() if handler != null
      handler = null
      $currentFormDiv = $in
      $in.fadeIn 400

  submitForm = ->
    $add = $(this)
    $add.attr 'disabled', 'disabled'
    setTimeout (-> $add.removeAttr 'disabled'), 5000

    handler.clear() if handler != null

    $currentFormDiv ||= $('#li-standard-form')
    action = currentForm().attr('action')

    ajax = $.ajax
      type: 'POST'
      url: action
      data: currentForm().serialize()
      dataType: 'json'

    ajax.done (response) ->
      if response.result == 'success'
        console.log 'Successfully created line item!'
        jobId = action.charAt(action.indexOf('jobs/')+'jobs/'.length)
        refreshJob jobId
        lineItemModal.modal 'hide'

      else if response.result == 'failure'
        console.log 'Failed to create'
        handler ||= ErrorHandler('line_item', currentForm())
        handler.handleErrors(response.errors, response.modal)

    ajax.fail (jqXHR, textStatus) ->
      alert "Something's wrong with the server!"

  $('#line-item-submit').click submitForm
  lineItemModal.keyup (key) ->
    submitForm() if key.which is 13

  handleImprintableForm = ($form) ->
    $select_level = (num) -> $(".select-level[data-level='#{num}']")
    clearSelectLevel = (num) -> $select_level(num).children().filter('*:not(div)').remove()
    getOptions = (data=null, done) -> 
      a = $.ajax
        type: 'GET'
        url: '/line_items/select_options'
        data: data
      a.fail (jqXHR, textStatus) ->
        alert('Internal server error. Sorry!')
      a.done done

    ajax = getOptions()

    ajax.done (response) ->
      data =
        brand_id: null
        style_id: null
        color_id: null
      $response = $(response)
      clearSelectLevel(1)
      $select_level(1).prepend $response
      $response.change ->
        data.brand_id = $(this).val()
        ajax = getOptions data, (response) ->
          $response = $(response)
          $response.attr 'disabled', 'disabled'
          clearSelectLevel(2)
          $select_level(2).prepend $response
          $response.fadeIn
          $response.change ->
            data.style_id = $(this).val()
            ajax = getOptions data, (response) ->
              $response = $(response)
              $response.attr 'disabled', 'disabled'
              clearSelectLevel(3)
              $select_level(3).prepend $response
              $response.fadeIn
              $response.change ->
                data.color_id = $(this).val()
                ajax = getOptions data, (response) ->
                  $response = $(response)
                  $response.attr 'disabled', 'disabled'
                  clearSelectLevel(4)
                  $select_level(4).prepend $response
                  $response.fadeIn


  handleImprintableForm $('#li-imprintable-form')
  lineItemModal.modal 'show'