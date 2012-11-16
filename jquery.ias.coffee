
do (jQuery) ->
  $.ias = (options) ->
    #setup
    opts = $.extend {}, $.ias.defaults, options
    util = new $.ias.util()
    paging = new $.ias.paging(opts.scrollContainer)
    hist = if opts.history then new $.ias.history() else false
    _self = @


    hide_pagination = -> 
      $(opts.pagination).hide()


    get_scroll_treshold = (pure) ->
      el = $(opts.container).find(opts.item).last()

      return 0 if el.size() == 0

      treshold = el.offset().top + el.height()

      unless pure
        treshold += opts.tresholdMargin

      treshold       


    scroll_handler = ->
      #the way we calculate if have to load the next page depend on which container we have
      if opts.scrollContainer == $.ias.defaults.scrollContainer
        scrTop = opts.scrollContainer.scrollTop()
      else
        scrTop = opts.scrollContainer.offset().top

      wndHeight = opts.scrollContainer.height()

      curScrOffset = scrTop + wndHeight;

      if curScrOffset >= get_scroll_treshold()
        paginate curScrOffset


    reset = ->
      hide_pagination()

      opts.scrollContainer.scroll scroll_handler


    stop_scroll = -> 
      opts.scrollContainer.unbind 'scroll', scroll_handler     



    init = () ->
      paging.onChangePage = (pageNum, scrollOffset, pageUrl) ->
        hist.setPage pageNum, pageUrl if hist

        # call onPageChange event
        opts.onPageChange.call @, pageNum, pageUrl, scrollOffset

      # setup scroll and hide pagination
      reset()

      # load and scroll to previous page
      if hist and hist.havePage()
        stop_scroll()
        
        pageNum = hist.getPage()

        util.forceScrollTop () ->
          if pageNum > 1
            paginateToPage pageNum

            curTreshold = get_scroll_treshold true
            $("html,body").scrollTop curTreshold
          else
            reset()

      _self


    #initialize
    init()


    paginate = (curScrOffset, onCompleteHandler) ->
      urlNextPage = $(opts.next).attr "href"

      unless urlNextPage
        return stop_scroll()

      if opts.beforePageChange and $.isFunction opts.beforePageChange
        return if opts.beforePageChange(curScrOffset, urlNextPage) is false

      paging.pushPages curScrOffset, urlNextPage

      stop_scroll()
      show_loader()

      loadItems urlNextPage, (data, items) ->
        # call the onLoadItems callback
        result = opts.onLoadItems.call @, items

        if result isnt false
          $(items).hide()     # at first, hide it so we can fade it in later

          # insert them after the last item with a nice fadeIn effect
          curLastItem = $(opts.container).find(opts.item).last()
          curLastItem.after(items)
          $(items).fadeIn()


          # update pagination
          $(opts.pagination).replaceWith $(opts.pagination, data)

          remove_loader()
          reset()
                 
          # call the onRenderComplete callback
          opts.onRenderComplete.call @, items

          onCompleteHandler.call @ if onCompleteHandler


    loadItems = (url, onCompleteHandler) ->
      items = []

      $.get url, null, (data) ->
        # walk through the items on the next page
        # and add them to the items array
        container = $(opts.container, data).eq(0)

        if 0 == container.length
          # incase the element is a root element (body > element),
          # try to filter it
          container = $(data).filter(opts.container).eq(0)

        if container
          container.find(opts.item).each ->
            items.push @

        onCompleteHandler.call @, data, items if onCompleteHandler
      , 'html'


    paginateToPage = (pageNum) ->
      curTreshold = get_scroll_treshold true

      if curTreshold > 0
        paginate curTreshold, ->
          stop_scroll()

          if (paging.getCurPageNum(curTreshold) + 1) < pageNum
            paginateToPage pageNum

            $("html,body").animate "scrollTop": curTreshold, 400, "swing"
          else
            $("html,body").animate "scrollTop": curTreshold, 1000, "swing"
            
            reset()


    get_loader = ->
      loader = $(".ias_loader")

      if loader.size() == 0
        loader = $("<div class='ias_loader'>"+opts.loader+"</div>")
        loader.hide()

      return loader


    show_loader = ->
      loader = get_loader()

      if opts.customLoaderProc isnt false
        opts.customLoaderProc loader
      else
        el = $(opts.container).find(opts.item).last()
        el.after loader
        loader.fadeIn()


    remove_loader = ->
      loader = get_loader()
      loader.remove()


    debug = ($obj) ->
      window.console.log $obj if window.console and window.console.log


  # plugin defaults
  $.ias.defaults = {
                    container : '#container', 
                    scrollContainer : $(window), 
                    item : '.item', 
                    pagination : '#pagination', 
                    next : '.next', 
                    loader : '<img src="images/loader.gif"/>', 
                    tresholdMargin : 0, 
                    history : true, 
                    onPageChange : ->
                      , 
                    beforePageChange : ->
                      , 
                    onLoadItems : ->
                      , 
                    onRenderComplete : ->
                      , 
                    customLoaderProc : false 
                  }


  # utility module
  $.ias.util = ->
    # setup
    wndIsLoaded = false
    forceScrollTopIsCompleted = false
    self = @

    init = ->
      $(window).load ->
        wndIsLoaded = true

    # initialize
    init()

    @.forceScrollTop = (onCompleteHandler) ->
      $("html,body").scrollTop 0

      unless forceScrollTopIsCompleted
        unless wndIsLoaded
          setTimeout ->
            self.forceScrollTop onCompleteHandler
          , 1
        else
          onCompleteHandler.call()
          forceScrollTopIsCompleted = true



  # paging module
  $.ias.paging = ->
    # setup
    pagebreaks = [[0, document.location.toString()]]
    changePageHandler = ->
    lastPageNum = 1


    getCurPageNum = ->
      pbs = pagebreaks.length-1
      while(pbs > 0)
        return pbs + 1 if scrollOffset > pagebreaks[pbs][0]      
        pbs -= 1    

      return 1


    @.getCurPageNum = (scrollOffset) ->
      getCurPageNum scrollOffset      


    getCurPagebreak = (scrollOffset) ->
      pbs = pagebreaks.length-1
      while(pbs >= 0)
        return pagebreaks[pbs] if scrollOffset > pagebreaks[pbs][0]
        pbs -= 1

      return null      


    @.onChangePage = (fn) ->
      changePageHandler = fn      


    @.pushPages = (scrollOffset, urlNextPage) ->
      pagebreaks.push [scrollOffset, urlNextPage]


    scroll_handler = ->
      scrTop = $(window).scrollTop()
      wndHeight = $(window).height()

      curScrOffset = scrTop + wndHeight

      curPageNum = getCurPageNum curScrOffset
      curPagebreak = getCurPagebreak curScrOffset

      if lastPageNum != curPageNum
        changePageHandler.call @, curPageNum, curPagebreak[0], curPagebreak[1] # @todo fix for window height
      
      lastPageNum = curPageNum;           


    init = ->
      $(window).scroll scroll_handler


    # initialize
    init()
    undefined



  $.ias.history = () ->
    # setup
    isPushed = false
    isHtml5 = false


    # initialize
    init()


    init = ->
      isHtml5 = !!(window.history && history.pushState && history.replaceState)
      isHtml5 = false         # html5 functions disabled due to problems in chrome


    @.setPage = (pageNum, pageUrl) ->
      @.updateState page : pageNum, "", pageUrl


    @.havePage = ->
      return @.getState() != false


    @.getPage = ->
      if @.havePage()
        stateObj = @.getState()
        return stateObj.page
            
      return 1


    @.getState = ->
      if isHtml5
        stateObj = history.state
        if stateObj and stateObj.ias then return stateObj.ias
      else
        haveState = (window.location.hash.substring(0, 7) == "#/page/")
        if haveState
          pageNum = parseInt window.location.hash.replace("#/page/", "")
          return page : pageNum

      return false


    @.updateState = (stateObj, title, url) ->
      if isPushed
        @.replaceState stateObj, title, url
      else
        @.pushState stateObj, title, url


    @.pushState = (stateObj, title, url) ->
      if isHtml5
        history.pushState ias : stateObj, title, url
      else
        hash = if stateObj.page > 0 then "#/page/" + stateObj.page else ""
        window.location.hash = hash

      isPushed = true


    @.replaceState = (stateObj, title, url) ->
      if isHtml5
        history.replaceState ias : stateObj, title, url
      else
        @.pushState stateObj, title, url

  








