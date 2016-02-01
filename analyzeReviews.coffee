MongoClient = require('mongodb').MongoClient
assert      = require 'assert'
retext      = require 'retext'
spell       = require 'retext-spell'
profanities = require 'retext-profanities'
intensify   = require 'retext-intensify'
readability = require 'retext-readability'
sentiment   = require 'retext-sentiment'
dict        = require 'dictionary-en-gb'
report      = require 'vfile-reporter'
fs          = require 'fs'
crypto      = require 'crypto'

dburl = 'mongodb://localhost:27017/reviews'

class Analysis
    constructor: (@review, @targetCollection) ->
        @run()
    run: =>
        require('retext')().use(readability).use(intensify).use(profanities).use(spell, dict).use(sentiment).use(=> (cst) => @review.sentiment = cst.data.polarity).process @review.text, (err, file) =>
            # insert text metadata
            @review.textMetaData = {}
            @review.textMetaData.characterCount = @review.text.length
            @review.textMetaData.titleLength = @review.title.length
            @review.textMetaData.wordCount = @review.text.split(' ').length
            @review.textMetaData.averageWordLength = @review.textMetaData.characterCount / @review.textMetaData.wordCount

            # insert detected language issues
            @review.languageIssues = {}
            @review.languageIssues.absolute = @mapIssues file.messages
            @review.languageIssues.density = {}

            # calculate language issue density
            for issue, occurences of @review.languageIssues.absolute
                @review.languageIssues.density[issue] = 100 * occurences / @review.textMetaData.wordCount

            # calculate additional meta data
            @review.votes.quota = @review.votes.helpful / @review.votes.total

            rawId = @review.id + @review.text + @review.date.toString()
            # insert
            @targetCollection.insert @review

            # notify user
            process.stdout.write '.', @review[@review._id.length - 1]



    mapIssues: (messages) =>
        # predefined index
        issueIndex =
            intensify: 0
            spell: 0
            profanities: 0
            readability: 0

        for issue in messages
            # determine type
            if issue.source?
                issueId = issue.source
            else if !issue.ruleId?
                issueId = 'retext-readability'
            else
                issueId = issue.ruleId
            issueId = issueId.substr 7, issueId.length - 1

            # add or increment
            issueIndex[issueId]++
        issueIndex



analyze = =>
    MongoClient.connect dburl, (err, db) =>
        assert.equal(null, err)
        rawdataCollection = db.collection('reviews')
        productCollection = db.collection('products')
        targetCollection = db.collection('analyzedReviews')
        productCollection.find().toArray (err, res) ->
            products = {}
            for product in res
                if products[product.id]?
                    products[product.id].price = product.price if product.price > products[product.id].price
                    products[product.id].salePrice = product.salePrice if product.salePrice > products[product.id].salePrice
                else 
                    products[product.id] = product
            for batchNumber in [0..1000]
                # build query object
                ((batchNumber) =>
                    setTimeout (=>
                        console.log()
                        console.log()
                        console.log 'starting batch', batchNumber
                        targetCollection.find().toArray (err, res) ->
                            analyzedIds = []
                            for analyzed in res
                                analyzedIds.push analyzed._id
                            #analyzedIds.splice 100, 10000000
                            # process batch, request raw data for each batch
                            queryObject =
                                _id:
                                    '$nin': analyzedIds
                            cursor = rawdataCollection.find(queryObject)
                            cursor.count().then (count) ->
                                console.log 'MISSING', count
                            cursor.limit(20).toArray (err, res) =>
                                for review in res
                                    review.product = products[review.productId]
                                    new Analysis(review, targetCollection) 
                    ), 4000 * batchNumber
                )(batchNumber)

analyze()
