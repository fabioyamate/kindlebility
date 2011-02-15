Fs = require('fs')
Url = require('url')
Sys = require('sys')
Query = require('querystring')
Readability = require('./readability/lib/readability')
Spawn = require('child_process').spawn
Request = require('request')
Promise = require('./promised-io/lib/promise')
Config = JSON.parse(Fs.readFileSync('config.json', 'utf8'))
Postmark = 'http://api.postmarkapp.com/email'
UserAgent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_5; en-US) AppleWebKit/534.10 (KHTML, like Gecko) Chrome/8.0.552.215 Safari/534.10"
Mysql = require('mysql').Client
mysql = new Mysql

mysql.user = 'root'
mysql.password = ''

error = (client, msg) ->
  Sys.puts("ERROR: #{msg}")
  client.send(msg)
  client.send('done')

RetrievePage = (args) ->
  client = args.client
  client.send('Retrieving page...')
  defer = new Promise.defer()
  options = {
    uri: args.url,
    headers: {
      'User-Agent': UserAgent
    }
  }
  Request options, (err, response, body) ->
    if err?
      msg = 'Failed to retrieve page.'
      error(client, msg)
      defer.reject(msg)
    else
      defer.resolve({
        client: client,
        response: response,
        body: body,
        url: args.url,
        to: args.to
      })
  defer

RunReadability = (args) ->
  client = args.client
  client.send('Processing...')
  defer = new Promise.defer()
  console.log(args.response.headers)
  Readability.parse args.body, args.url, (result) ->
    if result.error
      msg = 'Failed running Readability'
      error(client, msg)
      defer.reject(msg)
    else
      console.log(result);
      defer.resolve({
        client: client,
        url: args.url,
        result: result,
        to: args.to,
        content_type: args.response.headers['content-type']
      })
  defer

Saving = (args) ->
  client = args.client
  client.send('Saving...')
  defer = new Promise.defer()
  filename = Hash.sha1(args.url)
  mysql.connect()
  mysql.query('USE magaziner_development')
  mysql.query("INSERT INTO articles SET title = ?, content = ?, url = ?", [args.result.title, args.result.content, args.url])

  client.send('done')
  Sys.puts("Everything went smoothly.")

exports.verifyParams = (req) ->
  url = Url.parse(req.url)
  return false unless url.query?
  query = Query.parse(url.query)
  query.to? ? true : false

exports.processSocketIO = (args) ->
  sequence = if args.result?
    [
      WriteFile,
      WebkitHtmlToPdf,
      ReadFile,
      SendEmail
    ]
  else
    [
      RetrievePage,
      RunReadability,
      Saving
    ]
  Promise.seq(sequence, args)
