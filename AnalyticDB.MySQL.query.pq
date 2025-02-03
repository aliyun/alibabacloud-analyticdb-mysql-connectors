// Use this file to write queries to test your data connector
let
    result = AnalyticDB.MySQL.Contents("localhost"),
    db = result{[Name = "test"]}[Data],
    t1 = db{[Name = "t1"]}[Data]
in
    t1

