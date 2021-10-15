$ ->

  addCheckboxChangeHandler = ($row)->
    $checkbox = $row.find(":checkbox")
    $select = $row.find("select")
    $textarea = $row.find("textarea")
    $checkbox.on "change", -> $select.prop(disabled: !this.checked)
    $checkbox.on "change", -> $textarea.prop(disabled: !this.checked)
    $checkbox.change()

  $(".js--access-list-row").each -> addCheckboxChangeHandler($(this))
