import Scraper from '../amazon-review-scraper/'
import {MongoClient} from 'mongodb'
import assert from 'assert'

var scraper = new Scraper()

var url = 'mongodb://localhost:27017/reviews'

MongoClient.connect(url, function (err, db) {
    assert.equal(null, err);
    console.log("Connected correctly to server");
    db.close();
});
