# Handy little module for ajax error handling!
# Doesn't actually do the ajaxing for you; just 
# adds and removes error content from the page.
@ErrorHandler = (resourceName, $form, resourceId) ->
  handler = {}
  capitalize = (str) -> (str.charAt(0).toUpperCase() + str.substr(1)).replace('_id', '').replace('_', ' ')
  contains = (array, thing) -> 
    return true if entry == thing for entry in array
    false
  getParamName = (field) ->
    if resourceName is null
      field
    else
      if resourceId
        "#{resourceName}[#{resourceId}][#{field}]"
      else
        "#{resourceName}[#{field}]"
  findFieldElementFor = (field) ->
    $field = $form.find("*[name^='#{getParamName(field)}']")
    $field = $form.find("*[name^='#{getParamName(field.replace('_id', ''))}']") if $field.length == 0
    $field = $form.find("*[name^='#{getParamName(field + '_id')}']") if $field.length == 0
    $field

  handler.errorFields = []

  handler.handleErrors = (errors, modal) ->
    handler.clear() if handler.errorFields.length > 0
    # Add modal
    $modal = null
    unless modal is null
      $modal = $(modal)
      $('body').append $modal
      $modal.on 'hidden.bs.modal', (e) -> $modal.remove()
    # Mark fields
    for field, fieldErrors of errors
      continue if fieldErrors.length == 0
      handler.errorFields.push(field)
      # Grab the input field element
      $field = findFieldElementFor field
      
      if $field.length == 0
        console.log "Couldn't find field #{field} (name #{getParamName(field)})"
        continue
      
      # Create the error message div
      $errorMsgDiv = $ '<div/>',
        class: 'error'
        for:   getParamName(field)

      # Place it before the input field
      $field.before $errorMsgDiv

      # Wrap the input field to make it red
      $field.wrap $('<div/>', class: 'field_with_errors') unless $field.data('no-wrap')

      # Populate error message div with messages
      for error in fieldErrors
        $errorMsgDiv.append $ '<p/>',
          class: 'text-danger'
          text:  "#{capitalize field} #{error}"

    # Show the modal
    $modal.modal 'show' unless $modal is null

  handler.clear = () ->
    for field in handler.errorFields
      $field = findFieldElementFor field
      $errorMsgDiv = $form.find(".error[for='#{getParamName(field)}']")
      $errorMsgDiv.remove()
      $field.unwrap() if $field.parent().hasClass('field_with_errors') and not $field.data('no-wrap')
    handler.errorFields = []

  return handler

@errorHandlerFrom = (element, resourceName, $form, resourceId) ->
  $element = $(element)
  handler = $element.data 'error-handler'
  if handler is undefined
    handler = ErrorHandler(resourceName, $form, resourceId)
    $element.data 'error-handler', handler

  handler
