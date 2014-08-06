jQuery ->

  if $('#sample_location_ids').length
    stores = $('#sample_location_ids').data()['stores']
    store_name_array = []
    for store in stores
      store_name_array.push(store[0])
    $('#sample_location_ids').on('tokenfield:createtoken', (e) ->
      for store in stores
        if e.attrs.label == store[0]
          e.attrs.value == store[1]
    ).tokenfield({
          autocomplete: {
            source: store_name_array,
            delay: 100
          },
          showAutocompleteOnFocus: true
    })

  $(document).on('click', '.add_fields', ->
    $('.chosen-select').chosen()
  )

  # these functions are modified from an example hosted publicly at
  # http://www.mredkj.com/tutorials/tableaddcolumn.html
  `function addColumn(tblId, size, size_id)
  {
    var tblHeadObj = document.getElementById(tblId).tHead;
    var select = document.getElementById('add-a-size');

    // first make sure size hasn't already been selected
    var tableHeaders = tblHeadObj.rows[0].cells;
    for (var h = 0; h < tableHeaders.length; ++h) {
      if (size == tableHeaders[h].outerText) {
        if(!confirm("This would create a duplicate size, are you sure you wish to proceed?"))
          return;
      }
    }

    for (var h=0; h<tblHeadObj.rows.length; h++) {
      var newTH = document.createElement('th');
      newTH.id = "col-"+String(tblHeadObj.rows[h].cells.length-1);
      newTH.setAttribute("data-size-id", size_id);

      tblHeadObj.rows[h].deleteCell(tblHeadObj.rows[h].cells.length-1);
      tblHeadObj.rows[h].appendChild(newTH);

      var headerPlus = document.createElement('i');
      var headerMinus = document.createElement('i');

      headerPlus.id = "col-plus-"+String(tblHeadObj.rows[h].cells.length-1);
      headerMinus.id = 'col-minus-'+String(tblHeadObj.rows[h].cells.length-1);

      newTH.innerHTML = size

      headerPlus.className = 'fa fa-plus';
      headerMinus.className = 'fa fa-minus';

      newTH.appendChild(headerPlus);
      newTH.appendChild(headerMinus);

      tblHeadObj.rows[h].appendChild(select);
    }

    var tblBodyObj = document.getElementById(tblId).tBodies[0];
    for (var i=0; i<tblBodyObj.rows.length-1; i++) {
      var newCell = tblBodyObj.rows[i].insertCell(-1);
      newCell.id = "cell-"+String(i+1)+"-"+String(tblHeadObj.rows[0].cells.length-2);

      var cellPlus = document.createElement('i');
      var cellMinus = document.createElement('i');

      cellPlus.className = 'fa fa-plus cell';
      cellMinus.className = 'fa fa-minus cell';

      var check = document.createElement('i');
      check.className = 'fa fa-check';
      check.id = "image-"+String(i+1)+"-"+String(tblHeadObj.rows[0].cells.length-2);

      newCell.appendChild(check);
      newCell.appendChild(cellPlus);
      newCell.appendChild(cellMinus);
    }
  }`

  $(document).on('click', '#size-button', ->
    size = $('#size_select :selected').text()
    size_id = $('#size_select :selected').val()
    if size == 'Select a Size'
      return
    addColumn('imprintable-variants-list', size, size_id)
  )

  $(document).on('click', '#color-button', ->
    color = $('#color_select :selected').text()
    color_id = $('#color_select :selected').val()
    if color == 'Select a Color'
      return

    table = document.getElementById('imprintable-variants-list')
    tblBodyObj = table.tBodies[0]

    # first make sure the color hasn't already been selected
    rowCount = tblBodyObj.rows.length - 1
    while rowCount >= 0
      if (tblBodyObj.rows[rowCount].cells[0].outerText == color)
        if(!confirm("This would create a duplicate color, are you sure you wish to proceed?"))
          return
        else
          break
      rowCount -= 1

    count = tblBodyObj.rows[0].cells.length
    cellIndex = 0
    row = table.insertRow(tblBodyObj.rows.length)
    if count > 0
      rowHeader = document.createElement('th')
      row.id = "row-"+String(tblBodyObj.rows.length-1)
      row.setAttribute('data-color-id', color_id)
      cellIndex += 1
      count -= 1

      headerPlus = document.createElement('i')
      headerMinus = document.createElement('i')

      headerPlus.className = 'fa fa-plus'
      headerPlus.id = "row-plus-"+String(tblBodyObj.rows.length)

      headerMinus.className = 'fa fa-minus'
      headerMinus.id = "row-minus-"+String(tblBodyObj.rows.length)

      rowHeader.innerHTML = color
      rowHeader.appendChild(headerPlus)
      rowHeader.appendChild(headerMinus)

      row.appendChild(rowHeader)

    while count > 0
      # create new cell with times sign
      newCell = row.insertCell(cellIndex)
      count -= 1

      newCell.id = "cell-"+String(tblBodyObj.rows.length-1)+"-"+String(cellIndex)

      cellCheck = document.createElement('i')
      cellMinus = document.createElement('i')
      cellPlus = document.createElement('i')

      cellCheck.className = 'fa fa-check'
      cellCheck.id = "image-"+String(tblBodyObj.rows.length-1)+"-"+String(cellIndex)

      cellIndex += 1

      cellPlus.className = 'fa fa-plus cell'
      cellMinus.className = 'fa fa-minus cell'

      newCell.appendChild(cellCheck)
      newCell.appendChild(cellPlus)
      newCell.appendChild(cellMinus)
  )

  intersect_arrays = (x, y) ->
    z = []
    count = 0
    for item_one in x
      for item_two in y
        if item_one == item_two
          z[count] = item_one
          count += 1
          continue
    return z

  change_cells = (class_name, element) ->
    if /row_/.test(element.attr('id'))
      tds = document.querySelectorAll('#' + element.closest('tr').attr('id').concat(' td'))
      for item in tds
        item.firstElementChild.className = class_name
    else if /col_/.test(element.attr('id'))
      sub = element.attr('id').split('_')[2]
      sub = 'i[id$=-' + sub.toString() + ']'
      array_one = document.querySelectorAll('i[id^=image-]')
      array_two = document.querySelectorAll(sub)
      union = intersect_arrays(array_one, array_two)
      for item in union
        item.className = class_name
    else if /cell/.test(element.attr('class'))
      element = element.prev() until /image_\d*_\d*/.test(element.attr('id'))
      element.prop("class", class_name)

  aggregate_variants =  ->
    variants_to_remove = []
    times = $('.fa-times')
    for item in times
      if $(item).attr('data-variant-id')
        variants_to_remove.push($(item).attr('data-variant-id'))

    variants_to_add = new Array
    checks = $('.fa-check')
    for item in checks
      if !$(item).attr('data-variant-id')
        sub = $(item).attr('id').split('-')[2]
        colhead = document.querySelectorAll('#col-'+String(sub))
        size_id = $(colhead).attr('data-size-id')

        sub = $(item).attr('id').split('-')[1]
        rowhead = document.querySelectorAll('#row-'+String(sub))
        color_id = $(rowhead).attr('data-color-id')

        variants_to_add.push({size_id: size_id, color_id: color_id})

    return { variants_to_add: variants_to_add, variants_to_remove: variants_to_remove }

  populate_color_and_size_ids = ->
    color_ids = new Array
    size_ids = new Array
    checked = $(".checked")
    for item in checked
      if($(item).parent().parent().prev().text() == 'Color')
        color_ids.push($(item).children().first().attr('value'))
      else if ($(item).parent().parent().prev().text() == 'Size')
        size_ids.push($(item).children().first().attr('value'))
    return {color_ids: color_ids, size_ids: size_ids}

  $(document).on('click', '.fa-plus',  ->
    change_cells('fa fa-check', $(this))
  )

  $(document).on('click', '.fa-minus', ->
    change_cells('fa fa-times', $(this))
  )

  $('.chosen-select').chosen()
  $('.color-size-chosen-select').chosen( { width: '200px' } )
  $('#color_ids').chosen( { width: "100%" })
  $('#size_ids').chosen( { width: "100%" })

  $('.table.table-hover').fixedHeader()

  get_id = ->
    url_array = document.URL.split('/')
    id = url_array[url_array.length-2]
    return id

  $(document).on('click', '#submit_button', ->
    innerHtml = document.getElementById('submit_button').innerHTML
    if innerHtml == 'Update Imprintable'
      if $('#imprintable-variants-list').length
        # variants already exist
        # aggregate all the variants and populate params
        variant_hash = aggregate_variants()
        id = get_id()
        pobj = { update: variant_hash, id: id }
        $.post('/imprintables/update_imprintable_variants', pobj)
      else
        # variants don't exist yet
        # populate color_ids and size_ids
        ids_hash = populate_color_and_size_ids()
        id = get_id()
        pobj = { update: ids_hash, id: id }
  )
