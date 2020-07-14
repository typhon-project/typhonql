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
 

private str U(str u) = pUUID(u);
private str base64(str b) = base64Encode(b);

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
	                      '   photoURL: "moustache",
	                      '   avatarURL: "blocky",
	                      '   address: "alsoThere",
	                      '   billing: address( street: "Seventh", city: "Ams"
	                      '   , zipcode: zip(nums: "1234", letters: "ab")
	                      '   , location: #point(2.0 3.0))}`);
	p.runUpdate((Request) `insert User { @id: #davy, name: "Davy", location: #point(20.0 30.0), photoURL: "beard",
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
	    [["moustache", {}, "Pablo"], ["beard", {}, "Davy"]]>);
	  
	}
	
	p.runUpdate((Request) `insert Product {@id: #tv, name: "TV", description: "Flat", productionDate:  $2020-04-13$, availabilityRegion: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), price: 20 }`);
	p.runUpdate((Request) `insert Product {@id: #radio, name: "Radio", description: "Loud" , productionDate:  $2020-04-13$, availabilityRegion: #polygon((10.0 10.0, 40.0 10.0, 40.0 40.0, 10.0 40.0, 10.0 10.0)), price: 30 }`);
	
	
	
	if (doTest) {
	  rs = p.runQuery((Request)`from Product p select p.@id, p.name, p.description, p.productionDate`); // TODO: include polygon in this test
	  p.assertResultEquals("products were inserted", rs, <["p.@id", "p.name", "p.description", "p.productionDate"], 
	     [[U("tv"), "TV", "Flat", "2020-04-13"], [U("radio"), "Radio", "Loud", "2020-04-13"]]>);
	}
	
	p.runUpdateWithBlobs((Request) `insert Review { @id: #rev1, content: "Good TV", user: #pablo, product: #tv, location: #point(2.0 3.0), screenshot: #blob:s1 }`, (U("s1") : "xx"));
	p.runUpdateWithBlobs((Request) `insert Review { @id: #rev2, content: "", user: #davy, product: #tv, location: #point(20.0 30.0), screenshot: #blob:s2 }`, (U("s2") : "yy"));
	p.runUpdateWithBlobs((Request) `insert Review { @id: #rev3, content: "***", user: #davy, product: #radio, location: #point(3.0 2.0), screenshot: #blob:s3 }`, (U("s3") : "zz"));
	
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

    if (doTest) {
      rs = p.runQuery((Request)`from Tag t select t.@id, t.name`);
      p.assertResultEquals("tags were inserted", rs, <["t.@id", "t.name"], [
        [U("fun"), "fun"],
        [U("kitchen"), "kitchen"],
        [U("music"), "music"],
        [U("social"), "social"]
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
	    [U("tv1"), 1, U("tv")],
	    [U("tv2"), 1, U("tv")],
	    [U("tv3"), 3, U("tv")],
	    [U("tv4"), 3, U("tv")],
	    [U("radio1"), 2, U("radio")],
	    [U("radio2"), 2, U("radio")]
	  ]>);
	  
	  rs = p.runQuery((Request)`from Product p select p.inventory where p.@id == #tv`);
	  p.assertResultEquals("tv inventory obtained", rs, <["p.inventory"], [[U("tv1")], [U("tv2")], [U("tv3")], [U("tv4")]]>);
	  
	  rs = p.runQuery((Request)`from Product p select p.inventory where p.@id == #radio`);
	  p.assertResultEquals("radio inventory obtained", rs, <["p.inventory"], [[U("radio1")], [U("radio2")]]>);
	}	
	
	p.runUpdate((Request) `insert Wish { @id: #wish1, intensity: 7, user: #pablo, product: #tv }`);
	
	if (doTest) {
	  rs = p.runQuery((Request)`from Wish w select w.@id`);
	  p.assertResultEquals("whish was inserted", rs, <["w.@id"], [
	    [U("wish1")]
	  ]>);
	  
	  rs = p.runQuery((Request)`from Product p select p.wish where p.@id == #tv`);
	  p.assertResultEquals("wish obtained from product", rs, <["p.wish"], [[U("wish1")]]>);
	  
	  rs = p.runQuery((Request)`from User u select u.wish where u.@id == #pablo`);
	  p.assertResultEquals("wish obtained from user", rs, <["u.wish"], [[U("wish1")]]>);
	}
}

void testSetup(PolystoreInstance p, Log log = NO_LOG()) {
  println("Doing sanity check on setup");
  p.resetDatabases();
  setup(p, true);
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

/*

The below test fails, but the results seem equal...
pected: <["i.shelf","i.product"],[
  [2,"a398fb77-df76-3615-bdf5-7cd65fd0a7c5"], [2,"a398fb77-df76-3615-bdf5-7cd65fd0a7c5"],
   [1,"c9a1fdac-6e08-3dd8-9e71-73244f34d7b3"],[1,"c9a1fdac-6e08-3dd8-9e71-73244f34d7b3"],
  [3,"c9a1fdac-6e08-3dd8-9e71-73244f34d7b3"],[3,"c9a1fdac-6e08-3dd8-9e71-73244f34d7b3"]]>, 
actual: <["i.shelf","i.product"],[
  [2,"a398fb77-df76-3615-bdf5-7cd65fd0a7c5"], [2,"a398fb77-df76-3615-bdf5-7cd65fd0a7c5"],
  [1,"c9a1fdac-6e08-3dd8-9e71-73244f34d7b3"], [1,"c9a1fdac-6e08-3dd8-9e71-73244f34d7b3"]]>
  [3,"c9a1fdac-6e08-3dd8-9e71-73244f34d7b3"], [3,"c9a1fdac-6e08-3dd8-9e71-73244f34d7b3"],

*/

void testLoneVars(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i select i`);
  rs = <rs<0>, {*rs<1>}>;
  p.assertEquals("all features from item retrieved", rs, <["i.picture", "i.shelf", "i.product"]
    , {
        [base64("aa"), 1, U("tv")],
        [base64("bb"), 1, U("tv")],
        [base64("cc"), 3, U("tv")],
        [base64("dd"), 3, U("tv")],
        [base64("ee"), 2, U("radio")],
        [base64("ff"), 2, U("radio")]
    }>);
    
  rs = p.runQuery((Request)`from Biography b select b`);
  p.assertEquals("all features from biography retrieved", rs, <["b.content", "b.user"]
    , [["Chilean", U("pablo")]]>);
    
}

void testCustomDataTypes(PolystoreInstance p) {
  p.runUpdate((Request) `insert User { @id: #jurgen, name: "Jurgen", location: #point(2.0 3.0), 
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
  
  p.runUpdateWithBlobs((Request)`insert Review { @id: #newReview, content: "expensive", user: #davy, location: #point(1.0 1.0), screenshot: #blob:s4 }`, (U("s4") : "uu"));
  
  rs = p.runQuery((Request)`from Review r select r.screenshot where r.@id == #newReview`);
  p.assertResultEquals("Blob in Mongo", rs, <["r.screenshot"], [["dXU="]]>);
}
  

void testDeleteAllSQLBasic(PolystoreInstance p) {
  p.runUpdate((Request)`delete Tag t`);
  rs = p.runQuery((Request)`from Tag t select t.@id`);
  p.assertResultEquals("deleteAllSQLBasic", rs, <["t.@id"], []>);
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
    [[U("fun")], [U("kitchen")], [U("music")], [U("social")]]>);
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

void testInsertManyContainSQLtoExternal(PolystoreInstance p) {
  p.runUpdateWithBlobs((Request)`insert Review { @id: #newReview, content: "expensive", user: #davy, location: #point(1.0 1.0), screenshot: #blob:s4 }`, (U("s4") : "uu"));
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

void testInsertSQLNeo(PolystoreInstance p) {
  p.runUpdate((Request)`insert Product {@id: #laptop, name: "Laptop", wish: #wish1, description: "Practical", productionDate:  $2020-04-14$, availabilityRegion: #polygon((1.0 1.0, 4.0 1.0, 4.0 4.0, 1.0 4.0, 1.0 1.0)), price: 150}`);
  rs = p.runQuery((Request)`from Wish w select w.product where w.@id == #wish1`);
  p.assertResultEquals("testInsertSQLNeoToEnd", rs, <["w.product"], [[U("laptop")]]>);
  
  p.runUpdate((Request) `insert User { @id: #tijs, name: "Tijs", location: #point(2.0 3.0), 
	                      '   photoURL: "cwi",
	                      '   avatarURL: "something",
	                      '   address: "somwehere",
	                      '   wish: #wish1,
	                      '   billing: address( street: "Eigth", city: "Ams"
	                      '   , zipcode: zip(nums: "2345", letters: "cd")
	                      '   , location: #point(2.0 3.0))}`);
	                      	                      
  rs = p.runQuery((Request)`from Wish w select w.user where w.@id == #wish1`);
  p.assertResultEquals("testInsertSQLNeoNeoFromEnd", rs, <["w.user"], [[U("tijs")]]>);
  
}

void testDeleteSQLNeoSimple(PolystoreInstance p) {
  p.runUpdate((Request)`delete Wish w where w.@id == #wish1`);
  rs = p.runQuery((Request)`from Wish w select w.@id where w.@id == #wish1`);
  p.assertResultEquals("testDeleteSQLNeoSimple", rs, <["w.@id"], []>);
  rs = p.runQuery((Request)`from Product p select p.@id, p.wish where p.@id == #tv`);
  p.assertResultEquals("testDeleteSQLNeoSimpleToEnd", rs, <["p.@id", "p.wish"], [[U("tv"), {}]]>);
  rs = p.runQuery((Request)`from User u select u.@id, u.wish where u.@id == #pablo`);
  p.assertResultEquals("testDeleteSQLNeoSimpleFromEnd", rs, <["u.@id", "u.wish"], [[U("pablo"), {}]]>);
  
}

void testDeleteSQLNeoCascade(PolystoreInstance p) {
  p.runUpdate((Request)`delete Product p where p.@id == #tv`);
  rs = p.runQuery((Request)`from Wish w select w.@id where w.@id == #wish1`);
  p.assertResultEquals("testDeleteSQLNeoCascade", rs, <["w.@id"], []>);
  rs = p.runQuery((Request)`from Product p select p.@id, p.wish where p.@id == #tv`);
  p.assertResultEquals("testDeleteSQLNeoCascadeToEnd", rs, <["p.@id", "p.wish"], []>);
  rs = p.runQuery((Request)`from User u select u.@id, u.wish where u.@id == #pablo`);
  p.assertResultEquals("testDeleteSQLNeoCascadeFromEnd", rs, <["u.@id", "u.wish"], [[U("pablo"), {}]]>);
  
}

void testUpdateSingleRefSQLNeo(PolystoreInstance p) {
  p.runUpdate((Request)`update Wish w where w.@id == #wish1 set {product: #radio}`);
  rs = p.runQuery((Request)`from Wish w select w.@id, w.product where w.@id == #wish1`);
  p.assertResultEquals("testUpdateRefSQLNeo", rs, <["w.@id", "w.product"], [[ U("wish1"), U("radio")]]>);
  rs = p.runQuery((Request)`from Product p select p.@id, p.wish where p.@id == #radio`);
  p.assertResultEquals("testUpdateRefSQLNeoTo", rs, <["p.@id", "p.wish"], [[ U("radio"), U("wish1")]]>);
  rs = p.runQuery((Request)`from Product p select p.@id, p.wish where p.@id == #tv`);
  p.assertResultEquals("testUpdateRefSQLNeoFormerTo", rs, <["p.@id", "p.wish"], [[ U("radio"), {}]]>);
}

void testUpdateAttrNeo(PolystoreInstance p) {
  p.runUpdate((Request)`update Wish w where w.@id == #wish1 set {intensity: 3}`);
  rs = p.runQuery((Request)`from Wish w select w.@id, w.intensity where w.@id == #wish1`);
  p.assertResultEquals("testUpdateAttrNeo", rs, <["w.@id", "w.intensity"], [[ U("wish1"), 3]]>);
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
  p.runUpdateWithBlobs((Request)`insert Review { @id: #newReview, content: "super!", user: #davy, location: #point(1.0 1.0), screenshot: #blob:s5 }`, (U("s5") : "uu"));
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
  p.runUpdateWithBlobs((Request)`insert Review { @id: #newReview, content: "super!", user: #davy, location: #point(1.0 1.0), screenshot: #blob:s6 }`, (U("s6") : "uu"));
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
  p.assertResultEquals("selectViaSQLInverseLocal", rs, <["i.shelf"], [[1], [1], [3], [3]]>);
}

void testSelectViaSQLKidLocal(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Item i, Product p select i.shelf where p.@id == #tv, p.inventory == i`);
  p.assertResultEquals("selectViaSQLKidLocal", rs, <["i.shelf"], [[1], [1], [3], [3]]>);
}


void testSQLDateEquals(PolystoreInstance p) {
  rs = p.runQuery((Request)`from Product p select p.name, p.productionDate where p.productionDate == $2020-04-13$`);
  p.assertResultEquals("sqlDateEquals", rs, <["p.name", "p.productionDate"], [["Radio", "2020-04-13"],["TV", "2020-04-13"]]>);
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


  rs = p.runQuery((Request)`from Product p select p.name where #point(2.0 3.0) & p.availabilityRegion`);
  p.assertResultEquals("testGISonSQLIntersectLiteral", rs, <["p.name"], [["TV"]]>);
  

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

void testGISPrint(PolystoreInstance p) {
    rs = p.runQuery((Request)`from Product p select p.availabilityRegion`);
    p.assertResultEquals("GIS Print - SQL", rs, <["p.availabilityRegion"], [["POLYGON ((10 10, 40 10, 40 40, 10 40, 10 10))"],["POLYGON ((1 1, 4 1, 4 4, 1 4, 1 1))"]]>);


    rs = p.runQuery((Request)`from Review r select r.location`);
    p.assertResultEquals("GIS Print - Mongo", rs, <["r.location"], [["POINT (2 3)"],["POINT (20 30)"], ["POINT (3 2)"]]>);
}


void testInsertNeo(PolystoreInstance p) {
  // TODO: this shows the cyclic reference problem we still need to solve.
  // NB: we have to insert the product first.

  // inventory: [#laptop1, #laptop2], 
  p.runUpdate((Request) `insert User { @id: #paul, name: "Paul", location: #point(2.0 3.0), photoURL: "klint",
	                      '  billing: address( street: "Eigth", city: "Ams"
	                      '   , zipcode: zip(nums: "1234", letters: "ab")
	                      '   , location: #point(2.0 3.0))}`);
  rs = p.runQuery((Request)`from User u select u.@id, u.name where u.name == "Paul"`);
  p.assertResultEquals("users were inserted", rs, <["u.@id", "u.name"], [[U("paul"), "Paul"]]>);
	 
  p.runUpdate((Request) `insert Wish { @id: #wish2, intensity: 7, user: #paul, product: #tv }`);
	
  rs = p.runQuery((Request)`from Wish w select w.@id, w.intensity where w.@id ==#wish2`);
  p.assertResultEquals("items were inserted", rs, <["w.@id", "w.intensity"], [
	    [U("wish2"), 7]
	  ]>);
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
						  [
						   ["\"IPhone\"", "\"Apple\""],
				           ["\"Samsung S10\"", "\"Samsung\""]]);
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
	p.runUpdate((Request) `insert User { @id: #tijs, name: "Tijs", <KeyVal aBillingKeyVal>, location: #point(1.0 1.0), address: "a", avatarURL: "b", photoURL: "c" }`);
	rs = p.runQuery((Request) `from User u select u.@id where u.@id == #tijs`);
	p.assertResultEquals("basic insert in sql", rs, <["u.@id"],[[U("tijs")]]>);
}

void test13(PolystoreInstance p) {
	<_, names> = p.runUpdate((Request) `insert User { name: "Tijs", <KeyVal aBillingKeyVal>, location: #point(1.0 1.0), address: "a", avatarURL: "b", photoURL: "c" }`);
	p.assertEquals("one insert is one object inserted", size(names), 1);
	uuid = names["uuid"];
	rs = p.runQuery([Request] "from User u select u.@id where u.@id == #<uuid>");
	p.assertResultEquals("generated id is in the result", rs, <["u.@id"],[["<uuid>"]]>);
}


TestExecuter executer(Log log = NO_LOG()) = initTest(setup, HOST, PORT, USER, PASSWORD, log = log);

void runTest(void(PolystoreInstance) t, Log log = NO_LOG(), bool runTestsInSetup = false) {
	 executer(log = log).runTest(t, runTestsInSetup); 
}

void runTests(list[void(PolystoreInstance)] ts, Log log = NO_LOG(), bool runTestsInSetup = false) {
	executer(log = log).runTests(ts, runTestsInSetup); 
}

Schema fetchSchema() {
	return executer().fetchSchema();
}

Schema printSchema() {
	executer().printSchema();
}


void runTests(Log log = NO_LOG(), bool runTestsInSetup = false) {
	tests = 
	  [ testKeyValueFeatures
	  , testCustomDataTypes
	  , testLoneVars
	  , testInsertSingleValuedSQLCross
	  , testInsertManyValuedSQLLocal
	  , testDeleteAllSQLBasic
	  , testDeleteAllWithCascade
	  , testDeleteKidsRemovesParentLinksSQLLocal
	  , testDeleteKidsRemovesParentLinksSQLCross

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
	  
	  , testSQLDateEquals
	  
	  , testGISonSQL
	  , testGISonMongo
	  , testGISonCrossMongoSQL
	  , testGISPrint
	  
	  , testBlobs
	  
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
	runTests(tests, log = log, runTestsInSetup = runTestsInSetup);
}

void runNeoTests(Log log = NO_LOG()) {
	tests = 
	  [ testInsertSQLNeo,
	  testDeleteSQLNeoSimple,
	  testDeleteSQLNeoCascade,
	  testUpdateSingleRefSQLNeo,
	  testUpdateAttrNeo,
	  testInsertNeo
	];
	runTests(tests, log = log);
}

