// Use this file to write queries to test your data connector
let
    result = AnalyticDB.MySQL.Database("localhost", "test", [
        ConnectionTimeout = 10,
        ReadTimeout = 60,
        WriteTimeout = 60,
        NoCache = 1,
        ForwardCursor = 1
    ]),
    db = result{[Name = "test"]}[Data],
    t1 = db{[Name = "t1"]}[Data]
in
    t1
