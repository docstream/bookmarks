mongoose = require 'mongoose'
_ = require 'underscore'

MODID = "BOOKMARK"

class BookmarkService
  Bookmark = null

  constructor: (url) ->
    @conn = mongoose.createConnection url
    monitorConn @conn

    Bookmark = require('./model/bookmark-model')(@conn)

    @viewHelpers = [
      {name: 'myBookmarks', fn: @myRecords}
    ]

  close: ->
    @conn.close()

  # View helper for listing of my records, DO NOT USE anywhere else!
  myRecords: (options, cb) =>
    query = {
      page: options.page
      max: options.max
    }

    params = {
      endUser: options.userId
      domainName: options.domainName
    }

    Bookmark.search params, query, (err, result) =>
      if err
        cb err
      else
        bookmarks = if query.page then result.bookmarks else result
        embedParams =
          paging: (if query.page then true else false)
          totalCount: result.totalCount
          page: result.page
          pageSize: result.pageSize
          filter: if query.filter then query.filter else ""

        cb null, appendSearchData(bookmarks, embedParams)


  # data = { see model }
  # params = {
  #   userId: String(ObjectId)
  # }
  # cbHash = {
  #   MODEL_ERR: cb(err)
  #   DEFAULT: cb(res)
  # }
  create: (data, params, cbHash) ->
    bookmarkData = data
    bookmarkData.endUser = params.userId

    Bookmark.create bookmarkData, (err, bookmark) ->
      if err
        cbHash.MODEL_ERR err
      else
        cbHash.DEFAULT {data: bookmark.toObject()}

  # cbHash = {
  #   MODEL_ERR: cb(err)
  #   NOT_FOUND: cb()
  #   DEFAULT: cb(res)
  # }
  findSingle: (id, userId, cbHash) ->
    params = {
      endUser: userId
      _id: id
    }

    Bookmark.findSingle params, (err, bookmark) ->
      if err
        cbHash.MODEL_ERR err
      else if bookmark == null
        cbHash.NOT_FOUND()
      else
        cbHash.DEFAULT {data: bookmark.toObject()}

  # cbHash = {
  #   MODEL_ERR: cb(err)
  #   NOT_FOUND: cb()
  #   DELETED: cb()
  # }
  delete: (id, userId, cbHash) ->
    query =
      _id: id
      endUser: userId

    Bookmark.findOne query, (err, bookmark) ->
      if err
        cbHash.MODEL_ERR err
      else if bookmark == null
        cbHash.NOT_FOUND()
      else
        bookmark.remove (err) ->
          if err
            cbHash.MODEL_ERR err
          else
            cbHash.DELETED()

  # cbHash = {
  #   MODEL_ERR: cb(err)
  #   DELETED: cb()
  # }
  deleteUser: (userId, domainName, cbHash) ->
    query =
      endUser: userId
      domainName: domainName

    Bookmark.remove query, (err) ->
      if err
        cbHash.MODEL_ERR err
      else
        cbHash.DELETED()


  # params = {
  #   userId: String(ObjectId)
  #   domainName: String
  # }
  # cbHash = {
  #   MODEL_ERR: cb(err)
  #   DEFAULT: cb(res)
  # }
  overview: (encHref, params, cbHash) ->
    modParams =
      urlFragFree: decodeURIComponent(encHref)
      endUser: params.userId.toString()
      domainName: params.domainName

    Bookmark.overview modParams, (err, result) ->
      if err
        cbHash.MODEL_ERR err
      else
        totalCount = 0
        cleanedResult = {}
        _.each result, (row) ->
          console.log 'row ', row
          totalCount += row.count
          cleanedResult[row._id] = {fragmIdentUrl: '#' + row._id, count:  row.count }

        cbHash.DEFAULT {data: {totalCount: totalCount}, embeds: {ids:  cleanedResult }}


  # params = {
  #   userId: String(ObjectId)
  #   domainName: String
  # }
  # cbHash = {
  #   MODEL_ERR: cb(err)
  #   DEFAULT: cb(res)
  # }
  search: (query, params, cbHash) ->
    params =
      endUser: params.userId
      domainName: params.domainName

    Bookmark.search params, query, (err, result) =>
      if err
        cbHash.MODEL_ERR err
      else
        bookmarks = if query.page then result.bookmarks else result
        embedParams =
          paging: (if query.page then true else false)
          totalCount: result.totalCount
          page: result.page
          pageSize: result.pageSize
          filter: if query.filter then query.filter else ""

        cbHash.DEFAULT appendSearchData(bookmarks, embedParams)




  #Privates
  appendSearchData = (bookmarks, params) ->
    if params.paging
      radix = 10
      totalCount = parseInt(params.totalCount, radix)
      page = parseInt(params.page, radix)
      pageSize = parseInt(params.pageSize, radix)
      nextPage = if (totalCount - (page * pageSize) > 0) then page + 1 else page
      prevPage = if page == 1 then page else page - 1

      data:
        totalCount: totalCount or 0,
        currentPage: page or 0,
        pageSize: pageSize or 0,
        pageCount: Math.ceil(totalCount/pageSize) or 0,
        nextPage: nextPage,
        prevPage: prevPage
        pageFilter: params.filter

      embeds:
        bookmarks : _.map bookmarks, (bookmark) ->
          bookmark.toObject()
    else
      embeds:
        bookmarks : _.map bookmarks, (bookmark) ->
          bookmark.toObject()

module.exports.BookmarkService = BookmarkService

monitorConn = (conn) ->
  conn.on 'error' , (err) ->
    console.error "#{MODID} ERROR conn :",err
  conn.on 'connected', ->
    console.log "#{MODID}: connected via mongoose."
  conn.on 'disconnected', ->
    console.warn "#{MODID}: disconnected via mongoose."
  #global guard:
  process.on 'SIGINT',->
    conn.connection.close ->
      console.log "#{MODID}: closed via SIGINT"
      process.exit 0
