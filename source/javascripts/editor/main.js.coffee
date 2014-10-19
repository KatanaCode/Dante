window.Editor = {

}

###
#TODO:
+ OK set selected <p> like medium
+ OK shows the + when selected <p> is empty
+ detect enter key between words to split and duplicate tags
+ actions over text
###

# make it accessible
window.selection = 0
selected_menu = false
window.current_editor = null

class Editor.MainEditor extends Backbone.View
  el: "#editor"

  events:
    "blur"    : "handleBlur"
    "mouseup" : "handleTextSelection"
    "keydown" : "handleKeyDown"
    "keyup"   : "handleCarriageReturn"
    "paste"   : "handlePaste"

  initialize: (opts = {})=>
    @editor_options = opts
    window.current_editor = @
    #globals for selected text and node
    @current_range = null
    @current_node = null

    if (localStorage.getItem('contenteditable'))
      $(@el).html  localStorage.getItem('contenteditable')

    @store()

  store: ()->
    localStorage.setItem("contenteditable", $(@el).html )
    setTimeout ()=>
      console.log("storing")
      @store()
    , 5000

  template: ()=>
    "<section class='section-content'>
      <div class='section-inner'>
        <h3 class='graf--h3'>title here</h3>
        <p class='graf--p'>body here<p>
      </div>
    </section>"

  render: ()=>
    @template()
    $(@el).html @template()
    $(@el).attr("contenteditable", "true")

    $(@el).wrap("<div class='notesSource'></div>")

    $("<div id='editor-menu' class='editor-menu' style='opacity: 0;'></div>").insertAfter(@el)
    $("<div class='inlineTooltip2 button-scalableGroup is-active'></div>").insertAfter(@el)

    @editor_menu = new Editor.Menu()

    @tooltip_view = new Editor.Tooltip()
    @tooltip_view.render()

  getSelectedText: () ->
    text = ""
    if typeof window.getSelection != "undefined"
      text = window.getSelection().toString()
    else if typeof document.selection != "undefined" && document.selection.type == "Text"
      text = document.selection.createRange().text
    text
    #text

  selection: ()=>
    selection
    if (window.getSelection)
      selection = window.getSelection()
    else if (document.selection && document.selection.type != "Control")
      selection = document.selection

  getRange: () ->
    editor = $(@el)[0]
    range = selection.rangeCount && selection.getRangeAt(0)
    range = document.createRange() if (!range)
    if !editor.contains(range.commonAncestorContainer)
      range.selectNodeContents(editor)
      range.collapse(false)
    range

  setRange: (range)->
    range = range || this.current_range
    if !range
      range = this.getRange()
      range.collapse(false); # set to end

    @selection().removeAllRanges()
    @selection().addRange(range)
    @

  #set focus and caret position on element
  setRangeAt: (element)->
    range = document.createRange()
    sel = window.getSelection()

    range.setStart(element, 0);
    range.collapse(true)
    sel.removeAllRanges()
    sel.addRange(range)
    @el.focus()

  focus: (focusStart) ->
    @.setRange() if (!focusStart)
    $(@el).focus()
    @

  #NOT USED
  focusNode: (node, range)->
    range.setStartAfter(node)
    range.setEndBefore(node)
    range.collapse(false)
    @.setRange(range)

  #get the element that wraps Caret position
  getNode: ()->
    node = undefined
    root = $(@el).find(".section-inner")[0]
    range = @selection().getRangeAt(0)
    node = range.commonAncestorContainer
    return null  if not node or node is root
    node = node.parentNode  while node and (node.nodeType isnt 1) and (node.parentNode isnt root)
    node = node.parentNode  while node and (node.parentNode isnt root)
    (if root.contains(node) then node else null)

  displayMenu: (sel)->
    @handleCaret()
    @editor_menu.render()
    @editor_menu.show()

  resetOffset: ($textField)=>
    offset = $textField.caret('offset');
    position = $textField.caret('position');
    @resizeBox(offset, position)
    offset

  resizeBox: (offset, position)->
    padd = @editor_menu.$el.width() / 2
    padd = padd + (padd * 0.1)
    top =  offset.top - offset.height - 16
    @editor_menu.$el.offset({left: offset.left - padd, top: top })

  handleBlur: (ev)=>
    #console.log(ev)
    #hide menu only if is not in use
    setTimeout ()=>
      @editor_menu.hide() unless selected_menu
    , 200

    @tooltip_view.hide()
    false

  handleFocus: (ev)=>
    console.log("Handle focus #{ev}")

  #get text of selected and displays menu
  handleTextSelection: (ev)->
    @editor_menu.hide()
    text = @getSelectedText()
    unless _.isEmpty text
      @current_range = @getRange()
      @current_node  = @getNode()
      #console.log(@current_range)
      @.displayMenu()

  handleCaret: ()->
    @resetOffset($(@el));

  handleArrow: (ev)=>
    console.log("ENTER ARROWS")
    #console.log @getNode()
    current_node = $(@getNode())
    @displayTooltipAt( current_node )
    @markAsSelected( current_node )

  handlePaste: (ev)=>
    console.log("pasted!")
    debugger
    @cleanContents()
    @setupElementsClasses()

  #overrides default behavior
  handleKeyDown: (e)->
    e.preventDefault() if _.contains([13], e.which)

  handleCarriageReturn: (e)->
    @editor_menu.hide() #hides menu just in case

    anchor_node = @getNode() #current node on which cursor is positioned
    previous_node = anchor_node.previousSibling
    next_node = anchor_node.nextSibling

    #enter key
    if (e.which == 13)
      e.preventDefault() #http://stackoverflow.com/questions/6023307/dealing-with-line-breaks-on-contenteditable-div

      #removes all childs
      $(@el).find(".is-selected").removeClass("is-selected")

      parent = $(anchor_node)

      #return unless $(@el).is( @getRange().commonAncestorContainer )

      if parent.prop("tagName") != "P"
        #debugger
        # if matches the linebreak match
        if (anchor_node && @editor_menu.lineBreakReg.test(anchor_node.nodeName))
          @handleLineBreakWith(parent.prop("tagName").toLowerCase(), parent  )
        else
          @handleLineBreakWith("p", parent)

        #TODO: we block more enters because we don't now how to handle this yet
        #return
      else
        @handleLineBreakWith("p", parent)

    #delete key
    if (e.which == 8)
      @tooltip_view.hide()

      if $(anchor_node).text() is ""
        @position = $(anchor_node).offset()
        setTimeout(
          ()=>
            @tooltip_view.render()
            @tooltip_view.move(left: @position.left - 60 , top: @position.top - 10 )
        , 200)

    #arrows key
    if _.contains([37,38,39,40], e.which)
      @handleArrow(e)

    @cleanContents()

  handleLineBreakWith: (element_type, from_element)->
    new_paragraph = $("<#{element_type} class='graf graf--#{element_type} graf--empty is-selected'><br/></#{element_type}>")

    if from_element.parent().is('[class^="graf--"]')
      new_paragraph.insertAfter(from_element.parent())
    else
      new_paragraph.insertAfter(from_element)

    #set caret on new <p>
    @setRangeAt(new_paragraph[0])
    #shows tooltip

    @displayTooltipAt($(new_paragraph))

  #shows the (+) tooltip at current element
  displayTooltipAt: (element)->
    #console.log $(element)
    @tooltip_view.hide()
    return unless _.isEmpty( $(element).text() )
    @position = $(element).offset()
    @tooltip_view.render()
    @tooltip_view.move(left: @position.left - 60 , top: @position.top - 5 )

  #mak the current row as selected
  markAsSelected: (element)->
    $(@el).find(".is-selected").removeClass("is-selected")
    $(element).addClass("is-selected")

  setupElementsClasses: ()->
    setTimeout ()=>
      $(@el).find(".section-inner").find("span , div").contents().unwrap()
      _.each  $(@el).find(".section-inner").children(), (n)->
        name = $(n).prop("tagName").toLowerCase()
        $(n).removeClass().addClass("graf--#{name}")
    , 200


  cleanContents: ()->
    #TODO: should config tags
    console.log("CLEAN CONTENTS NAW")
    node = @getNode()
    $(node).find("span , div").contents().unwrap()

class Editor.Menu extends Backbone.View
  el: "#editor-menu"

  events:
    "mousedown i" : "handleClick"
    #"click .editor-icon" : "handleClick"
    "mouseenter" : "handleOver"
    "mouseleave" : "handleOut"

  initialize: (opts={})=>
    @config = opts.buttons || @default_config()

    @commandsReg = {
      block: /^(?:p|h[1-6]|blockquote|pre)$/
      inline: /^(?:bold|italic|underline|insertorderedlist|insertunorderedlist|indent|outdent)$/,
      source: /^(?:insertimage|createlink|unlink)$/
      insert: /^(?:inserthorizontalrule|insert)$/
      wrap: /^(?:code)$/
    }

    @lineBreakReg = /^(?:blockquote|pre|div)$/i;

    @effectNodeReg = /(?:[pubia]|h[1-6]|blockquote|[uo]l|li)/i;

  default_config: ()->
    buttons: [
        'blockquote', 'h2', 'h3', 'p', 'code', 'insertorderedlist', 'insertunorderedlist', 'inserthorizontalrule',
        'indent', 'outdent', 'bold', 'italic', 'underline', 'createlink'
      ]

  template: ()=>
    html = ""
    _.each @config.buttons, (item)->
      html += "<i class=\"editor-icon icon-#{item}\" data-action=\"#{item}\"></i>"
    html

  render: ()=>
    $(@el).html(@template())
    @show()
    @delegateEvents()

  handleClick: (ev)->
    element = $(ev.currentTarget)
    name = element.data("action")
    value = $(@el).find("input").val()

    console.log("menu #{name} item clicked!")

    if @commandsReg.block.test(name)
      console.log "block here"
      @commandBlock name
    else if @commandsReg.inline.test(name) or @commandsReg.source.test(name)
      console.log "overall here"
      @commandOverall name, value
    else if @commandsReg.insert.test(name)
      console.log "insert here"
      @commandInsert name
    else if @commandsReg.wrap.test(name)
      console.log "wrap here"
      @commandWrap name
    else
      console.log "can't find command function for name: " + name

    @cleanContents()
    false

  cleanContents: ()->
    current_editor.cleanContents()

  commandOverall: (cmd, val) ->
    message = " to exec 「" + cmd + "」 command" + ((if val then (" with value: " + val) else ""))
    if document.execCommand(cmd, false, val)
      console.log "success" + message
    else
      console.log "fail" + message, true
    return

  commandInsert: (name) ->
    node = current_editor.current_node
    return  unless node
    current_editor.current_range.selectNode node
    current_editor.current_range.collapse false
    @commandOverall node, name

  commandBlock: (name) ->
    node = current_editor.current_node
    list = @effectNode(current_editor.getNode(node), true)
    name = "p" if list.indexOf(name) isnt -1
    @commandOverall "formatblock", name

  commandWrap: (tag) ->
    node = current_editor.current_node
    val = "<" + tag + ">" + selection + "</" + tag + ">"
    @commandOverall "insertHTML", val

  # node effects
  effectNode: (el, returnAsNodeName) ->
    nodes = []
    el = el or current_editor.$el[0]
    while el isnt current_editor.$el[0]
      nodes.push (if returnAsNodeName then el.nodeName.toLowerCase() else el)  if el.nodeName.match(@effectNodeReg)
      el = el.parentNode
    nodes

  handleOut: ()->
    selected_menu = false

  handleOver: ()->
    selected_menu = true

  show: ()->
    $(@el).css("opacity", 1)
    $(@el).css('visibility', 'visible')

  hide: ()->
    $(@el).css("opacity", 0)
    $(@el).css('visibility', 'hidden')


class Editor.Tooltip extends Backbone.View
  el: ".inlineTooltip2"

  initialize: ()=>
    #console.log $(@el).length

  template: ()->
    '<button class="button button--small button--circle button--neutral button--inlineTooltipControl" title="Add an image, video, embed, or new part" data-action="inline-menu">
        <span class="fa fa-plus"></span>
    </button>'

  render: ()=>
    #console.log @template()
    $(@el).html(@template())
    $(@el).show()

  move: (coords)->
    $(@el).offset(coords)

  hide: ()=>
    $(@el).hide()



###
addEvent(document.getElementById('clear'), 'click', function () {
  localStorage.clear();
  window.location = window.location; // refresh
});

if (localStorage.getItem('contenteditable')) {
  editable.innerHTML = localStorage.getItem('contenteditable');
}
###