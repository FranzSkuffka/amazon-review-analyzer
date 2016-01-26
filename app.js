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


var scraper = new Scraper()

var dburl = 'mongodb://localhost:27017/reviews'

var products = [
    // 'http://www.amazon.com/Amazon-W87CUN-Fire-TV-Stick/dp/B00GDQ0RMG/ref=cm_cr_pr_product_top?ie=UTF8'
    'http://www.amazon.com/Ozeri-Digital-Multifunction-Kitchen-Elegant/dp/B004164SRA/ref=zg_bs_kitchen_2'
    // 'http://www.amazon.com/Blue-Microphones-Yeti-USB-Microphone/dp/B002VA464S/ref=zg_bs_musical-instruments_11'
]
var scrapeProducts = function (products) {
    var opts = {
        pageChunks: {
            start: 10,
            middle: 0,
            end: 0
        },
        sortOrder: 'helpful'
    }
    for (var url of products) {
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
                    console.log('inserted review')
                }
                });
        });
    }
};






// analyzeReviews();
// scrapeProducts(products);
