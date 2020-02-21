
# TyphonQL: an Evolving Reference

## Introduction

## Example TyphonML Model

```
datatype String
datatype int
datatype Date

entity User {
    name: String
    age: int
    reviews -> Review."Review.author"[0..*]
    orders -> Order."Order.user"[0..*]
    paymentInfo :-> CreditCard."CreditCard.owner"[0..*]
}

entity CreditCard {
  number: String
  expires: Date
  owner -> User."User.paymentInfo"[1]
}

entity Product {
    name : String
    description : String
    price : int
    reviews :-> Review."Review.product"[0..*]
    orders -> Order."Order.product"[0..*]
}

entity Order {
  user -> User."User.orders"[1]
  product -> Product."Product.orders"[1]
  amount: int
  date: Date
}

entity Review {
    text : String
    product -> Product."Product.reviews"[1]
    author -> User."User.reviews"[1]
    replies :-> Comment [0..*]
}

entity Comment {
  review -> Review."Review.replies"[0..1]
  text: String
  replies :-> Comment[0..1]
  author -> User[0..1]
}

relationaldb Inventory {
    tables { 
      table { User : User }
      table { Product : Product }
      table { CreditCard : CreditCard }
      table { Order : Order }
    }
}
documentdb Reviews {
    collections { 
      Reviews : Review
      Comments : Comment 
    }
}

```