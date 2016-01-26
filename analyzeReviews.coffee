MongoClient = require('mongodb').MongoClient
assert = require 'assert'
retext = require 'retext'
spell = require 'retext-spell'
profanities = require 'retext-profanities'
intensify = require 'retext-intensify'
readability = require 'retext-readability'
dict = require 'dictionary-en-gb'
report = require 'vfile-reporter'

dburl = 'mongodb://localhost:27017/reviews'

class Analysis
    constructor: (@review, @targetCollection) ->
        @run()
    run: =>
        retext().use(readability).use(intensify).use(profanities).use(spell, dict).process @review.text, (err, file) =>
            # insert text metadata
            @review.textMetaData = {}
            @review.textMetaData.characterCount = @review.text.length
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

            # notify user
            console.log 'Analyzed review', @review._id

            # insert
            @targetCollection.insert @review


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
    MongoClient.connect dburl, (err, db) ->
        assert.equal(null, err)
        rawdataCollection = db.collection('reviews')
        productCollection = db.collection('products')
        targetCollection = db.collection('analyzedReviews')
        productCollection.find().toArray (err, res) ->
            products = {}
            for product in res
                products[product._id] = product

            rawdataCollection.find().toArray (err, res) ->
                for review in res
                    review.product = products[review.productId]
                    new Analysis review, targetCollection
