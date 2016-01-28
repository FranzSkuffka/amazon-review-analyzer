import Scraper from '../amazon-review-scraper/'
import {MongoClient} from 'mongodb'
import assert from 'assert'
import retext from 'retext'
import spell from 'retext-spell'
import profanities from 'retext-profanities'
import intensify from 'retext-intensify'
import readability from 'retext-readability'
import dict from 'dictionary-en-gb'
import report from 'vfile-reporter'
import analyzeStuff from './analyzeReviews.coffee'
import fs from 'fs'


var scraper = new Scraper()

var dburl = 'mongodb://localhost:27017/reviews'

var departments = [
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

MongoClient.connect(dburl, function (err, db) {
var productCount = 1;
var reviewCount = 1;
var scrapeProduct = function (url) {
    var opts = {
        pageChunks: {
            start: 5,
            middle: 0,
            end: 0
        },
        sortOrder: 'helpful'
    }
        scraper.scrapeProduct(url).then(function (productData) {
            var collection = db.collection('products');
            collection.insert(productData);
            console.log('inserted product no', productData.id, productCount)
            productCount++;
        });
        scraper.scrapeProductReviews(url, opts).then(function (reviews) {
            var collection = db.collection('reviews');
            for (var review of reviews){
                collection.insert(review);
                console.log('inserted review',review.id,reviewCount)
                reviewCount++;
            }
        });
};


// scrapeProduct(url);

var scrapeDepartment = function (url) {
    console.log('scraping', url);
    scraper.getDepartmentProductUrls(url, 0)
        .then((urls) =>
            {
                for (var productUrl of urls){
                    scrapeProduct(productUrl)
                }
            })
}

var exportData = function (collectionId) {
    MongoClient.connect(dburl, function (err, db) {
        var sourceCollection = db.collection(collectionId);
        sourceCollection.find().toArray( function(err, res) {
            console.log(res.length);
            fs.writeFile(collectionId + '_' + (new Date()).toString() + '.json', JSON.stringify(res), function (err) {
                  if (err) return console.log(err);
                  console.log('Exported ' + collectionId);
            });
        });
    });
};



// console.log('analyzing');
// analyzeStuff();
exportData('reviews');
exportData('analyzedReviews');
// exportData();
// scrapeDepartment(departments[0])
});
