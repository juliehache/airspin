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

  modes:
    crossFader:
      handleFrame: (frame) ->
        if frame.hands.length > 0
          hand = frame.hands[0]
          x = hand.palmPosition[0]
          max = 200

          val = x + (max / 2)
          return if val > max || val < 0

          value = val / max
          $('#crossfader').val(val)
          @crossfade(value)

      handleEvent: (value, max) ->
        x = parseInt(value) / parseInt(max);
        @crossfade(x)

      crossfade: (value) ->
        # update UI
        AirSpin.left.gainNode.gain.value = Math.cos(value * 0.5*Math.PI)
        AirSpin.right.gainNode.gain.value = Math.cos((1.0 - value) * 0.5*Math.PI)

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
    createSource = =>
      source = @context.createBufferSource()
      source.buffer = buffer
      source.loop = true
      source

    @source?.disconnect()
    @source = createSource()
    @source.connect(@gain)

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

  AirSpin.load ['../audio/polish_girl.m4a', '../audio/true_loves.m4a']

  AirSpin.leap.on 'connect', ->
    console.log "Successfully connected."

  AirSpin.leap.on 'deviceConnected', ->
    console.log "A Leap device has been connected."

  AirSpin.leap.on 'deviceDisconnected', ->
    console.log "A Leap device has been disconnected."

  AirSpin.leap.on 'frame', (frame) ->
    AirSpin.currentMode().handleFrame?(frame)

  AirSpin.leap.connect();
