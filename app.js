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




var analyzeReviews = function() {
    MongoClient.connect(dburl, function (err, db) {
        assert.equal(null, err);
        var rawdataCollection = db.collection('reviews');
        var productCollection = db.collection('products');
        var targetCollection = db.collection('analyzedReviews');
        productCollection.find().toArray(function (err, res) {
            products = {}
            for (var product of res){
                products[product._id] = product
            }

            rawdataCollection.find().toArray(function(err, res) {
                for (var rawReview of res){
                    var processedReview = rawReview;
                    var retextResults = {};
                    processedReview.languageMetaData = {};
                    processedReview.product = products[processedReview.productId];

                    retext().use(readability).process(processedReview.text, function (err, file) {
                        retextResults.readability = file.messages.length;
                    });
                    retext().use(profanities).process(processedReview.text, function (err, file) {
                        retextResults.profanities = file.messages.length;
                    });

                    retext().use(spell, dict).process(processedReview.text, function (err, file) {
                        retextResults.spell = file.messages.length;
                    });

                    retext().use(intensify).process(processedReview.text, function (err, file) {
                        retextResults.intensity = file.messages.length;
                    });






                    processedReview.languageMetaData.issues = retextResults;
                    processedReview.languageMetaData.characterCount = processedReview.text.length;
                    processedReview.languageMetaData.wordCount = processedReview.text.split(' ').length;
                    processedReview.languageMetaData.avgWordLength = processedReview.languageMetaData.characterCount / processedReview.languageMetaData.wordCount;
                    processedReview.languageMetaData.profanityDensity = processedReview.languageMetaData.issues.profanities / processedReview.languageMetaData.wordCount * 100;

                    delete processedReview.text;
                    processedReview.votes.quota = rawReview.votes.helpful / rawReview.votes.total
                    targetCollection.insert(processedReview);
                    console.log('analyzed review')
                }
                db.close()
            });
        });
    });
}

// analyzeReviews();
scrapeProducts(products);
