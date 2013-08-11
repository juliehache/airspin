#= require jquery.min
#= require leap
#= require mousetrap
#= require_self


window.AirSpin =
  init: ->
    window.AudioContext = window.AudioContext || window.webkitAudioContext
    @context = new AudioContext()

    @buffers = new Array()
    @left = new AirSpin.Track()
    @right = new AirSpin.Track()

    @leap = new Leap.Controller()

    @crossfaderWrapper = document.getElementById("crossfader-wrapper")

  modes:
    crossFader:
      handleFrame: (frame) ->
        $('#crossfader').val(@value * 200) if @value
        if AirSpin.left?.source
          rate = AirSpin.left.source.playbackRate.value
          $('#left-playbackrate').html(Math.round(rate * 100) / 100).css("background", "")
        if AirSpin.right?.source
          rate = AirSpin.right.source.playbackRate.value
          $('#right-playbackrate').html(Math.round(rate * 100) / 100).css("background", "")
        AirSpin.crossfaderWrapper.style.background = ''
        for hand in frame.hands
          if hand.palmPosition[0] < 100 && hand.palmPosition[0] > -100
            @leapCrossfade(hand.palmPosition)
          else if hand.palmPosition[0] < -150
            @playbackRate("left", hand.palmPosition)
          else if hand.palmPosition[0] > 150
            @playbackRate("right", hand.palmPosition)

      leapCrossfade: (values) ->
        x = values[0]
        max = 200

        val = x + (max / 2)

        return if val > max || val < 0
        $('#crossfader').val(val)
        return if values[2] > 50
        AirSpin.crossfaderWrapper.style.background = 'green'
        value = val / max
        @crossfade(value)

      handleEvent: (value, max) ->
        x = parseInt(value) / parseInt(max);
        @crossfade(x)

      crossfade: (value) ->
        @value = value
        AirSpin.left.gainNode.gain.value = Math.cos(value * 0.5*Math.PI)
        AirSpin.right.gainNode.gain.value = Math.cos((1.0 - value) * 0.5*Math.PI)

      playbackRate: (trackName, values) ->
        track = AirSpin[trackName]
        return if values[1] < 200
        y = values[1] - 200

        rate = y /100
        $("##{trackName}-playbackrate").html(Math.round(rate * 100) / 100)
        return if values[2] > 50
        $("##{trackName}-playbackrate").css("background", "green")
        if track.source
          track.source.playbackRate.value = rate


    trackOne: {}
    trackTwo: {}
    off: {}

  currentModeName: 'crossFader'

  currentMode: ->
    @modes[@currentModeName]

  leap: {}

  audioContext: {}

  load: (urlList) ->
    bufferLoader = new AirSpin.BufferLoader @context, urlList, (buffers) =>
      @buffers = @buffers.concat(buffers)

      @left.setBuffer(@buffers[0])
      @right.setBuffer(@buffers[1])

      @left.gainNode.gain.value = 1
      @right.gainNode.gain.value = 0

      @left.play()
      @right.play()
    bufferLoader.load()


class AirSpin.Track
  constructor: ->
    @context = AirSpin.context
    @gainNode = @context.createGain()
    @gainNode.connect(@context.destination)

  setBuffer: (buffer) ->
    @source?.disconnect()
    delete @source
    delete @startTime
    delete @stopTime
    @buffer = buffer

  togglePlay: ->
    if @isPlaying()
      @pause()
    else
      @play()

  play: ->
    # return if @isPlaying()
    @source?.disconnect()
    delete @source

    @source = @createSource()
    @source.start(0, @playOffset())
    @startTime = @context.currentTime - @playOffset()
    delete @stopTime

  createSource: ->
    source = @context.createBufferSource()
    source.buffer = @buffer
    source.loop = true
    source.connect(@gainNode)
    source

  pause: ->
    @stopTime = @context.currentTime
    @source.stop(0)

  isPlaying: ->
    @startTime && !@stopTime

  playOffset: ->
    if @stopTime && @startTime
      @stopTime - @startTime
    else
      0


class AirSpin.BufferLoader
  constructor: (@context, @urlList, @onload) ->
    @bufferList = new Array()
    @loadCount = 0

  loadBuffer: (url, index) ->
    request = new XMLHttpRequest()
    request.open("GET", url, true)
    request.responseType = "arraybuffer"

    request.onload = =>
      # Asynchronously decode the audio file data in request.response
      @context.decodeAudioData(
        request.response
        ,
        (buffer) =>
          if !buffer
            alert "error decoding file data: #{url}"
            return
          @bufferList[index] = buffer;
          if ++@loadCount == @urlList.length
            @onload(@bufferList)
        ,
        (error) =>
          console.error('decodeAudioData error', error)
      )

    request.onerror = ->
      alert 'BufferLoader: XHR error'

    request.send()

  load: ->
    for url, i in @urlList
      @loadBuffer(url, i)

$ ->
  AirSpin.init()

  $('#crossfader').on 'change', ->
    AirSpin.modes.crossFader.handleEvent?($(this).val(), this.max)

  $('#left-play').on 'click', ->
    AirSpin.left.togglePlay()

  $('#right-play').on 'click', ->
    AirSpin.right.togglePlay()

  AirSpin.load ['../audio/polish_girl.m4a', '../audio/true_loves.m4a']

  AirSpin.leap.on 'connect', ->
    console.log "Successfully connected."

  AirSpin.leap.on 'deviceConnected', ->
    console.log "A Leap device has been connected."

  AirSpin.leap.on 'deviceDisconnected', ->
    console.log "A Leap device has been disconnected."

  positionInputs = (document.getElementById(id) for id in ["leap-x", "leap-y", "leap-z"])
  AirSpin.leap.on 'frame', (frame) ->
    if frame.hands.length > 0
      for n, i in frame.hands[0].palmPosition
        positionInputs[i].value = parseInt(n)
    AirSpin.currentMode().handleFrame?(frame)

  AirSpin.leap.connect();
