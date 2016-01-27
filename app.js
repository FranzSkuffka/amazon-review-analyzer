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
            MongoClient.connect(dburl, function (err, db) {
                assert.equal(null, err);
                var collection = db.collection('products');
                productData._id = productData.id;
                delete productData.id;
                collection.insert(productData);
                console.log('inserted product')
            });
        });
        scraper.scrapeProductReviews(url, opts).then(function (reviews) {
            MongoClient.connect(dburl, function (err, db) {
                assert.equal(null, err);
                var collection = db.collection('reviews');
                for (var review of reviews){
                    review._id = review.id;
                    delete review.id;
                    collection.insert(review);
                    console.log('inserted review',review._id)
                }
            });
        });
};






// scrapeProduct(url);

var scrapeDepartment = function (url) {
    scraper.getDepartmentProductUrls(url, 10)
        .then((urls) =>
            {
                for (var productUrl of urls){
                    scrapeProduct(productUrl)
                }
            })
}

// scrapeDepartment('http://www.amazon.com/Best-Sellers-Electronics-Office-Products/zgbs/electronics/172574/ref=zg_bs_nav_e_1_e');

for (var index in departments) {
    setTimeout(()=>scrapeDepartment(departments[index]), 5000*index);
}

var exportData = function () {
    MongoClient.connect(dburl, function (err, db) {
        var sourceCollection = db.collection('analyzedReviews');
        sourceCollection.find().toArray( function(err, res) {
                console.log(res.length);
                fs.writeFile('export.json', JSON.stringify(res), function (err) {
                      if (err) return console.log(err);
                      console.log('Exported analyzed reviews > export.json');
                });

            });
    });
};



//analyzeStuff();
// exportData();
