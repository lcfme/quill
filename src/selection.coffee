Scribe = require('./scribe')


class Scribe.Selection
  @SAVED_CLASS = 'saved-selection'

  constructor: (@editor) ->
    @range = null
    this.initListeners()
    @editor.renderer.runWhenLoaded( =>
      @nativeSelection = @editor.contentWindow.getSelection()
      this.setRange(new Scribe.Range(@editor, 0, 0))    # Range gets set to end of doc in Firefox by default
    )

  initListeners: ->
    checkUpdate = =>
      this.update() if @editor.root.isContentEditable
    keyUpdate = (event) =>
      checkUpdate() if Scribe.Keyboard.KEYS.LEFT <= event.which and event.which <= Scribe.Keyboard.KEYS.DOWN
    @editor.root.addEventListener('keyup', keyUpdate)
    @editor.root.addEventListener('mouseup', checkUpdate)

  format: (name, value, options = {}) ->
    this.update()
    return unless @range
    start = @range.start.index
    end = @range.end.index
    formats = @range.getFormats()
    @editor.formatAt(start, end - start, name, value, options) if end > start
    formats[name] = value
    @range.formats = formats
    this.setRange(new Scribe.Range(@editor, start, end))

  deleteRange: ->
    this.update()
    return false if @range.isCollapsed()
    @editor.deleteAt(@range.start.index, @range.end.index - @range.start.index)
    this.update()
    return @range

  getNativeRange: ->
    return if @nativeSelection?.rangeCount > 0 then @nativeSelection.getRangeAt(0) else null

  getRange: ->
    nativeRange = this.getNativeRange()
    return null unless nativeRange?
    start = new Scribe.Position(@editor, nativeRange.startContainer, nativeRange.startOffset)
    end = new Scribe.Position(@editor, nativeRange.endContainer, nativeRange.endOffset)
    if nativeRange.compareBoundaryPoints(Range.START_TO_END, nativeRange) > -1
      return new Scribe.Range(@editor, start, end)
    else
      return new Scribe.Range(@editor, end, start)

  preserve: (fn) ->
    nativeRange = this.getNativeRange()
    if nativeRange?
      startLineNode = Scribe.Utils.findAncestor(nativeRange.startContainer, Scribe.Line.isLineNode)
      endLineNode = Scribe.Utils.findAncestor(nativeRange.endContainer, Scribe.Line.isLineNode)
      startOffset = Scribe.Position.getIndex(nativeRange.startContainer, nativeRange.startOffset, startLineNode)
      endOffset = Scribe.Position.getIndex(nativeRange.endContainer, nativeRange.endOffset, endLineNode)
      savedNativeRange = _.clone(nativeRange)
      fn()
      nativeRange = this.getNativeRange()
      if !_.isEqual(_.clone(nativeRange), savedNativeRange)
        start = new Scribe.Position(@editor, startLineNode, startOffset)
        end = new Scribe.Position(@editor, endLineNode, endOffset)
        this.setRange(new Scribe.Range(@editor, start, end))
    else
      fn()

  setRange: (range, silent = false) ->
    return unless @nativeSelection?
    this.update(true)
    return if range == @range or @range?.equals(range)
    @range = range
    @nativeSelection.removeAllRanges()
    if @range?
      nativeRange = @editor.root.ownerDocument.createRange()
      _.each([@range.start, @range.end], (pos, i) ->
        [node, offset] = Scribe.DOM.findDeepestNode(pos.leafNode, pos.offset)
        fn = if i == 0 then 'setStart' else 'setEnd'
        nativeRange[fn].call(nativeRange, node, offset)
      )
      @nativeSelection.addRange(nativeRange)
    @editor.emit(Scribe.Editor.events.SELECTION_CHANGE, @range) unless silent

  update: (silent = false) ->
    range = this.getRange()
    unless range == @range or @range?.equals(range)
      @editor.emit(Scribe.Editor.events.SELECTION_CHANGE, range) unless silent
      @range = range


module.exports = Scribe
