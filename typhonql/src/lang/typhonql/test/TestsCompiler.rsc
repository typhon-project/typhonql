/********************************************************************************
* Copyright (c) 2018-2020 CWI & Swat.engineering 
*
* This program and the accompanying materials are made available under the
* terms of the Eclipse Public License 2.0 which is available at
* http://www.eclipse.org/legal/epl-2.0.
*
* This Source Code may also be made available under the following Secondary
* Licenses when the conditions for such availability set forth in the Eclipse
* Public License, v. 2.0 are satisfied: GNU General Public License, version 2
* with the GNU Classpath Exception which is
* available at https://www.gnu.org/software/classpath/license.html.
*
* SPDX-License-Identifier: EPL-2.0 OR GPL-2.0 WITH Classpath-exception-2.0
********************************************************************************/

module lang::typhonql::\test::TestsCompiler

import lang::typhonql::util::Log;
import lang::typhonql::util::Testing;

import lang::typhonql::TDBC;
import lang::typhonql::Normalize; // for pUUID
import lang::typhonql::util::UUID; 

import IO;
import Set;
import Map;
import List;

import lang::typhonml::Util;

/*
 * These tests are meant to be run on a Typhon Polystore deployed according to the
 * resources/user-reviews-product folder
 */
 

str U(str u) = pUUID(u);
str base64(str b) = base64Encode(b);

//str HOST = "192.168.178.78";
str HOST = "localhost";
str PORT = "8080";
str USER = "admin";
str PASSWORD = "admin1@";

public Log PRINT() = void(value v) { println("LOG: <v>"); };
 
KeyVal aBillingKeyVal =
  (KeyVal)`billing: address( street: "Commelin", city: "Ams"
          '   , zipcode: zip(nums: "1093", letters: "VX")
          '   , location: #point(2.0 3.0))`;

void setup(PolystoreInstance p, bool doTest) {
	p.runUpdate((Request) `insert User { @id: #pablo, name: "Pablo", location: #point(2.0 3.0), 
                          '  created: $2020-01-02T12:24:00$,
	                      '   photoURL: "moustache",
	                      '   avatarURL: "blocky",
	                      '   address: "alsoThere",
	                      '   billing: address( street: "Seventh", city: "Ams"
	                      '   , zipcode: zip(nums: "1234", letters: "ab")
	                      '   , location: #point(2.0 3.0))}`);
	p.runUpdate((Request) `insert User { @id: #davy, name: "Davy", location: #point(20.0 30.0), photoURL: "beard",
                          '  created: $2020-01-02T12:24:00-03:00$,
	                      '   avatarURL: "blockyBeard",
	                      '   address: "alsoThere",
	                      '  billing: address( street: "Bla", city: "Almere"
	                      '   , zipcode: zip(nums: "4566", letters: "cd")
	                      '   , location: #point(20.0 30.0))}`);
	
	if (doTest) {
	  rs = p.runQuery((Request)`from User u select u.@id, u.name`);
	  p.assertResultEquals("users were inserted", rs, <["u.@id", "u.name"], [[U("pablo"), "Pablo"], [U("davy"), "Davy"]]>);
	  
	  rs = p.runQuery((Request)`from User u select u.photoURL, u.name`);
	  p.assertResultEquals("keyvals retrieved", rs, <["user__Stuff_kv_0.photoURL", "u.name"], [["moustache", "Pablo"], ["beard", "Davy"]]>);

	  rs = p.runQuery((Request)`from User u select u.photoURL, u.avatarURL, u.name`);
	  p.assertResultEquals("multiple keyvals retrieved", rs, <["user__Stuff_kv_0.photoURL", "user__Stuff_kv_0.avatarURL", "u.name"],
	    [["moustache", "blocky", "Pablo"], ["beard", "blockyBeard", "Davy"]]>);
	  
	}
	
	p.runUpdate((Request) `insert Product {@id: #tv, name: "TV", description: "Flat", productionDate:  $2020-04-13$, availabilityRegion: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), price: 20 }`);
	p.runUpdate((Request) `insert Product {@id: #radio, name: "Radio", description: "Loud" , productionDate:  $2020-04-13$, availabilityRegion: #polygon((10.0 10.0, 40.0 10.0, 40.0 40.0, 10.0 40.0, 10.0 10.0)), price: 30 }`);
	
	
	
	if (doTest) {
	  rs = p.runQuery((Request)`from Product p select p.@id, p.name, p.description, p.productionDate`); // TODO: include polygon in this test
	  p.assertResultEquals("products were inserted", rs, <["p.@id", "p.name", "p.description", "p.productionDate"], 
	     [[U("tv"), "TV", "Flat", "2020-04-13"], [U("radio"), "Radio", "Loud", "2020-04-13"]]>);
	}
	
	p.runUpdateWithBlobs((Request) `insert Review { @id: #rev1, content: "Good TV", user: #pablo, product: #tv, posted: $2020-02-03T02:11:00+01:00$, location: #point(2.0 3.0), screenshot: #blob:s1 }`, (U("s1") : "xx"));
	p.runUpdateWithBlobs((Request) `insert Review { @id: #rev2, content: "", user: #davy, product: #tv, posted: $2020-02-03T02:11:00$, location: #point(20.0 30.0), screenshot: #blob:s2 }`, (U("s2") : "yy"));
	p.runUpdateWithBlobs((Request) `insert Review { @id: #rev3, content: "***", user: #davy, product: #radio, posted: $2020-02-03T02:11:00$, location: #point(3.0 2.0), screenshot: #blob:s3 }`, (U("s3") : "zz"));
	
	p.runUpdate((Request)`insert Comment { @id: #c1, review: #rev1, comment: "I agree" }`);
	p.runUpdate((Request)`insert Comment { @id: #c2, review: #rev2, comment: "please write something" }`);
	p.runUpdate((Request)`insert Comment { @id: #c3, review: #rev2, comment: "dude, this is lazy" }`);
	
	
	if (doTest) {
	  rs = p.runQuery((Request)`from Review r select r.@id, r.content, r.user, r.product`);
	  p.assertResultEquals("reviews were inserted", rs, <["r.@id", "r.content", "r.user", "r.product"], 
	     [[U("rev1"), "Good TV", U("pablo"), U("tv")], 
	      [U("rev2"), "", U("davy"), U("tv")],
	      [U("rev3"), "***", U("davy"), U("radio")]
	      ]>);
	      
	  rs = p.runQuery((Request)`from Product p select p.reviews`);
	  p.assertResultEquals("reviews obtained from product", rs, <["p.reviews"], [[U("rev1")], [U("rev2")], [U("rev3")]]>);

	  rs = p.runQuery((Request)`from User u select u.reviews`);
	  p.assertResultEquals("reviews obtained from user", rs, <["u.reviews"], [[U("rev1")], [U("rev2")], [U("rev3")]]>);
	  
	  rs = p.runQuery((Request)`from Review r select r.@id, r.comments`);
	  p.assertResultEquals("comments obtained from review", rs, <["r.@id", "r.comments"], 
	     [
	       [U("rev1"), [U("c1")]],
	       [U("rev2"), [U("c2"), U("c3")]],
	       [U("rev3"), {}]
	     ]
	     >);
	}
	
	
	
	p.runUpdate((Request) `insert Biography { @id: #bio1, content: "Chilean", user: #pablo }`);
	
	if (doTest) {
	  rs = p.runQuery((Request)`from Biography b select b.@id, b.content, b.user`);
	  p.assertResultEquals("bios were inserted", rs, <["b.@id", "b.content", "b.user"], 
	    [[U("bio1"), "Chilean", U("pablo")]]>);
	    
	  rs = p.runQuery((Request)`from User u select u.biography`);
	  // the fact that there's null (i.e., <false, "">) here means that
	  // there are users without bios
	  p.assertResultEquals("bio obtained from user", rs, <["u.biography"], [[U("bio1")], [{}]]>);  
	}
	
	p.runUpdate((Request) `insert Tag { @id: #fun, name: "fun" }`);
	p.runUpdate((Request) `insert Tag { @id: #kitchen, name: "kitchen" }`);
	p.runUpdate((Request) `insert Tag { @id: #music, name: "music" }`);
	p.runUpdate((Request) `insert Tag { @id: #social, name: "social" }`);
	
	p.runUpdate((Request) `insert Tag { @id: #friendly, name: "friendly" }`);
	

	p.runUpdate((Request) `insert Synonym { @id: #syn1, source: #social, target: #friendly, weight: 10 }`);
	

    if (doTest) {
      rs = p.runQuery((Request)`from Tag t select t.@id, t.name`);
      p.assertResultEquals("tags were inserted", rs, <["t.@id", "t.name"], [
        [U("fun"), "fun"],
        [U("kitchen"), "kitchen"],
        [U("music"), "music"],
        [U("social"), "social"],
        [U("friendly"), "friendly"]
      ]>);
    }


	p.runUpdateWithBlobs((Request) `insert Item { @id: #tv1, shelf: 1, product: #tv, picture: #blob:b1 }`, (U("b1") : "aa"));	
	p.runUpdateWithBlobs((Request) `insert Item { @id: #tv2, shelf: 1, product: #tv, picture: #blob:b2 }`, (U("b2") : "bb"));	
	p.runUpdateWithBlobs((Request) `insert Item { @id: #tv3, shelf: 3, product: #tv, picture: #blob:b3 }`, (U("b3") : "cc"));	
	p.runUpdateWithBlobs((Request) `insert Item { @id: #tv4, shelf: 3, product: #tv, picture: #blob:b4 }`, (U("b4") : "dd"));
	
	p.runUpdateWithBlobs((Request) `insert Item { @id: #radio1, shelf: 2, product: #radio, picture: #blob:b5 }`, (U("b5") : "ee"));
	p.runUpdateWithBlobs((Request) `insert Item { @id: #radio2, shelf: 2, product: #radio, picture: #blob:b6 }`, (U("b6") : "ff"));
	
	if (doTest) {
	  rs = p.runQuery((Request)`from Item i select i.@id, i.shelf, i.product`);
	  p.assertResultEquals("items were inserted", rs, <["i.@id", "i.shelf", "i.product"], [
	    [U("tv1"), "1", U("tv")],
	    [U("tv2"), "1", U("tv")],
	    [U("tv3"), "3", U("tv")],
	    [U("tv4"), "3", U("tv")],
	    [U("radio1"), "2", U("radio")],
	    [U("radio2"), "2", U("radio")]
	  ]>);
	  
	  rs = p.runQuery((Request)`from Product p select p.inventory where p.@id == #tv`);
	  p.assertResultEquals("tv inventory obtained", rs, <["p.inventory"], [[U("tv1")], [U("tv2")], [U("tv3")], [U("tv4")]]>);
	  
	  rs = p.runQuery((Request)`from Product p select p.inventory where p.@id == #radio`);
	  p.assertResultEquals("radio inventory obtained", rs, <["p.inventory"], [[U("radio1")], [U("radio2")]]>);
	}	
	
	p.runUpdate((Request) `insert Wish { @id: #wish1, intensity: 7, user: #pablo, product: #tv }`);
	p.runUpdate((Request) `insert Wish { @id: #wish2, intensity: 9, user: #pablo, product: #radio }`);
	
	if (doTest) {
	  rs = p.runQuery((Request)`from Wish w select w.@id`);
	  p.assertResultEquals("whish was inserted", rs, <["w.@id"], [
	    [U("wish1")], [U("wish2")]
	  ]>);
	  
	  rs = p.runQuery((Request)`from Product p select p.wishes where p.@id == #tv`);
	  p.assertResultEquals("wish obtained from product", rs, <["p.wishes"], [[U("wish1")]]>);
	  
	  rs = p.runQuery((Request)`from User u select u.wishes where u.@id == #pablo`);
	  p.assertResultEquals("wish obtained from user", rs, <["u.wishes"], [[U("wish1")], [U("wish2")]]>);
	}
	
	p.runUpdate((Request) `insert Word { @id: #outstanding, name: "outstanding" }`);
	p.runUpdate((Request) `insert Evaluation { @id: #evaluation1, body: "This is outstanding!" }`);
	p.runUpdate((Request) `insert Occurrence { @id: #occurrence1, times:10, word: #outstanding, evaluation: #evaluation1 }`);
	
	if (doTest) {
	  rs = p.runQuery((Request)`from Occurrence o select o.@id`);
	  p.assertResultEquals("occurrence was inserted", rs, <["o.@id"], [
	    [U("occurrence1")]]>);
	  
	  rs = p.runQuery((Request)`from Product p select p.wishes where p.@id == #tv`);
	  p.assertResultEquals("wish obtained from product", rs, <["p.wishes"], [[U("wish1")]]>);
	  
	  rs = p.runQuery((Request)`from User u select u.wishes where u.@id == #pablo`);
	  p.assertResultEquals("wish obtained from user", rs, <["u.wishes"], [[U("wish1")], [U("wish2")]]>);
	}
	
	
	p.runUpdate((Request) `insert Company { @id: #ibm, name: "IBM", mission: "Be better", vision: "Forever"}`);
    
    p.runUpdate((Request) `insert Foundation { @id: #wwf, name: "WWF", mission: "Better world", vision: "We are the world"}`);
    p.runUpdate((Request) `insert Foundation { @id: #greenpeace, name: "Greenpeace", mission: "Green peace", vision: "Peace should be green"}`);
    
    if (doTest) {
  		rs = p.runQuery((Request)`from Company c select c.@id, c.mission`);
  		p.assertResultEquals("company was inserted", rs, <["c.@id", "c.mission"], [
	    	[U("ibm"), "Be better"]]>);
	    
	    // Not done for now because NLAE gets stuck with NER
	    rs = p.runQuery((Request)`from Foundation f select f.@id`);
	    p.assertResultEquals("foundation was inserted", rs, <["f.@id", "f.mission"], [
	    	[U("wwf"), "Better world"],
	    	[U("greenpeace"), "Green peace"]]>); 
	} 
}

void resetDatabases(PolystoreInstance p) {
	p.resetDatabases();
}

void testSetup(PolystoreInstance p, Log log = NO_LOG()) {
  println("Doing sanity check on setup");
  p.resetDatabases();
  setup(p, true);
}

// pro memorie, these tests will fail.
void testNullReferences(PolystoreInstance p) {
   rs = p.runQuery((Request)`from User u select u.name where u.biography == null`);
   p.assertResultEquals("users without bios", rs, <["u.name"], [["Davy"]]>);

   rs = p.runQuery((Request)`from Product p select p.name where p.reviews == null`);
   p.assertResultEquals("products without reviews", rs, <["p.name"], []>);

}

void testBasicMongoDBWhereClauses(PolystoreInstance p) {
  
	rs = p.runQuery((Request)`from Review r select r.content where r.product == #tv, r.user == #davy`);
	p.assertResultEquals("comma separated clauses both filter", rs, <["r.content"], [[""]]>);

	rs = p.runQuery((Request)`from Review r select r.content where r.product == #tv && r.user == #davy`);
	p.assertResultEquals("using && filters like comma", rs, <["r.content"], [[""]]>);


	rs = p.runQuery((Request)`from Review r select r.content where r.product == #radio || r.user == #pablo`);
	p.assertResultEquals("using || works", rs, <["r.content"], [["***"], ["Good TV"]]>);

	rs = p.runQuery((Request)`from Review r select r.content where r.product == #radio || r.user == #pablo || r.location == #point(20.0 30.0)`);
	p.assertResultEquals("using || works multiple times", rs, <["r.content"], [["***"], ["Good TV"], [""]]>);

//p.runUpdateWithBlobs((Request) `insert Review { @id: #rev1, content: "Good TV", user: #pablo, product: #tv, posted: $2020-02-03T02:11:00+01:00$, location: #point(2.0 3.0), screenshot: #blob:s1 }`, (U("s1") : "xx"));
//	p.runUpdateWithBlobs((Request) `insert Review { @id: #rev2, content: "", user: #davy, product: #tv, posted: $2020-02-03T02:11:00$, location: #point(20.0 30.0), screenshot: #blob:s2 }`, (U("s2") : "yy"));
//	p.runUpdateWithBlobs((Request) `insert Review { @id: #rev3, content: "***", user: #davy, product: #radio, posted: $2020-02-03T02:11:00$, location: #point(3.0 2.0), screenshot: #blob:s3 }`, (U("s3") : "zz"));
	
	rs = p.runQuery((Request)`from Review r select r.content where r.product == #radio || (r.user == #pablo && r.location == #point(20.0 30.0))`);
	p.assertResultEquals("using && below || works ", rs, <["r.content"], [["***"]]>);

	rs = p.runQuery((Request)`from Review r select r.content where (r.user == #pablo && r.location == #point(20.0 30.0) || r.product == #radio )`);
	p.assertResultEquals("using && below || works (no short-circuit) ", rs, <["r.content"], [["***"]]>);

}

void testBasicAggregationNativeMongo(PolystoreInstance p) {
	rs = p.runQuery((Request)`from Review r select count(r.@id) as reviewCount`);
	p.assertResultEquals("reviews counted correctly", rs, <["r.reviewCount"],
	  [["3"]]>);


    // mongo doesn't allow combination with non-aggregation operators
	rs = p.runQuery((Request)`from Review r select count(r.@id) as reviewCount group r.user`);
	p.assertResultEquals("reviews counted grouped by user", rs, <["r.reviewCount"],
	  [["2"], 
	   ["1"]]>);
	   
	p.runUpdate((Request)`delete Review r`);
	rs = p.runQuery((Request)`from Review r select count(r.@id) as reviewCount`);
	p.assertResultEquals("reviews counted correctly on empty collection", rs, <["r.reviewCount"],
	  [["0"]]>);
}

void testBasicAggregationNativeSQL(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i select count(i.@id) as cnt group null`);
  p.assertResultEquals("items counted correctly", rs, <["i.cnt"], 
    [["6"]]>);

  rs = p.runQuery((Request)`from Item i select sum(i.shelf) as cnt group null`);
  p.assertResultEquals("item shelves summed correctly", rs, <["i.cnt"], 
    [["12"]]>);
    
  rs = p.runQuery((Request)`from Item i select count(i.@id) as cnt`);
  p.assertResultEquals("items counted w/o group-clause", rs, <["i.cnt"], 
    [["6"]]>);

  // select `Item.shelf`, count(`Item.@id`) from Item group by `Item.shelf`;
  rs = p.runQuery((Request)`from Item i select i.shelf, count(i.@id) as numOfItems group i.shelf`);
  p.assertResultEquals("shelf items counted correctly", rs, <["i.shelf", "i.numOfItems"], 
    [["1", "2"], ["2", "2"], ["3","2"]]>);


    
  rs = p.runQuery((Request)`from Product p select p.@id, count(p.inventory) as numOfItems group p.@id`);  
  p.assertResultEquals("product inventory items counted correctly", rs, <["p.@id", "p.numOfItems"], 
    [[U("tv"), "4"], [U("radio"), "2"]]>);
    
  // TODO: let type checker test at as-clauses are present
  
  rs = p.runQuery((Request)`from Item i, Product p select i.product, sum(p.price) as total where i.product == p group i.product`);
  p.assertResultEquals("item prices summed correctly", rs, <["i.product", "p.total"], 
    [[U("tv"), "<4 * 20>"], [U("radio"), "<2 * 30>"]]>);
    
  // todo: sum(i.product.price)? that needs changing expandNavigation normalization (no; because of lifting)
  // but it still does not work...
  //rs = p.runQuery((Request)`from Item i select i.product, sum(i.product.price) as total group i.product`);
  //p.assertResultEquals("item prices summed correctly thru navigation", rs, <["i.product", "total"], 
  //  [[U("tv"), 4 * 20], [U("radio"), 2 * 30]]>);

  rs = p.runQuery((Request)`from Item i, Product p select i.product, sum(p.price) as total 
                           'where i.product == p group i.product having total \> 60`);
  p.assertResultEquals("item prices summed and larger than 60", rs, <["i.product", "p.total"], 
    [[U("tv"), "<4 * 20>"]]>);
    
    
  p.runUpdate((Request)`delete Item i`);
  rs = p.runQuery((Request)`from Item i select count(i.@id) as cnt`);
  p.assertResultEquals("items counted w/o group-clause on empty table", rs, <["i.cnt"], 
    [["0"]]>);
  
    
}

void testLimit(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i select i.shelf limit 2`);
  p.assertResultEquals("shelves selected correctly with limit 2", rs, <["i.shelf"], 
    [["2"], ["3"]]>);


  rs = p.runQuery((Request)`from Item i select i.shelf, count(i.@id) as numOfItems group i.shelf limit 2`);
  p.assertResultEquals("shelf items counted correctly with limit 2", rs, <["i.shelf", "i.numOfItems"], 
    [["1", "2"], ["2", "2"]]>);
}

void testLimitAndOrder(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i select i.shelf limit 2 order i.shelf`);
  p.assertResultEquals("shelves selected correctly limited and sorted", rs, <["i.shelf"], 
    [["1"], ["1"]]>);

  rs = p.runQuery((Request)`from Item i select i.shelf limit 2 order i.shelf desc`);
  p.assertResultEquals("shelves selected correctly limited and sorted in reverse", rs, <["i.shelf"], 
    [["3"], ["3"]]>);

  rs = p.runQuery((Request)`from Item i, Product p select i.product, sum(p.price) as total 
                           'where i.product == p group i.product order total limit 1`);
  p.assertResultEquals("item prices summed, sorted, limited", rs, <["i.product", "p.total"], 
    [[U("radio"), "<2 * 30>"]]>);
  
  rs = p.runQuery((Request)`from Item i, Product p select i.product, sum(p.price) as total 
                           'where i.product == p group i.product order total desc limit 1`);
  p.assertResultEquals("item prices summed, sorted in reverse, limited", rs, <["i.product", "p.total"], 
    [[U("tv"), "<4 * 20>"]]>);
  
  
  
}


void testOrdering(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i select i.shelf order i.shelf`);
  p.assertResultEquals("shelves correctly sorted", rs, <["i.shelf"], 
      [["1"], ["1"], ["2"], ["2"], ["3"], ["3"]]>);

  rs = p.runQuery((Request)`from Item i select i.shelf order i.shelf desc`);
  p.assertResultEquals("shelves correctly sorted in reverse", rs, <["i.shelf"], 
      [["3"], ["3"], ["2"], ["2"], ["1"], ["1"]]>);

  rs = p.runQuery((Request)`from Item i, Product p select i.product, sum(p.price) as total 
                           'where i.product == p group i.product order total`);
  p.assertResultEquals("item prices sorted correctly", rs, <["i.product", "p.total"], 
    [[U("tv"), "<4 * 20>"], [U("radio"), "<2 * 30>"]]>);
 
  rs = p.runQuery((Request)`from Item i, Product p select i.product, sum(p.price) as total 
                           'where i.product == p group i.product order total desc`);
  p.assertResultEquals("item prices sorted correctly in reverse", rs, <["i.product", "p.total"], 
    [[U("radio"), "<2 * 30>"], [U("tv"), "<4 * 20>"]]>);
  
}


void testMultiVarOccurencesMapToSamePlaceholder(PolystoreInstance p) {
  rs = p.runQuery((Request)`from User u, Review r select u.name where u.name == "Pablo",
                      ' u.reviews == r.@id, r.content == u.name, r.content == u.name`);
                      
  p.assertResultEquals("no exception thrown", rs, <["u.name"], []>);

  rs = p.runQuery((Request)`from User u, Review r select r.content, u.name where r.content == "something",
                      ' r.user == u.@id, u.name == r.content, u.name == r.content`);
                      
  p.assertResultEquals("no exception thrown", rs, <["r.content", "u.name"], []>);

}

void testKeyValueFeatures(PolystoreInstance p) {

  p.runUpdate((Request)`update User u where u.@id == #pablo set {photoURL: "something", name: "Pablo the 2nd"}`);
  p.runUpdate((Request)`update User u where u.@id == #davy set {photoURL: "other", name: "Landman"}`);

  rs = p.runQuery((Request)`from User u select u.photoURL, u.name`);
  p.assertResultEquals("keyvals were updated", rs, <["user__Stuff_kv_0.photoURL", "u.name"], 
    [["something", "Pablo the 2nd"], ["other", "Landman"]]>);

  /*
  the below throws:
  com.datastax.oss.driver.api.core.servererrors.InvalidQueryException: Invalid amount of bind variables
  
  but the correct cassandra delete is generated.
  */
  //p.runUpdate((Request)`delete User u where u.@id == #pablo`);
  //
  //rs = p.runQuery((Request)`from User u select u.photoURL where u.@id == #pablo`);
  //p.assertResultEquals("keyvals are deleted if parent is deleted", rs, <["user__Stuff_kv_0.photoURL"], []>);

}


void testDefaultAttrInsertion(PolystoreInstance p) {
  p.runUpdate((Request)`insert User { name: "Donald Trump" }`);
  rs = p.runQuery((Request)`from User u select u where u.name == "Donald Trump"`);
  p.assertResultEquals("default vals correctly inserted", rs, <
    ["u.address","u.billing$city","u.billing$location","u.billing$street","u.billing$zipcode$letters",
       "u.billing$zipcode$nums","u.created","u.location","u.name"],
    [["","","POINT (0 0)","","","","0001-12-29T23:00:00Z","POINT (0 0)","Donald Trump"]]>);
  
}

// this is brittle! order of lone var expansion is not defined!
void testLoneVars(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i select i`);
  p.assertResultEquals("all features from Item retrieved", rs, <["i.picture", "i.shelf"]
    , [
        [base64("aa"), "1"],//, U("tv")],
        [base64("bb"), "1"],// U("tv")],
        [base64("cc"), "3"],//, U("tv")],
        [base64("dd"), "3"],// U("tv")],
        [base64("ee"), "2"],// U("radio")],
        [base64("ff"), "2"] // U("radio")]
    ]>);
  
  rs = p.runQuery((Request)`from User u select u`);
  p.assertResultEquals("all features from User retrieved", rs,
      <["u.address","u.billing$city","u.billing$location","u.billing$street","u.billing$zipcode$letters",
        "u.billing$zipcode$nums","u.created","u.location","u.name"],
      
       [["alsoThere","Ams","POINT (2 3)","Seventh","ab","1234","2020-01-02T11:24:00Z","POINT (2 3)","Pablo"],
       ["alsoThere","Almere","POINT (20 30)","Bla","cd","4566","2020-01-02T15:24:00Z","POINT (20 30)","Davy"]]
       >
       );
  
   
    
  rs = p.runQuery((Request)`from Review r select r`);
  p.assertResultEquals("all features from Review retrieved",  rs,
    <["r.content","r.location","r.posted","r.screenshot"],
    [["Good TV","POINT (2 3)","2020-02-03T01:11:00Z","eHg="],
     ["","POINT (20 30)","2020-02-03T01:11:00Z","eXk="],
     ["***","POINT (3 2)","2020-02-03T01:11:00Z","eno="]]>);
    
    
  rs = p.runQuery((Request)`from Biography b select b`);
  p.assertResultEquals("all features from Biography retrieved", rs, <["b.content"]
    , [["Chilean" /*, U("pablo")*/]]>);

   
   
  rs = p.runQuery((Request)`from User u, Biography b select u, b where u.biography == b`);
  p.assertResultEquals("all features of Pablo and his Biography retrieved", rs, 
     <["u.address","u.billing$city","u.billing$location","u.billing$street","u.billing$zipcode$letters",
     "u.billing$zipcode$nums","u.created","u.location","u.name","b.content"],
       [["alsoThere","Ams","POINT (2 3)","Seventh","ab","1234","2020-01-02T11:24:00Z","POINT (2 3)","Pablo","Chilean"]]>);
}

void testSelectFreetextAttributes(PolystoreInstance p) {
  rs = p.runQuery((Request) `from Company c select c.@id, c.mission, c.mission.SentimentAnalysis.Sentiment where c.mission.SentimentAnalysis.Sentiment \>= 1 && c.vision.SentimentAnalysis.Sentiment \>= 2`);
  
  // We do not know yet the expected result
  //p.assertResultEquals("company retrieved", rs, <["c.@id"], [
  //	    [U("ibm"), "Be better", 1]]>); 
                        
}

void testSelectFreetextAttributes2(PolystoreInstance p) {
  rs = p.runQuery((Request) `from Foundation f select f.@id, f.mission, f.mission.SentimentAnalysis.Sentiment where f.mission.SentimentAnalysis.begin \>= 1 && f.mission.NamedEntityRecognition.begin \>= 2`);
  // We do not know yet the expected result
  //p.assertResultEquals("foundation retrieved", rs, <["f.@id"], [
  //    [U("ibm"), "Better world", 1]]>); 
                        
}

void testSelectFreetextAttributes3(PolystoreInstance p) {
  rs = p.runQuery((Request) `from Foundation f select f.@id, f.mission, f.mission.SentimentAnalysis.Sentiment, f.mission.NamedEntityRecognition.NamedEntity where f.mission.SentimentAnalysis.begin \>= 1 && f.mission.NamedEntityRecognition.begin \>= 2`);
  println(rs);
  // We do not know yet the expected result
  //p.assertResultEquals("foundation retrieved", rs, <["f.@id"], [
  //    [U("ibm"), "Better world", 1]]>); 
                        
}
void testInsertFreetextAttributes(PolystoreInstance p) {
	p.runUpdate((Request) `insert Company { @id: #ibm, name: "IBM", mission: "Be better", vision: "Forever"}`);
   	
   	rs = p.runQuery((Request)`from Company c select c.@id, c.mission`);
  	p.assertResultEquals("company was inserted", rs, <["c.@id", "c.mission"], [
	    	[U("ibm"), "Be better"]]>);
	 
}

void testDeleteFreetextAttributes(PolystoreInstance p) {
    p.runUpdate((Request) `delete Company c where c.@id == #ibm`);
	rs = p.runQuery((Request) `from Company c select c.@id where  c.@id == #ibm`);
	p.assertResultEquals("company (with free text attribtues) deleted", rs, <["c.@id"], []>);
}

void testCustomDataTypes(PolystoreInstance p) {
  p.runUpdate((Request) `insert User { @id: #jurgen, name: "Jurgen", location: #point(2.0 3.0), 
                          '  created: $2020-01-02T12:24:00$,
                        '  photoURL: "moustache",
                        '  avatarURL: "blockyMoustache",
	                    '  address: "Address 2",
                        '  billing: address( street: "Seventh", city: "Ams"
	                    '   , zipcode: zip(nums: "1234", letters: "ab")
	                    '   , location: #point(2.0 3.0))}`);
	                    

  p.runUpdate((Request)`update User u where u.@id == #jurgen set {billing: address(street: "Schout")}`);
  
  rs = p.runQuery((Request)`from User u select u.billing.street where u.@id == #jurgen`);
  p.assertResultEquals("custom data type field updated and retrieved", rs, <["u.billing$street"], [["Schout"]]>);


  p.runUpdate((Request)`update User u where u.@id == #jurgen set {billing: address(zipcode: zip(letters: "ZZ"))}`);
  
  rs = p.runQuery((Request)`from User u select u.billing.zipcode.letters where u.@id == #jurgen`);
  p.assertResultEquals("nested custom data type field updated and retrieved", rs, <["u.billing$zipcode$letters"], [["ZZ"]]>);
  
  // No delete now, because of $pull bug in mongo child cascade.
  p.runUpdate((Request)`delete User u where u.billing.zipcode.letters == "ZZ"`);
  rs = p.runQuery((Request)`from User u select u.@id where u.@id == #jurgen`);
  p.assertResultEquals("delete by nested custom data type", rs, <["u.@id"], []>);

}

void testInsertSingleValuedSQLCross(PolystoreInstance p) {
  p.runUpdate((Request)`insert Category {@id: #appliances, id: "appliances", name: "Home Appliances"}`);
  
  rs = p.runQuery((Request)`from Category c select c.name where c.@id == #appliances`);
  p.assertResultEquals("category name obtained from mongo", rs, <["c.name"],[["Home Appliances"]]>);
  
  p.runUpdate((Request)`insert Product {@id: #nespresso, 
  					 '  name: "Nespresso", 
  					 '  price: 23, 
  					 '  description: "Nice coffee",
  					 '  productionDate: $2020-04-15$,
  					 '  availabilityRegion: #polygon((1.0 1.0)),
  					 '  category: #appliances
  					 '}`);

  rs = p.runQuery((Request)`from Product p select p.name where p.category == #appliances`);
  p.assertResultEquals("product by category", rs, <["p.name"],[["Nespresso"]]>);
}

void testInsertManyValuedSQLLocal(PolystoreInstance p) {
  // TODO: this shows the cyclic reference problem we still need to solve.
  // NB: we have to insert the product first.

  // inventory: [#laptop1, #laptop2], 
  p.runUpdate((Request)`insert Product { @id: #laptop, name: "MacBook", availabilityRegion: #polygon((1.0 1.0)), productionDate: $2020-03-03$, price: 4000, description: "expensive laptop"}`);

  p.runUpdateWithBlobs((Request)`insert Item { @id: #laptop1, shelf: 1, product: #laptop, picture: #blob:b5 }`, (U("b5") : "dd"));	
  p.runUpdateWithBlobs((Request)`insert Item { @id: #laptop2, shelf: 1, product: #laptop, picture: #blob:b6 }`, (U("b6") : "dd"));	
	
  
  rs = p.runQuery((Request)`from Product p select p.inventory where p.@id == #laptop`);
  
  p.assertResultEquals("many-valued inventory obtained from product", rs, <["p.inventory"],
      [[U("laptop1")], [U("laptop2")]]>);
  
  rs = p.runQuery((Request)`from Item i select i.@id where i.product == #laptop`);
  p.assertResultEquals("many-valued inventory obtained via inverse", rs, <["i.@id"],
      [[U("laptop1")], [U("laptop2")]]>);
  
}

//p.runUpdate((Request)`insert Category {@id: #appliances, id: "appliances", name: "Home Appliances"}`);

void testDeleteSomeMongoBasic(PolystoreInstance p) {
  p.runUpdate((Request)`insert Category {@id: #appliances, id: "appliances", name: "Home Appliances"}`);
  p.runUpdate((Request)`insert Category {@id: #other, id: "misc", name: "Misc"}`);
  p.runUpdate((Request)`delete Category c where c.@id == #other`);
  rs = p.runQuery((Request)`from Category c select c.@id`);
  p.assertResultEquals("delete with where from mongo deletes", rs, <["c.@id"], [["appliances"]]>);
}

void testBlobs(PolystoreInstance p) {
  p.runUpdateWithBlobs((Request) `insert Item { @id: #tv5, shelf: 1, product: #tv, picture: #blob:tb1 }`, (U("tb1") : "aa"));	
  rs = p.runQuery((Request)`from Item i select i.picture where i.@id == #tv5`);
  p.assertResultEquals("Blob in SQL", rs, <["i.picture"], [["YWE="]]>);

  p.runPreparedUpdateWithBlobs((Request) `insert Item { @id: #tv7, shelf: 1, product: #tv, picture: ??b }`,
    ["b"], ["blob"], [["#blob:<U("tb1")>"]], (U("tb1") : "aa"));	
  rs = p.runQuery((Request)`from Item i select i.picture where i.@id == #tv7`);
  p.assertResultEquals("Prepared Blob in SQL", rs, <["i.picture"], [["YWE="]]>);
  
  p.runUpdateWithBlobs((Request)`insert Review { @id: #newReview, content: "expensive", user: #davy, posted: $2020-02-02T11:11:00$, location: #point(1.0 1.0), screenshot: #blob:s4 }`, (U("s4") : "uu"));
  
  rs = p.runQuery((Request)`from Review r select r.screenshot where r.@id == #newReview`);
  p.assertResultEquals("Blob in Mongo", rs, <["r.screenshot"], [["dXU="]]>);

  p.runPreparedUpdateWithBlobs((Request) `insert Review { @id: #newReview2, content: "expensive", user: #davy, posted: $2020-02-02T11:11:00$, location: #point(1.0 1.0), screenshot: ??b }`,
    ["b"], ["blob"], [["#blob:<U("s4")>"]], (U("s4") : "uu"));	
  rs = p.runQuery((Request)`from Review r select r.screenshot where r.@id == #newReview2`);
  p.assertResultEquals("Prepared Blob in Mongo", rs, <["r.screenshot"], [["dXU="]]>);
}


void testDeleteAllSQLNeoWithCascade(PolystoreInstance p) {
  p.runUpdate((Request)`delete Tag t where t.name == "friendly"`);
  rs = p.runQuery((Request)`from Tag t select t.@id`);
  p.assertResultEquals("testDeleteAllSQLNeoCascade", rs, <["t.@id"], 
		[[U("fun")],
        [U("kitchen")],
        [U("music")],
        [U("social")]]>);
  rs = p.runQuery((Request)`from Synonym s select s.@id`);
  p.assertResultEquals("deleting a synonym by cascade on tag deletes it", rs, <["s.@id"], []>);
  rs = p.runQuery((Request)`from Tag t select t.synonymsFrom where t.@id == #social`);
  p.assertResultEquals("deleting a synonym by cascade on tag deletes the synonyms of tag 1", rs, <["t.synonymsFrom"], [[{}]]>);
  rs = p.runQuery((Request)`from Tag t select t.synonymsTo where t.@id == #friendly`);
  p.assertResultEquals("deleting a synonym by cascade on tag deletes the synonyms of tag 2", rs, <["t.synonymsTo"], []>);
  
}

void testDeleteAllSQLMongoNeoWithCascade(PolystoreInstance p) {
  p.runUpdate((Request)`delete Word w where w.name == "outstanding"`);
  rs = p.runQuery((Request)`from Word w select w.@id`);
  p.assertResultEquals("testDeleteAllSQLMongoNeoWithCascade", rs, <["w.@id"], 
		[]>);
  rs = p.runQuery((Request)`from Occurrence o select o.@id`);
  p.assertResultEquals("deleting a occurrence by cascade on word deletes it", rs, <["o.@id"], []>);
  rs = p.runQuery((Request)`from Evaluation e select e.occurrences where t.@id == #evaluation1`);
  p.assertResultEquals("deleting a occurrence by cascade on word deletes the evaluations of that occurrence", rs, <["e.occurrences"], []>);
}

void testDeleteAllWithCascade(PolystoreInstance p) {
  p.runUpdate((Request)`delete Product p where p.name == "Radio"`);

  rs = p.runQuery((Request)`from Product p select p.@id where p.name == "Radio"`);
  p.assertResultEquals("deleting a product by name deletes it", rs, <["p.@id"], []>);

  p.runUpdate((Request)`delete Product p where p.@id == #tv`);
  
  rs = p.runQuery((Request)`from Product p select p.@id where p.@id == #tv`);
  p.assertResultEquals("deleting a product by id deletes it", rs, <["p.@id"], []>);
  
  rs = p.runQuery((Request)`from Item i select i.@id where i.product == #tv`);
  p.assertResultEquals("deleting products deletes items", rs, <["i.@id"], []>);
  
  rs = p.runQuery((Request)`from Review r select r.@id where r.product == #tv`);
  p.assertResultEquals("deleting products deletes reviews", rs, <["r.@id"], []>);

  rs = p.runQuery((Request)`from Tag t select t.@id`);
  p.assertResultEquals("deleting products does not delete tags", rs, <["t.@id"], 
    [[U("fun")], [U("kitchen")], [U("music")], [U("social")], [U("friendly")]]>);
}

void testDeleteKidsRemovesParentLinksSQLLocal(PolystoreInstance p) {
  p.runUpdate((Request)`delete Item i where i.product == #tv`);
  
  rs = p.runQuery((Request)`from Product p select p.inventory where p == #tv`);
  p.assertResultEquals("delete items removes from inventory", rs, <["p.inventory"], [[{}]]>);
}

void testDeleteKidsRemovesParentLinksSQLCross(PolystoreInstance p) {
  p.runUpdate((Request)`delete Review r where r.product == #tv`);
  
  rs = p.runQuery((Request)`from Product p select p.reviews where p == #tv`);
  p.assertResultEquals("delete reviews removes from product reviews", rs, <["p.reviews"], [[{}]]>);
}

void testInsertManyXrefsSQLLocal(PolystoreInstance p) {
  p.runUpdate((Request)`insert Product {@id: #iphone, name: "iPhone", description: "Apple", tags: [#fun, #social], availabilityRegion: #polygon((1.0 1.0)), productionDate: $2020-01-01$, price: 400}`);
  rs = p.runQuery((Request)`from Product p select p.name where p.tags == #fun`);
  p.assertResultEquals("insertManyXrefsSQLLocal", rs, <["p.name"], [["iPhone"]]>);
}

void testInsertManyContainSQLtoLocal(PolystoreInstance p) {

}

void testInsertManyContainSQLtoExternal(PolystoreInstance p) {
  p.runUpdateWithBlobs((Request)`insert Review { @id: #newReview, content: "expensive", user: #davy, posted: $2020-11-22T23:55:00$, location: #point(1.0 1.0), screenshot: #blob:s4 }`, (U("s4") : "uu"));
  p.runUpdate((Request)`insert Product {@id: #iphone, name: "iPhone", description: "Apple", reviews: [#newReview], availabilityRegion: #polygon((1.0 1.0)), price: 400, productionDate: $2001-01-01$}`);
  
  // this below query is not as intended, r remains unconstrained, so you get all review contents.
  //rs = p.runQuery((Request)`from Product p, Review r select r.content where p.@id == #iphone, p.reviews == #newReview`);
  
  // this throws: could not find source tbl for outer join...
  // seems to be the case when you have two wheres conditions on a junction table field...
  //rs = p.runQuery((Request)`from Product p, Review r select r.content where p.@id == #iphone, p.reviews == #newReview, p.reviews == r`);

  
  // this works, but doesn't show that it's found via p.reviews:
  //rs = p.runQuery((Request)`from Product p, Review r select r.content where p.@id == #iphone, r == #newReview`);
  
  // so we use this:
  rs = p.runQuery((Request)`from Product p, Review r select r.content where p.@id == #iphone, p.reviews == r`);
  
  p.assertResultEquals("InsertManyContainSQLtoExternal", rs, <["r.content"], [["expensive"]]>);
}

void testInsertWithNullSQL(PolystoreInstance p) {
  // No description 
  p.runUpdate((Request)`insert Product {@id: #wine, name: "Aliwen", productionDate:  $2020-04-14$, availabilityRegion: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), price: 150}`);
  rs = p.runQuery((Request)`from Product p select p.@id, p.description where p.@id == #wine`);
  p.assertResultEquals("testInsertWithNullSQL", rs, <["p.@id", "p.description"], [[U("wine"), {}]]>);

}

void testInsertWithNullNeo(PolystoreInstance p) {
  // No description 
  p.runUpdate((Request)`insert Wish {@id: #wish3, user: #davy, product: #tv}`);
  rs = p.runQuery((Request)`from Wish w select w.@id, w.intensity where w.@id == #wish3`);
  p.assertResultEquals("testInsertWithNullNeo", rs, <["w.@id", "w.intensity"], [[U("wish3"), {}]]>);

}

void testInsertWithNullMongo(PolystoreInstance p) {
  // No description 
  p.runUpdate((Request)`insert Biography { @id: #bio2, user: #davy }`);
  rs = p.runQuery((Request)`from Biography b select b.@id, b.content where b.@id == #bio2`);
  p.assertResultEquals("testInsertWithNullMongo", rs, <["b.@id", "b.content"], [[U("bio2"), {}]]>);

}

void testInsertSQLNeo(PolystoreInstance p) {
  p.runUpdate((Request)`insert Product {@id: #laptop, name: "Laptop", wishes: [#wish1], description: "Practical", productionDate:  $2020-04-14$, availabilityRegion: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), price: 150}`);
  rs = p.runQuery((Request)`from Wish w select w.product where w.@id == #wish1`);
  p.assertResultEquals("testInsertSQLNeoToEnd", rs, <["w.product"], [[U("laptop")]]>);
  
  p.runUpdate((Request) `insert User { @id: #tijs, name: "Tijs", location: #point(2.0 3.0), 
                          '  created: $2020-01-02T12:24:00$,
	                      '   photoURL: "cwi",
	                      '   avatarURL: "something",
	                      '   address: "somwehere",
	                      '   wishes: [#wish1],
	                      '   billing: address( street: "Eigth", city: "Ams"
	                      '   , zipcode: zip(nums: "2345", letters: "cd")
	                      '   , location: #point(2.0 3.0))}`);
	                      	                      
  rs = p.runQuery((Request)`from Wish w select w.user where w.@id == #wish1`);
  p.assertResultEquals("testInsertSQLNeoFromEnd", rs, <["w.user"], [[U("tijs")]]>);
  rs = p.runQuery((Request)`from Product p, Wish w select w.user where w.product == p, p == #laptop`);
  p.assertResultEquals("testInsertSQLNeoFromEndForProductId", rs, <["w.user"], [[U("tijs")]]>);
  
  
  
}

void testDeleteNeoAll(PolystoreInstance p) {
 p.runUpdate((Request)`delete Wish w`);
 rs = p.runQuery((Request)`from Wish w select w.@id`);
 p.assertResultEquals("all edges deleted", rs, <["w.@id"], []>);
}

void testDeleteSQLNeoSimple(PolystoreInstance p) {
  p.runUpdate((Request)`delete Wish w where w.@id == #wish1`);
  rs = p.runQuery((Request)`from Wish w select w.@id where w.@id == #wish1`);
  p.assertResultEquals("testDeleteSQLNeoSimple", rs, <["w.@id"], []>);
  rs = p.runQuery((Request)`from Product p select p.@id, p.wishes where p.@id == #tv`);
  p.assertResultEquals("testDeleteSQLNeoSimpleToEnd", rs, <["p.@id", "p.wishes"], [[U("tv"), {}]]>);
  rs = p.runQuery((Request)`from User u select u.@id, u.wishes where u.@id == #pablo`);
  p.assertResultEquals("testDeleteSQLNeoSimpleFromEnd", rs, <["u.@id", "u.wishes"], [[U("pablo"), U("wish2")]]>);
  
}

void testDeleteSQLNeoCascade(PolystoreInstance p) {
  p.runUpdate((Request)`delete Product p where p.@id == #tv`);
  rs = p.runQuery((Request)`from Wish w select w.@id where w.@id == #wish1`);
  p.assertResultEquals("testDeleteSQLNeoCascade", rs, <["w.@id"], []>);
  rs = p.runQuery((Request)`from Product p select p.@id, p.wishes where p.@id == #tv`);
  p.assertResultEquals("testDeleteSQLNeoCascadeToEnd", rs, <["p.@id", "p.wishes"], []>);
  rs = p.runQuery((Request)`from User u select u.@id, u.wishes where u.@id == #pablo`);
  p.assertResultEquals("testDeleteSQLNeoCascadeFromEnd", rs, <["u.@id", "u.wishes"], [[U("pablo"),  U("wish2")]]>);
    
}


void testUpdateSingleRefSQLNeo(PolystoreInstance p) {
  p.runUpdate((Request)`update Wish w where w.@id == #wish1 set {product: #radio}`);
  rs = p.runQuery((Request)`from Wish w select w.@id, w.product where w.@id == #wish1`);
  p.assertResultEquals("testUpdateRefSQLNeo", rs, <["w.@id", "w.product"], [[ U("wish1"), U("radio")]]>);
  rs = p.runQuery((Request)`from Product p select p.@id, p.wishes where p.@id == #radio`);
  p.assertResultEquals("testUpdateRefSQLNeoTo", rs, <["p.@id", "p.wishes"], [[ U("radio"), U("wish1")], [U("radio"), U("wish2")]]>);
  rs = p.runQuery((Request)`from Product p select p.@id, p.wishes where p.@id == #tv`);
  p.assertResultEquals("testUpdateRefSQLNeoFormerTo", rs, <["p.@id", "p.wishes"], [[ U("tv"), {}]]>);
}

void testNeoReachability(PolystoreInstance p) {
  p.runUpdate((Request)`insert Product { @id: #laptop, name: "MacBook", availabilityRegion: #polygon((1.0 1.0)), productionDate: $2020-03-03$, price: 4000, description: "expensive laptop"}`);
  p.runUpdate((Request)`insert Product {@id: #pc, name: "PC", description: "PC", productionDate:  $2020-04-14$, availabilityRegion: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), price: 250}`);
  p.runUpdate((Request)`insert Concordance { @id: #concordance1, source: #laptop, target: #pc, weight: 5}`);
  //from Product p, Wish w select w.user where w.product == p, p == #laptop
  Request r = (Request)`from Product p1, Product p2, Concordance c select p2.@id, c.@id where p1 == #laptop, p1 -[c]-\>p2`;
  //Request r = (Request)`from Product p1, Product p2, Concordance c select p1.@id, c.@id where p1.@id == #laptop, c.source == p1`;
  rs = p.runQuery(r);
  p.assertResultEquals("testNeoReachability", rs, <["p2.@id", "c.@id"], [[ U("pc"), U("concordance1")]]>);
  
}

void testUpdateAttrNeo(PolystoreInstance p) {
  p.runUpdate((Request)`update Wish w where w.@id == #wish1 set {intensity: 3}`);
  rs = p.runQuery((Request)`from Wish w select w.@id, w.intensity where w.@id == #wish1`);
  p.assertResultEquals("testUpdateAttrNeo", rs, <["w.@id", "w.intensity"], [[ U("wish1"), "3"]]>);
}

void testUpdateSingleRefSQLMongo(PolystoreInstance p) {
  p.runUpdate((Request)`update Biography b where b.@id == #bio1 set {user: #davy}`);
  rs = p.runQuery((Request)`from Biography b select b.@id, b.user where b.@id == #bio1`);
  p.assertResultEquals("testUpdateRefSQLMongo", rs, <["b.@id", "b.user"], [[ U("bio1"), U("davy")]]>);
  rs = p.runQuery((Request)`from User u select u.@id, u.biography where u.@id == #davy`);
  p.assertResultEquals("testUpdateRefSQLMongoTo", rs, <["u.@id", "u.biography"], [[ U("davy"), U("bio1")]]>);
  rs = p.runQuery((Request)`from User u select u.@id, u.biography where u.@id == #pablo`);
  p.assertResultEquals("testUpdateRefSQLMongoFormerTo", rs, <["u.@id", "u.biography"], [[ U("pablo"), {}]]>);
}

void testUpdateManyXrefSQLLocal(PolystoreInstance p) {
  p.runUpdate((Request)`update Product p where p.@id == #tv set {tags +: [#fun, #social]}`);
  p.runUpdate((Request)`update Product p where p.@id == #radio set {tags +: [#fun, #music]}`);
  
  rs = p.runQuery((Request)`from Product p select p.name where p.tags == #fun`);
  p.assertResultEquals("updateManyXrefsSQLLocal", rs, <["p.name"], [["TV"], ["Radio"]]>);
}

void testUpdateManyXrefSQLLocalRemove(PolystoreInstance p) {
  p.runUpdate((Request)`update Product p where p.@id == #tv set {tags +: [#fun, #social]}`);
  p.runUpdate((Request)`update Product p where p.@id == #radio set {tags +: [#fun, #music]}`);
  
  p.runUpdate((Request)`update Product p where p.@id == #tv set {tags -: [#fun]}`);
  p.runUpdate((Request)`update Product p where p.@id == #radio set {tags -: [#fun]}`);
  
  rs = p.runQuery((Request)`from Product p select p.name where p.tags == #social`);
  p.assertResultEquals("updateManyXrefsSQLLocalRemove", rs, <["p.name"], [["TV"]]>);
}


void testUpdateManyXrefSQLLocalSet(PolystoreInstance p) {
  p.runUpdate((Request)`update Product p where p.@id == #tv set {tags: [#social]}`);
  p.runUpdate((Request)`update Product p where p.@id == #radio set {tags: [#music]}`);
  
  rs = p.runQuery((Request)`from Product p select p.name where p.tags == #social`);
  p.assertResultEquals("updateManyXrefsSQLLocalSet", rs, <["p.name"], [["TV"]]>);
}


void testUpdateManyXrefSQLLocalSetToEmpty(PolystoreInstance p) {
  p.runUpdate((Request)`update Product p where p.@id == #tv set {tags: [#social]}`);
  p.runUpdate((Request)`update Product p where p.@id == #radio set {tags: [#music]}`);

  p.runUpdate((Request)`update Product p where p.@id == #tv set {tags: []}`);
  p.runUpdate((Request)`update Product p where p.@id == #radio set {tags: []}`);
  
  rs = p.runQuery((Request)`from Product p select p.name where p.tags == #social`);
  p.assertResultEquals("updateManyXrefsSQLLocalSetToEmpty", rs, <["p.name"], []>);
}


void testUpdateManyContainSQLtoExternal(PolystoreInstance p) {
  p.runUpdateWithBlobs((Request)`insert Review { @id: #newReview, content: "super!", user: #davy, posted: $2020-02-03T02:11:00$, location: #point(1.0 1.0), screenshot: #blob:s5 }`, (U("s5") : "uu"));
  p.runUpdate((Request)`update Product p where p.@id == #tv set {reviews +: [#newReview]}`);
  
  rs = p.runQuery((Request)`from Product p, Review r select r.content where p.@id == #tv, p.reviews == r`);
  p.assertResultEquals("updateManyContainSQLtoExternal", rs, <["r.content"], [["super!"], [""], ["Good TV"]]>);
}

void testUpdateManyContainSQLtoExternalRemove(PolystoreInstance p) {
  p.runUpdate((Request)`update Product p where p.@id == #tv set {reviews -: [#rev2]}`);
  
  rs = p.runQuery((Request)`from Product p, Review r select r.content where p.reviews == r, p.@id == #tv`);
  p.assertResultEquals("updateManyContainSQLtoExternalRemove", rs, <["r.content"], [["Good TV"]]>);
}


void testUpdateManyContainSQLtoExternalSet(PolystoreInstance p) {
  p.runUpdateWithBlobs((Request)`insert Review { @id: #newReview, content: "super!", posted: $2020-02-03T02:11:00$, user: #davy, location: #point(1.0 1.0), screenshot: #blob:s6 }`, (U("s6") : "uu"));
  p.runUpdate((Request)`update Product p where p.@id == #tv set {reviews: [#newReview]}`);
  
  rs = p.runQuery((Request)`from Product p, Review r select r.content where p.@id == #tv, p.reviews == r`);
  p.assertResultEquals("updateManyContainSQLtoExternalSet", rs, <["r.content"], [["super!"]]>);
}

void testUpdateManyContainSQLtoExternalSetToEmpty(PolystoreInstance p) {
  p.runUpdate((Request)`update Product p where p.@id == #tv set {reviews: []}`);
  
  rs = p.runQuery((Request)`from Product p, Review r select r.content where p.reviews == r, p.@id == #tv`);
  p.assertResultEquals("updateManyContainSQLtoExternalSet", rs, <["r.content"], []>);
}

void testUpdateSingleRefSQLMongo(PolystoreInstance p) {
  p.runUpdate((Request)`update Biography b where b.@id == #bio1 set {user: #davy}`);
  rs = p.runQuery((Request)`from Biography b select b.@id, b.user where r.@id == #bio1`);
  p.assertResultEquals("testUpdateRefSQLMongo", rs, <["b.@id", "b.user"], [[ U("bio1"), U("davy")]]>);
  rs = p.runQuery((Request)`from User u select u.@id, u.biography where u.@id == #davy`);
  p.assertResultEquals("testUpdateRefSQLMongoTo", rs, <["u.@id", "u.biography"], [[ U("davy"), U("bio1")]]>);
  rs = p.runQuery((Request)`from User u select u.@id, u.biography where u.@id == #pablo`);
  p.assertResultEquals("testUpdateRefSQLMongoFormerTo", rs, <["u.@id", "u.biography"], [[ U("pablo"), {}]]>);
}




void testSelectViaSQLInverseLocal(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i select i.shelf where i.product == #tv`);
  p.assertResultEquals("selectViaSQLInverseLocal", rs, <["i.shelf"], [["1"], ["1"], ["3"], ["3"]]>);
}

void testSelectViaSQLKidLocal(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i, Product p select i.shelf where p.@id == #tv, p.inventory == i`);
  p.assertResultEquals("selectViaSQLKidLocal", rs, <["i.shelf"], [["1"], ["1"], ["3"], ["3"]]>);
}


void testSQLDateEquals(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Product p select p.name, p.productionDate where p.productionDate == $2020-04-13$`);
  p.assertResultEquals("sqlDateEquals", rs, <["p.name", "p.productionDate"], [["Radio", "2020-04-13"],["TV", "2020-04-13"]]>);
}

void testSQLDatetimeCompare(PolystoreInstance p) {
  p.runUpdate((Request) `insert EntitySmokeTest { @id: #e1, s: "Hoi", t: "Long", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-11-13$, dt: $2020-11-15T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }`);
  p.runUpdate((Request) `insert EntitySmokeTest { @id: #e2, s: "Hoi", t: "Long", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-11-14$, dt: $2020-11-16T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }`);
  rs = p.runQuery((Request)`from EntitySmokeTest e select e.@id, e.d where e.d \> $2020-11-12$ && e.d \< $2020-11-14$`);
  p.assertResultEquals("sqlDateCompare", rs, <["e.@id", "e.d"], [[U("e1"), "2020-11-13"]]>);

  rs = p.runQuery((Request)`from EntitySmokeTest e select e.@id, e.dt where e.dt \> $2020-11-15T00:00:00Z$ && e.dt \< $2020-11-16T00:00:00Z$`);
  p.assertResultEquals("sqlDatetimeCompare", rs, <["e.@id", "e.dt"], [[U("e1"), "2020-11-15T12:04:44Z"]]>);
}

void testMongoDatetimeCompare(PolystoreInstance p) {
  p.runUpdate((Request) `insert EntitySmokeTest2 { @id: #e1, s: "Hoi", t: "Long", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-11-13$, dt: $2020-11-15T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }`);
  p.runUpdate((Request) `insert EntitySmokeTest2 { @id: #e2, s: "Hoi", t: "Long", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-11-14$, dt: $2020-11-16T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }`);
  p.runUpdate((Request) `insert EntitySmokeTest2 { @id: #e3, s: "Hoi", t: "Long", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-11-12$, dt: $2020-11-13T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }`);
  rs = p.runQuery((Request)`from EntitySmokeTest2 e select e.@id, e.d where e.d \> $2020-11-12$ && e.d \< $2020-11-14$`);
  p.assertResultEquals("sqlDateCompare", rs, <["e.@id", "e.d"], [[U("e1"), "2020-11-13"]]>);

  rs = p.runQuery((Request)`from EntitySmokeTest2 e select e.@id, e.dt where e.dt \> $2020-11-15T00:00:00Z$ && e.dt \< $2020-11-16T00:00:00Z$`);
  p.assertResultEquals("sqlDatetimeCompare", rs, <["e.@id", "e.dt"], [[U("e1"), "2020-11-15T12:04:44Z"]]>);
}


void testGISonSQL(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Product p select p.name where #point(2.0 3.0) in p.availabilityRegion`);
  p.assertResultEquals("testGISonSQLLiteralPoint", rs, <["p.name"], [["TV"]]>);
  rs = p.runQuery((Request)`from Product p select p.name where #polygon((2.0 2.0, 3.0 2.0, 3.0 3.0, 2.0 3.0, 2.0 2.0)) in p.availabilityRegion`);
  p.assertResultEquals("testGISonSQLLiteralPolygon", rs, <["p.name"], [["TV"]]>);
  rs = p.runQuery((Request)`from User u select u.name where u.location in #polygon((2.0 2.0, 3.0 2.0, 3.0 3.0, 2.0 3.0, 2.0 2.0))`);
  p.assertResultEquals("testGISonSQLLiteralPolygonRhs", rs, <["u.name"], [["Pablo"]]>);

  rs = p.runQuery((Request)`from Product p, User u select u.name, p.name where u.location in p.availabilityRegion`);
  p.assertResultEquals("testGISonSQLJoin", rs, <["u.name", "p.name"], [["Pablo", "TV"], ["Davy", "Radio"]]>);


  rs = p.runQuery((Request)`from User u select u.name where distance(#point(20.01 30.01), u.location) \< 1000 `);
  p.assertResultEquals("testGISonSQLDistance", rs, <["u.name"], [["Davy"]]>);


  rs = p.runQuery((Request)`from Product p select p.name where #point(2.0 3.0) & p.availabilityRegion`);
  p.assertResultEquals("testGISonSQLIntersectLiteral", rs, <["p.name"], [["TV"]]>);
  
  rs = p.runQuery((Request)`from User u select u.name where u.location & #polygon((2.0 2.0, 3.0 2.0, 3.0 3.0, 2.0 3.0, 2.0 2.0))`);
  p.assertResultEquals("testGISonSQLIntersectLiteral2", rs, <["u.name"], [["Pablo"]]>);

}

void testGISonNeo(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Concordance c select c.@id where #point(2.0 3.0) in c.availabilityRegion`);
  p.assertResultEquals("testGISonNeoLiteralPoint", rs, <["c.@id"], [[U("TV")]]>);
  rs = p.runQuery((Request)`from Concordance c select c.@id where #polygon((2.0 2.0, 3.0 2.0, 3.0 3.0, 2.0 3.0, 2.0 2.0)) in c.availabilityRegion`);
  p.assertResultEquals("testGISonNeoLiteralPolygon", rs, <["c.@id"], [[U("TV")]]>);
  rs = p.runQuery((Request)`from Concordance c select c.@id where c.location in #polygon((2.0 2.0, 3.0 2.0, 3.0 3.0, 2.0 3.0, 2.0 2.0))`);
  p.assertResultEquals("testGISonNeoLiteralPolygonRhs", rs, <["c.@id"], [[U("Pablo")]]>);

  rs = p.runQuery((Request)`from Concordance c select c.@id where c.location in c.availabilityRegion`);
  p.assertResultEquals("testGISonNeoJoin", rs, <["c.@id"], [[U("Pablo")]]>);


  rs = p.runQuery((Request)`from Concordance c select c.@id where #point(2.0 3.0) & c.availabilityRegion`);
  p.assertResultEquals("testGISonNeoIntersectLiteral", rs, <["c.@id"], [["TV"]]>);
  

}

void testGISonMongo(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Review r select r.@id where distance(#point(2.0 3.0), r.location) \< 200.0`);
  p.assertResultEquals("testGISonMongo - distance query", rs, <["r.@id"], [[U("rev1")]]>);

  rs = p.runQuery((Request)`from Review r select r.@id where distance(#point(2.0 3.0), r.location) \<= 200.0`);
  p.assertResultEquals("testGISonMongo - distance query2", rs, <["r.@id"], [[U("rev1")]]>);

  rs = p.runQuery((Request)`from Review r select r.@id where distance(r.location, #point(2.0 3.0)) \>= 200.0`);
  p.assertResultEquals("testGISonMongo - mindistance query", rs, <["r.@id"], [[U("rev2")],[U("rev3")]]>);

  rs = p.runQuery((Request)`from Review r select r.@id where distance(r.location, #point(2.0 3.0)) \> 200.0`);
  p.assertResultEquals("testGISonMongo - mindistance query", rs, <["r.@id"], [[U("rev2")],[U("rev3")]]>);
  
  rs = p.runQuery((Request)`from Review r select r.@id where r.location in #polygon((2.0 2.0, 3.0 2.0, 3.0 3.0, 2.0 3.0, 2.0 2.0))`);
  p.assertResultEquals("testGISonMongo - contained in polygon", rs, <["r.@id"], [[U("rev1")],[U("rev3")]]>);

  rs = p.runQuery((Request)`from Review r select r.@id where r.location & #polygon((2.0 2.0, 3.0 2.0, 3.0 3.0, 2.0 3.0, 2.0 2.0))`);
  p.assertResultEquals("testGISonMongo - intersect with polygon", rs, <["r.@id"], [[U("rev1")],[U("rev3")]]>);

  rs = p.runQuery((Request)`from Review r select r.@id where r.location & #point(2.0 3.0)`);
  p.assertResultEquals("testGISonMongo - intersect with point", rs, <["r.@id"], [[U("rev1")]]>);
}


void testGISonCrossMongoSQL(PolystoreInstance p) {
  // TODO: Tijs add support for cross delayed clauses
  rs = p.runQuery((Request)`from Product p, Review r select r.@id, p.name where r.location in p.availabilityRegion`);
  p.assertResultEquals("testGISonCrossMongoSQL - contained", rs, <["r.@id", "p.name"], [[U("rev1"), "TV"], [U("rev3"), "TV"], [U("rev2"), "Radio"]]>);
  
  rs = p.runQuery((Request)`from User u, Review r select r.@id, u.name where distance(r.location, u.location) \< 200`);
  p.assertResultEquals("testGISonCrossMongoSQL - distance", rs, <["r.@id", "u.name"], [[U("rev1"), "Pablo"], [U("rev2"), "Davy"]]>);
}

void testGISProblemsOnEdges(PolystoreInstance p) {
    //p.runUpdate((Request)`insert Product { @id: #p1, name: "Testing", availabilityRegion: #polygon(( 47.695061728395 4.61025, 47.82962962963 4.61025,  47.82962962963 4.79525,  47.695061728395 4.79525,  47.695061728395 4.61025 )) }`);
    //p.runUpdate((Request)`insert Review { @id: #r1, location: #point(47.82962962963 4.79525) }`); //edge
    //p.runUpdate((Request)`insert Review { @id: #r2, location: #point(47.76 4.72) }`); // middle
    
    rs = p.runQuery((Request)`from Product p, Review r select r.@id, p.@id where r.location in p.availabilityRegion && p.productionDate \> $2020-01-01$`);
    p.assertResultEquals("testGISEdges - SQL First - GIS on mongo", rs, <["r.@id", "p.@id"], [[U("rev1"), U("tv")], [U("rev2"), U("radio")], [U("rev3"), U("tv")]]>);
    rs = p.runQuery((Request)`from Product p, Review r select r.@id, p.@id where r.location in p.availabilityRegion && r.posted \> $2020-01-01T00:00:00Z$`);
    p.assertResultEquals("testGISEdges - Mongo First - GIS on SQL", rs, <["r.@id", "p.@id"], [[U("rev1"), U("tv")], [U("rev2"), U("radio")], [U("rev3"), U("tv")]]>);
}

void testGISPrint(PolystoreInstance p) {
    rs = p.runQuery((Request)`from Product p select p.availabilityRegion`);
    p.assertResultEquals("GIS Print - SQL", rs, <["p.availabilityRegion"], [["POLYGON ((10 10, 40 10, 40 40, 10 40, 10 10))"],["POLYGON ((1 1, 4 1, 4 4, 1 4, 1 1))"]]>);


    rs = p.runQuery((Request)`from Review r select r.location`);
    p.assertResultEquals("GIS Print - Mongo", rs, <["r.location"], [["POINT (2 3)"],["POINT (20 30)"], ["POINT (3 2)"]]>);
}

void testDateTimePrint(PolystoreInstance p) {
    rs = p.runQuery((Request)`from User u select u.created where u.@id == #davy`);
    p.assertResultEquals("Print datetime - SQL", rs, <["u.created"],[["2020-01-02T15:24:00Z"]]>);

    rs = p.runQuery((Request)`from Review r select r.posted where r.@id == #rev1`);
    p.assertResultEquals("Print datetime - Mongo", rs, <["r.posted"],[["2020-02-03T01:11:00Z"]]>);
    
}


void testInsertNeo(PolystoreInstance p) {
  // TODO: this shows the cyclic reference problem we still need to solve.
  // NB: we have to insert the product first.

  // inventory: [#laptop1, #laptop2], 
  p.runUpdate((Request) `insert User { @id: #paul, name: "Paul", location: #point(2.0 3.0), photoURL: "klint",
                          '  address: "aa",
                          '  avatarURL: "bb",
                          '  created: $2020-01-02T12:24:00$,
	                      '  billing: address( street: "Eigth", city: "Ams"
	                      '   , zipcode: zip(nums: "1234", letters: "ab")
	                      '   , location: #point(2.0 3.0))}`);
  rs = p.runQuery((Request)`from User u select u.@id, u.name where u.name == "Paul"`);
  p.assertResultEquals("users were inserted", rs, <["u.@id", "u.name"], [[U("paul"), "Paul"]]>);
	 
  p.runUpdate((Request) `insert Wish { @id: #wish3, intensity: 7, user: #paul, product: #tv }`);
	
  rs = p.runQuery((Request)`from Wish w select w.@id, w.intensity where w.@id ==#wish3`);
  p.assertResultEquals("items were inserted", rs, <["w.@id", "w.intensity"], [
	    [U("wish3"), "7"]
	  ]>);
}

void testEscapedStrings(PolystoreInstance p) {
    p.runUpdate((Request)`insert Biography { @id: #escp1, content: "Es\\tcaped\\"", user: #pablo}`);
    p.runUpdate((Request)`insert Tag { @id: #escp2, name: "Es\\tcaped\\""}`);

    p.runUpdate((Request) `insert User { @id: #escp3, name: "Es\\tcaped\\"", location: #point(2.0 3.0), photoURL: "Es\\tcaped\\"",
                          '  created: $2020-01-02T12:24:00$,
                          '  address: "aa",
                          '  avatarURL: "bb",
	                      '  billing: address( street: "Eigth", city: "Ams"
	                      '   , zipcode: zip(nums: "1234", letters: "ab")
	                      '   , location: #point(2.0 3.0))}`);
    
    rs = p.runQuery((Request)`from Biography b select b.content where b == #escp1`);
    p.assertResultEquals("escaped chars in strings on mongo", rs, <["b.content"], [["Es\tcaped\""]]>);

    rs = p.runQuery((Request)`from Tag t select t.name where t == #escp2`);
    p.assertResultEquals("escaped chars in strings on mariadb", rs, <["t.name"], [["Es\tcaped\""]]>);

    rs = p.runQuery((Request)`from User u select u.name, u.photoURL where u == #escp3`);
    p.assertResultEquals("escaped chars in strings on cassandra", rs, <["u.name", "user__Stuff_kv_0.photoURL"], [["Es\tcaped\"", "Es\tcaped\""]]>);
}

void testPreparedUpdatesSimpleSQL(PolystoreInstance p) {
	p.runPreparedUpdate((Request) `insert Product { @id: ??id, name: ??name, description: ??description, availabilityRegion: #polygon((1.0 1.0)), productionDate: $2020-01-01$, price: 2000 }`,
						  ["id", "name", "description"],
						  ["uuid", "string", "string"],
						  [
						   [U("guitar"), "Guitar", "Tanglewood"],
				           [U("voilin"), "Violin", "Stradivarius"]]);
	rs = p.runQuery((Request) `from Product p select p.@id, p.name, p.description`);		    
	p.assertResultEquals("prepared insert statement on sql (simple)", rs,   
		<["p.@id", "p.name","p.description"],
		[[U("guitar"), "Guitar","Tanglewood"],[U("violin"),"Violin","Stradivarius"],[U("radio"), "Radio","Loud"],[U("tv"), "TV","Flat"]]>);
}

void testPreparedUpdatesSimpleSQLUpdate(PolystoreInstance p) {
	p.runPreparedUpdate((Request) `update Product p where p.@id == ??id set { name: ??name, description: ??description }`,
						  ["id", "name", "description"],
						  ["uuid", "string", "string"],
						  [
						   [U("tv"), "TELEVISION", "SONY"],
				           [U("radio"), "RADIO", "SAMSUNG"]]);
	rs = p.runQuery((Request) `from Product p select p.name, p.description`);		    
	p.assertResultEquals("prepared insert statement on sql (simple)", rs,   
		<["p.name","p.description"],
		[["RADIO","SAMSUNG"],["TELEVISION","SONY"]]>);
}

void testPreparedUpdatesSimpleSQLWithRefs(PolystoreInstance p) {
	p.runPreparedUpdate((Request) `insert User { name: ??name, location: #point(2.0 3.0), 
                          '  created: $2020-01-02T12:24:00$,
	                      '   photoURL: "generic",
	                      '   avatarURL: "blocky",
	                      '   biography: ??bio,
	                      '   address: "x",
	                      '   billing: address( street: ??street, city: "Ams"
	                      '   , zipcode: zip(nums: "1234", letters: "ab")
	                      '   , location: #point(2.0 3.0))}`,
						  ["name", "bio", "street"],
						  ["string", "uuid", "string"],
						  [
						   ["Tijs", U("bio1"), "First"],
				           ["Paul", U("bio1"), "Second"]]);
				           
    // This query does not work (Cassandra field condition)		           
	//rs = p.runQuery((Request) `from User u select u.name, u.biography where u.photoURL == "generic"`);
	rs = p.runQuery((Request) `from User u select u.name, u.biography where u.address == "x"`);		    
	p.assertResultEquals("prepared insert statement on sql (simple)", rs,   
		<["u.name", "u.biography"],
		[["Tijs",U("bio1")],["Paul",U("bio1")]]>);
}

void testPreparedUpdatesSimpleMongo(PolystoreInstance p) {
	p.runPreparedUpdate((Request) `insert Review { content: ??content, posted: $2020-02-03T22:11:00$, location: #point(2.0 3.0) }`,
						  ["content"],
						  ["string"],
						  [
						   ["Awful TV"],
				           ["Excellent TV"]]);
	rs = p.runQuery((Request) `from Review r select r.content`);		    
	p.assertResultEquals("prepared insert statement on mongo (simple)", rs,   
		<["r.content"],
		[["Good TV"],
		 [""],
		 ["***"],
		 ["Awful TV"],
		 ["Excellent TV"]]>);
}

void testPreparedUpdatesSimpleMongoWithRefs(PolystoreInstance p) {
	p.runPreparedUpdate((Request) `insert Review { content: ??content, user: ??user, product: ??product, posted: ??posted, location: #point(2.0 3.0) }`,
						  ["content", "user", "product", "posted"],
						  ["string", "uuid", "uuid", "datetime"],
						  [
						   ["Awful TV", U("tv"), U("pablo"), "2020-01-02T12:22:00Z"],
				           ["Excellent TV", U("tv"), U("davy"), "2020-01-02T12:22:00Z" ]]);
	rs = p.runQuery((Request) `from Review r select r.content, r.user, r.product, r.posted where r.product = #tv`);		    
	p.assertResultEquals("prepared insert statement on mongo with references (simple)", rs,   
		<["r.content","r.user","r.product", "r.posted"],
		[["Good TV", U("pablo"), U("tv"), "2020-01-02T12:22:00Z"],
		 ["Awful TV", U("pablo"), U("tv"), "2020-01-02T12:22:00Z"],
		 ["Excellent TV", U("davy"), U("tv"), "2020-01-02T12:22:00Z"]]>);
}


void test1(PolystoreInstance p) {
	rs = p.runQuery((Request) `from Product p select p.name`);
	p.assertResultEquals("name is selected from product", rs, <["p.name"],[["Radio"],["TV"]]>);
}

void test2(PolystoreInstance p) {
	rs = p.runQuery((Request) `from Product p select p.@id`);
	p.assertResultEquals("product ids are selected", rs, <["p.@id"],[[U("radio")],[U("tv")]]>);
}

void test3(PolystoreInstance p) {
	rs = p.runQuery((Request) `from Review r select r.content`);
	p.assertResultEquals("review content is selected", rs,  <["r.content"],[["Good TV"],[""],["***"]]>);
}

void test4(PolystoreInstance p) {
	rs = p.runQuery((Request) `from Review r select r.@id`);
	p.assertResultEquals("review ids are selected", rs,  <["r.@id"],[[U("rev1")],[U("rev2")],[U("rev3")]]>);
}

void test5(PolystoreInstance p) {
	rs = p.runQuery((Request) `from User u select u.biography.content where u == #pablo`);
	p.assertResultEquals("two-level navigation to attribute", rs,  <["biography_0.content"],[["Chilean"]]>);
}

void test6(PolystoreInstance p) {
	rs = p.runQuery((Request) `from User u, Biography b select b.content where u.biography == b, u == #pablo`);
	p.assertResultEquals("navigating via where-clauses", rs,   <["b.content"],[["Chilean"]]>);
}

void test7(PolystoreInstance p) {
	rs = p.runQuery((Request) `from User u, Review r select u.name, r.user where u.reviews == r, r.content == "***"`);
	p.assertResultEquals("fields from different entities", rs, <["u.name","r.user"],[["Davy",U("davy")]]>);
}

void test8(PolystoreInstance p) {
	p.runUpdate((Request) `update Biography b where b.@id == #bio1 set { content:  "Simple" }`);
	rs = p.runQuery((Request) `from Biography b select b.content where b.@id == #bio1`);
	p.assertResultEquals("basic update of attribute on mongo", rs, <["b.content"],[["Simple"]]>);
}

void test9(PolystoreInstance p) {
	p.runUpdate((Request) `update User u where u.@id == #pablo set { address:  "Fresia 8" }`);
	rs = p.runQuery((Request) `from User u select u.address where u.@id == #pablo`);
	p.assertResultEquals("basic update of attribute on sql", rs, <["u.address"],[["Fresia 8"]]>);
}


void test10(PolystoreInstance p) {
	p.runPreparedUpdate((Request) `insert Product { name: ??name, description: ??description, availabilityRegion: #polygon((1.0 1.0)), productionDate: $2020-01-01$, price: 2000 }`,
						  ["name", "description"],
						  ["string", "string"],
						  [
						   ["IPhone", "Apple"],
				           ["Samsung S10", "Samsung"]]);
	rs = p.runQuery((Request) `from Product p select p.name, p.description`);		    
	p.assertResultEquals("prepared insert statement on sql", rs,   
		<["p.name","p.description"],
		[["Samsung S10","Samsung"],["IPhone","Apple"],["Radio","Loud"],["TV","Flat"]]>);

}

void test11(PolystoreInstance p) {
	rs = p.runQuery((Request) `from User u select u.name where u.biography == #bio1`);
	p.assertResultEquals("filter on external relation in sql", rs, <["u.name"],[["Pablo"]]>);
}



void test12(PolystoreInstance p) {
	p.runUpdate((Request) `insert User { @id: #tijs, name: "Tijs", <KeyVal aBillingKeyVal>, created: $2020-01-02T12:13:00$, location: #point(1.0 1.0), address: "a", avatarURL: "b", photoURL: "c" }`);
	rs = p.runQuery((Request) `from User u select u.@id where u.@id == #tijs`);
	p.assertResultEquals("basic insert in sql", rs, <["u.@id"],[[U("tijs")]]>);
}

void test13(PolystoreInstance p) {
	res = p.runUpdate((Request) `insert User { name: "Tijs", <KeyVal aBillingKeyVal>, location: #point(1.0 1.0), created: $2020-01-02T12:13:00$, address: "a", avatarURL: "b", photoURL: "c" }`);
	p.assertEquals("one insert is one object inserted", size(res), 1);
	uuid =res[0];
	rs = p.runQuery([Request] "from User u select u.@id where u.@id == #<uuid>");
	p.assertResultEquals("generated id is in the result", rs, <["u.@id"],[["<uuid>"]]>);
}


void testMariaDBFields(PolystoreInstance p) {
    p.runUpdate((Request) `insert ReferenceTest { @id: #r1, r: 2}`);
	p.runUpdate((Request) `insert EntitySmokeTest { @id: #e1, s: "Hoi", t: "Long", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-01-02$, dt: $2020-03-04T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), ref: #r1 }`);
	rs = p.runQuery((Request) `from EntitySmokeTest e select e.s, e.t, e.i, e.r, e.f, e.b, e.d, e.dt, e.pt, e.pg, e.ref where e.@id == #e1`);
	p.assertResultEquals("Working regular values", rs, <
	   ["e.s", "e.t", "e.i", "e.r", "e.f",  "e.b", "e.d", "e.dt", "e.pt", "e.pg", "e.ref"],
	   [["Hoi", "Long", "3", "12312312321", "20.001", true, "2020-01-02", "2020-03-04T12:04:44Z", "POINT (0.2 0.4)", "POLYGON ((1 1, 4 1, 4 4, 1 4, 1 1))", U("r1")]]>);

	p.runPreparedUpdate((Request) `insert EntitySmokeTest { @id: ??id, s: ??s, t: ??t, i: ??i, r: ??r, f: ??f, b: ??b, d: ??d, dt: ??dt, pt: ??pt, pg: ??pg, ref: ??ref }`,
	   ["id", "s","t","i", "r","f", "b", "d", "dt", "pt", "pg", "ref"],
	   ["uuid", "string", "string", "int", "bigint", "float", "bool", "date", "datetime", "point", "polygon", "uuid"],
       [[U("e2"), "Hoi", "Long", "3", "12312312321", "20.01", "true", "2020-01-02", "2020-03-04T12:04:44Z", "POINT (0.2 0.4)", "POLYGON ((1 1, 4 1, 4 4, 1 4, 1 1))", U("r1")]]
	);
	rs = p.runQuery((Request) `from EntitySmokeTest e select e.s, e.t, e.i, e.r, e.f, e.b, e.d, e.dt, e.pt, e.pg, e.ref where e.@id == #e2`);
	p.assertResultEquals("Working parameterized", rs, <
	   ["e.s", "e.t", "e.i", "e.r", "e.f",  "e.b", "e.d", "e.dt", "e.pt", "e.pg", "e.ref"],
	   [["Hoi", "Long", "3", "12312312321", "20.01", true, "2020-01-02", "2020-03-04T12:04:44Z", "POINT (0.2 0.4)", "POLYGON ((1 1, 4 1, 4 4, 1 4, 1 1))", U("r1")]]>);
}
void testMongoDBFields(PolystoreInstance p) {
	p.runUpdate((Request) `insert EntitySmokeTest2 { @id: #e1, s: "Hoi", t: "Long", i: 3, r: 12312312321, f: 20.001, b: true, d: $2020-01-02$, dt: $2020-03-04T12:04:44Z$, pt: #point(0.2 0.4), pg: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)) }`);
	rs = p.runQuery((Request) `from EntitySmokeTest2 e select e.s, e.t, e.i, e.r, e.f, e.b, e.d, e.dt, e.pt, e.pg where e.@id == #e1`);
	p.assertResultEquals("Working regular values", rs, <
	   ["e.s", "e.t", "e.i", "e.r", "e.f",  "e.b", "e.d", "e.dt", "e.pt", "e.pg"],
	   [["Hoi", "Long", "3", "12312312321", "20.001", true, "2020-01-02", "2020-03-04T12:04:44Z", "POINT (0.2 0.4)", "POLYGON ((1 1, 4 1, 4 4, 1 4, 1 1))"]]>);
	p.runPreparedUpdate((Request) `insert EntitySmokeTest2 { @id: ??id, s: ??s, t: ??t, i: ??i, r: ??r, f: ??f, b: ??b, d: ??d, dt: ??dt, pt: ??pt, pg: ??pg }`,
	   ["id", "s","t","i", "r","f", "b", "d", "dt", "pt", "pg"],
	   ["uuid", "string", "string", "int", "bigint", "float", "bool", "date", "datetime", "point", "polygon"],
       [[U("e2"), "Hoi", "Long", "3", "12312312321", "20.001", "true", "2020-01-02", "2020-03-04T12:04:44Z", "POINT (0.2 0.4)", "POLYGON ((1 1, 4 1, 4 4, 1 4, 1 1))"]]
	);
	rs = p.runQuery((Request) `from EntitySmokeTest2 e select e.s, e.t, e.i, e.r, e.f, e.b, e.d, e.dt, e.pt, e.pg where e.@id == #e2`);
	p.assertResultEquals("Working parameterized", rs, <
	   ["e.s", "e.t", "e.i", "e.r", "e.f",  "e.b", "e.d", "e.dt", "e.pt", "e.pg"],
	   [["Hoi", "Long", "3", "12312312321", "20.001", true, "2020-01-02", "2020-03-04T12:04:44Z", "POINT (0.2 0.4)", "POLYGON ((1 1, 4 1, 4 4, 1 4, 1 1))"]]>);
}

TestExecuter executer(Log log = NO_LOG(), bool doTypeChecking = true) = initTest(setup, HOST, PORT, USER, PASSWORD, log = log, doTypeChecking = doTypeChecking);

void runTest(void(PolystoreInstance) t, Log log = NO_LOG(), bool runSetup = true, bool runTestsInSetup = false, bool doTypeChecking = true) {
	 executer(log = log, doTypeChecking = doTypeChecking).runTest(t, runSetup, runTestsInSetup); 
}

void runTests(list[void(PolystoreInstance)] ts, Log log = NO_LOG(), bool runTestsInSetup = false, bool doTypeChecking = true) {
	executer(log = log, doTypeChecking = doTypeChecking).runTests(ts, runTestsInSetup); 
}

Schema fetchSchema() {
	Schema s = executer().fetchSchema();
	return s;
}

void printSchema() {
	executer().printSchema();
}


void testDeleteAllSQLBasic(PolystoreInstance p) {
  p.runUpdate((Request)`delete Tag t`);
  rs = p.runQuery((Request)`from Tag t select t.@id`);
  p.assertResultEquals("deleteAllSQLBasic", rs, <["t.@id"], []>);
}

void runTests(Log log = NO_LOG(), bool runTestsInSetup = false) {
	tests = 
	  [ testBasicAggregationNativeSQL
	  , testBasicAggregationNativeMongo
	  , testBasicMongoDBWhereClauses
	  , testLimit
	  , testLimitAndOrder
	  , testOrdering
	  , testKeyValueFeatures
	  , testCustomDataTypes
	  , testDefaultAttrInsertion
	  , testLoneVars
	  , testInsertSingleValuedSQLCross
	  , testInsertManyValuedSQLLocal
	  , testDeleteAllSQLBasic
	  , testDeleteAllWithCascade
	  , testDeleteKidsRemovesParentLinksSQLLocal
	  , testDeleteKidsRemovesParentLinksSQLCross

	  , testMariaDBFields
	  , testMongoDBFields

	  , testInsertManyXrefsSQLLocal
	  , testInsertManyContainSQLtoExternal

	  , testSelectViaSQLKidLocal
	  , testSelectViaSQLInverseLocal 

	  , testUpdateManyXrefSQLLocal
	  , testUpdateManyXrefSQLLocalRemove
	  , testUpdateManyXrefSQLLocalSet
	  , testUpdateManyXrefSQLLocalSetToEmpty
	  
	  , testUpdateManyContainSQLtoExternal
	  , testUpdateManyContainSQLtoExternalRemove
	  , testUpdateManyContainSQLtoExternalSet
	  , testUpdateManyContainSQLtoExternalSetToEmpty
	  
	  , testUpdateSingleRefSQLMongo
	  
	  , testSQLDateEquals
	  
	  , testGISonSQL
	  , testGISonMongo
	  , testGISonCrossMongoSQL
	  , testGISPrint
	  , testBlobs
	  , testEscapedStrings
	  , testInsertSQLNeo
	  , testDeleteNeoAll
	  , testDeleteSQLNeoSimple
	  , testDeleteSQLNeoCascade
	  , testUpdateSingleRefSQLNeo
	  , testUpdateAttrNeo
	  , testInsertNeo
	  , testNeoReachability
	  , testUpdateAttrNeo
	  , testDeleteAllSQLNeoWithCascade
	  //, testDeleteAllSQLMongoNeoWithCascade
	  
	  , test1
	  , test2
	  , test3
	  , test4
	  , test5
	  , test6
	  , test7
	  , test8
	  , test9
	  , test10
	  , test11
	  , test12
	  , test13
	];
	runTests(tests, log = log, runTestsInSetup = runTestsInSetup, doTypeChecking = false);
}

void runNeoTests(Log log = NO_LOG()) {
	tests = 
	  [ 
	  testInsertSQLNeo,
	  testDeleteSQLNeoSimple,
	  testDeleteSQLNeoCascade,
	  testUpdateSingleRefSQLNeo,
	  testUpdateAttrNeo,
	  testInsertNeo,
	  testNeoReachability,
	  testUpdateAttrNeo
	];
	runTests(tests, log = log);
}

