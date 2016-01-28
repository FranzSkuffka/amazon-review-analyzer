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
    constructor: (@review, @targetCollection, @reviewNumber) ->
        @run()
    run: =>
        retext().use(readability).use(intensify).use(profanities).use(spell, dict).use(sentiment).use(=> (cst) => @review.sentiment = cst.data.polarity).process @review.text, (err, file) =>
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

            # clean
            delete @review.text
            delete @review.productId

            @review._id = crypto.createHash('md5').update(@review.id + @review.wordCount + @review.date.toString()).digest('hex')
            rawId = @review.id + @review.text + @review.date.toString()
            # insert
            @targetCollection.insert @review

            # notify user
            console.log 'Analyzed review', @review.id, @reviewNumber



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



module.exports = ->
    fs.readFile 'completedBatch', 'utf8', (err, batchNo) ->
        console.log batchNo
        MongoClient.connect dburl, (err, db) =>
            assert.equal(null, err)
            rawdataCollection = db.collection('reviews')
            productCollection = db.collection('products')
            targetCollection = db.collection('analyzedReviews')
            productCollection.find().toArray (err, res) ->
                products = {}
                delayFactor = 0
                for product in res
                    products[product.id] = product
                for i in [batchNo .. 1000]
                    delayFactor++
                    ((i, delayFactor) =>
                        cursor = rawdataCollection.find()
                        setTimeout( =>
                            batchSize = 5
                            fs.writeFile('completedBatch', i - 5) if i > 4
                            console.log 'Analyzing batch', i, 'of', 5000/batchSize
                            cursor.skip(batchSize * i).limit(batchSize).toArray (err, res) ->
                                for review, reviewNumber in res
                                    review.product = products[review.productId]

                                    ((review, i) =>
                                        setTimeout( =>
                                            new Analysis(review, targetCollection, i)
                                        ,
                                        i * 50))(review, reviewNumber)
                        ,
                        delayFactor * 500))(i, delayFactor)
