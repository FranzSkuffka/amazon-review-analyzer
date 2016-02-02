Scraper = require '../amazon-review-scraper/'

MongoClient = require('mongodb').MongoClient
assert = require 'assert'
retext = require 'retext'
spell = require 'retext-spell'
profanities = require 'retext-profanities'
intensify = require 'retext-intensify'
readability = require 'retext-readability'
dict = require 'dictionary-en-gb'
report = require 'vfile-reporter'
fs = require 'fs'
crypto = require 'crypto'

dburl = 'mongodb://localhost:27017/reviews'

departments = [
    'http://www.amazon.com/Best-Sellers-Appliances/zgbs/appliances/',
    'http://www.amazon.com/Best-Sellers-Electronics/zgbs/electronics/',
    'http://www.amazon.com/Best-Sellers-Computers-Accessories/zgbs/pc/',
    'http://www.amazon.com/Best-Sellers-Toys-Games/zgbs/toys-and-games/',
    'http://www.amazon.com/Best-Sellers-Patio-Lawn-Garden/zgbs/lawn-garden/',
    'http://www.amazon.com/Best-Sellers-Home-Improvement/zgbs/hi/',
    'http://www.amazon.com/Best-Sellers-Office-Products/zgbs/office-products/',
    'http://www.amazon.com/Best-Sellers-Pet-Supplies/zgbs/pet-supplies/',
    'http://www.amazon.com/Best-Sellers-Kitchen-Dining/zgbs/kitchen/',
    'http://www.amazon.com/Best-Sellers-Industrial-Scientific/zgbs/industrial/'
]

class UrlIterator
    constructor: (@urls, @id, callback) ->
        fs.readFile @id, 'utf8', (err, index) =>
            @index = index
            @index--
            callback()
    hasNext: =>
        if @urls[@index + 1]?
            return true
        else
            fs.writeFile(@id, 0)

    next: =>
        @index++
        fs.writeFile(@id, @index)
        console.log @index, 'of', @urls.length - 1
        @urls[@index]
    current: =>
        @urls[@index]

class DepartmentIterator

    constructor: (@departments, @db, @scraper, @opts) ->
        @departmentUrlIterator = new UrlIterator @departments, 'departments', => @scrapeDepartment()

    # recersive
    scrapeDepartment: =>
        console.log 'scraping department'
        @scraper.scrapeDepartmentBestsellers(@departmentUrlIterator.next()).then (data) =>
            @productUrlIterator = new UrlIterator data.productUrls, 'products', => @scrapeProduct()

    scrapeProduct: =>
        console.log 'scraping product', @productUrlIterator.next()
        @scraper.scrapeProduct(@productUrlIterator.current()).then (productData) =>
            collection = @db.collection('products');
            productData._id = crypto.createHash('md5').update(JSON.stringify(productData)).digest('hex')
            console.log('done')
            console.log()
            console.log()
            collection.insert(productData);
            console.log 'scraping reviews'
            @scraper.scrapeProductReviews(@productUrlIterator.current(), @opts).then (reviews) =>
                collection = @db.collection('reviews');
                console.log('done')
                console.log()
                console.log()
                for review in reviews
                    review._id = crypto.createHash('md5').update(JSON.stringify(review)).digest('hex')
                    collection.insert(review);
                if @productUrlIterator.hasNext()
                    @scrapeProduct()
                else if @departmentUrlIterator.hasNext()
                    console.log('COMPLETED DEPARTMENT__________________________________')
                    console.log()
                    console.log()
                    @scrapeDepartment()

MongoClient.connect dburl, (err, db) ->

    assert.equal(null, err)
    opts =
        sortOrder: 'recent'
        selectionAlgorithm: 'random'
        selectionAlgorithmParams: 30

    exportData = (collectionId) ->
        MongoClient.connect dburl, (err, db) ->
            sourceCollection = db.collection(collectionId);
            sourceCollection.find().toArray  (err, res) ->
                console.log(res.length);
                fs.writeFile collectionId + '_' + (new Date()).toString() + '.json', JSON.stringify(res),  (err) ->
                      console.log('Exported ' + collectionId);
    # new DepartmentIterator(departments, db, new Scraper(), opts)
    exportData('analyzedReviews')
    # exportData('reviews')
