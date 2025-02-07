// This connector provides a Direct Query enabled connector
// based on MySQL ODBC driver. It is specially optimized and customized
// for AnalyticDB MySQL.
//
[Version = "1.0.0"]
section AnalyticDB.MySQL;

// When set to true, additional trace information will be written out to the User log.
// This should be set to false before release. Tracing is done through a call to
// Diagnostics.LogValue(). When EnableTraceOutput is set to false, the call becomes a
// no-op and simply returns the original value.
EnableTraceOutput = true;

/****************************
 * ODBC Driver Configuration
 ****************************/
// The name of your ODBC driver.
//
Config_DriverName = "MySQL ODBC 5.1 Driver";

// If your driver under-reports its SQL conformance level because it does not
// support the full range of CRUD operations, but does support the ANSI SQL required
// to support the SELECT operations performed by Power Query, you can override
// this value to report a higher conformance level. Please use one of the numeric
// values below (i.e. 8 for SQL_SC_SQL92_FULL).
//
// SQL_SC =
// [
//     SQL_SC_SQL92_ENTRY            = 1,
//     SQL_SC_FIPS127_2_TRANSITIONAL = 2,
//     SQL_SC_SQL92_INTERMEDIATE     = 4,
//     SQL_SC_SQL92_FULL             = 8
// ]
//
// Set to null to determine the value from the driver.
//
Config_SqlConformance = ODBC[SQL_SC][SQL_SC_SQL92_FULL];
// null, 1, 2, 4, 8
// This setting controls row count limits and offsets. If not set correctly, query
// folding capabilities for this connector will be extremely limited. You can use
// the LimitClauseKind constants to match common LIMIT/OFFSET SQL formats. If none
// of the supported formats match your desired SQL syntax, consider filing a feature
// request to support your variation.
//
// Supporting OFFSET is considerably less important than supporting LIMIT.
//
// LimitClauseKind values and formats:
//
// LimitClauseKind.Top (LIMIT only, OFFSET not supported)
// -------------------
// SELECT TOP 100 *
// FROM table
//
// LimitClauseKind.Limit (LIMIT only, OFFSET not supported)
// ---------------------
// SELECT *
// FROM table
// LIMIT 100
//
// LimitClauseKind.LimitOffset
// ---------------------------
// SELECT *
// FROM table
// LIMIT 100 OFFSET 200
//
// This option requires that the SQL dialect support all three variations:
// "LIMIT x", "LIMIT x OFFSET y" and "OFFSET y". If your SQL dialect only supports
// OFFSET when LIMIT is also specified, use LimitClauseKind.Limit instead.
//
// LimitClauseKind.AnsiSql2008
// ---------------------------
// SELECT *
// FROM table
// OFFSET 200 ROWS
// FETCH FIRST 100 ROWS ONLY
//
Config_LimitClauseKind = LimitClauseKind.Top;
// see above
// Set this option to true if your ODBC supports the standard username/password
// handling through the UID and PWD connection string parameters. If the user
// selects UsernamePassword auth, the supplied values will be automatically
// added to the CredentialConnectionString.
//
// If you wish to set these values yourself, or your driver requires additional
// parameters to be set, please set this option to 'false'
//
Config_DefaultUsernamePasswordHandling = true;
// true, false
// Some drivers have problems will parameter bindings and certain data types.
// If the driver supports parameter bindings, then set this to true.
// When set to false, parameter values will be inlined as literals into the generated SQL.
// To enable inlining for a limited number of data types, set this value
// to null and set individual flags through the SqlCapabilities record.
//
// Set to null to determine the value from the driver.
//
Config_UseParameterBindings = null;
// true, false, null
// Override this setting to force the character escape value.
// This is typically done when you have set UseParameterBindings to false.
//
// Set to null to determine the value from the driver.
//
Config_StringLiteralEscapeCharacters  = { "'" }; // ex. { "'" } or { {"\", "\\"}, {"'", "\'"} }

// Override this if the driver expects the use of CAST instead of CONVERT.
// By default, the query will be generated using ANSI SQL CONVERT syntax.
//
// Set to null to leave default behavior.
//
Config_UseCastInsteadOfConvert = null;
// true, false, null
// Set this to true to enable Direct Query in addition to Import mode.
//
Config_EnableDirectQuery = true;

DefaultPort = 3306;


[DataSource.Kind="AnalyticDB.MySQL", Publish="AnalyticDB.MySQL.Publish"]
shared AnalyticDB.MySQL.Contents = Value.ReplaceType(AnalyticDBDatabaseImpl, AnalyticDBDatabaseType);

AnalyticDBDatabaseType = type function (
    server as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Server_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Server_FieldDescription"),
        Documentation.SampleValues = { Extension.LoadString("GetData_Server_FieldSample") }
    ]),
    optional database as (type text meta [
        Documentation.FieldCaption = Extension.LoadString("GetData_Database_FieldCaption"),
        Documentation.FieldDescription = Extension.LoadString("GetData_Database_FieldDescription"),
        Documentation.SampleValues = { Extension.LoadString("GetData_Database_FieldSample") }
    ]),
    optional options as (type nullable [
        optional ConnectionTimeout = (type number meta [
            Documentation.FieldCaption = Extension.LoadString("Options_ConnectionTimeout_FieldCaption"),
            Documentation.FieldDescription = Extension.LoadString("Options_ConnectionTimeout_FieldDesc"),
            Documentation.SampleValues = { Extension.LoadString("Options_ConnectionTimeout_FieldSample") }
        ]),
        optional ReadTimeout = (type number meta [
            Documentation.FieldCaption = Extension.LoadString("Options_ReadTimeout_FieldCaption"),
            Documentation.FieldDescription = Extension.LoadString("Options_ReadTimeout_FieldDesc"),
            Documentation.SampleValues = { Extension.LoadString("Options_ReadTimeout_FieldSample") }
        ]),
        optional WriteTimeout = (type number meta [
            Documentation.FieldCaption = Extension.LoadString("Options_WriteTimeout_FieldCaption"),
            Documentation.FieldDescription = Extension.LoadString("Options_WriteTimeout_FieldDesc"),
            Documentation.SampleValues = { Extension.LoadString("Options_WriteTimeout_FieldSample") }
        ])
      ] meta [
          Documentation.FieldCaption = Extension.LoadString("OptionsFieldCaption")
      ])
) as table meta[
    Documentation.Name = Extension.LoadString("GetData_Title"),
    Documentation.DisplayName = Extension.LoadString("GetData_Title"),
    Documentation.Caption = Extension.LoadString("GetData_Title")
];

AnalyticDBDatabaseImpl = (server as text, optional db as text, optional options as record) =>
    let
        Address = ParseAddress(server),
        ServerHost = Address[Host],
        ServerPort = Address[Port],
        ServerDatabase = Address[Database],
        database = if db <> null and db <> "" then db else ServerDatabase,

        // Many data sources accept an optional 'options' record that allows users to change
        // default behaviors about the connection, such as connection timeout. Use this map
        // to define the appropriate options for your ODBC Driver. If you do not want to support
        // an options record, remove the ValidOptionsMap variable and options parameter from
        // the data source function.
        ValidOptionsMap = #table(
            {"Name", "Type", "Description", "Default", "Validate"},
            {
                {
                    "ConnectionTimeout",
                    type nullable number,
                    "non-negative integers",
                    null,
                    each _ = null or (_ >= 0 and Number.RoundDown(_) = _)
                },
                {
                    "ReadTimeout",
                    type nullable number,
                    "non-negative integers",
                    null,
                    each _ = null or (_ >= 0 and Number.RoundDown(_) = _)
                },
                {
                    "WriteTimeout",
                    type nullable number,
                    "non-negative integers",
                    null,
                    each _ = null or (_ >= 0 and Number.RoundDown(_) = _)
                }
            }
        ),
        ValidatedOptions = ValidateOptions(options, ValidOptionsMap),
        //
        // Connection string settings
        //
        ConnectionString =  Record.Combine({[
            // At minimum you need to specify the ODBC Driver to use.
            Driver = Config_DriverName,
            // Specify custom properties for your ODBC Driver here.
            // The fields below are appropriate for the SQL Server ODBC Driver. The
            // names might be different for your data source.
            Server = ServerHost,
            Port = ServerPort,
            // These fields come from the options record, so they might be null.
            // A later step will strip all null values from the connection string.
            ConnectionTimeout = ValidatedOptions[ConnectionTimeout]?,
            ReadTimeout = ValidatedOptions[ReadTimeout]?,
            WriteTimeout = ValidatedOptions[WriteTimeout]?
            ], 
            if database <> null then [Database = database] else []
        }),
        //
        // Handle credentials
        // Credentials are not persisted with the query and are set through a separate
        // record field - CredentialConnectionString. The base Odbc.DataSource function
        // will handle UsernamePassword authentication automatically, but it is explictly
        // handled here as an example.
        //
        Credential = Extension.CurrentCredential(),
        CredentialConnectionString =
            if Credential[AuthenticationKind]? = "UsernamePassword" then
                // set connection string parameters used for basic authentication
                [UID = Credential[Username], PWD = Credential[Password]]
            else if (Credential[AuthenticationKind]? = "Windows") then
                // set connection string parameters used for windows/kerberos authentication
                [Trusted_Connection = "Yes"]
            else
                error Error.Record("Error", "Unhandled authentication kind: " & Credential[AuthenticationKind]?),
        //
        // Configuration options for the call to Odbc.DataSource
        //
        defaultConfig = Diagnostics.LogValue("BuildOdbcConfig", BuildOdbcConfig()),
        SqlCapabilities = Diagnostics.LogValue(
            "SqlCapabilities_Options", defaultConfig[SqlCapabilities] & [
                // Place custom overrides here
                // The values below are required for the SQL Native Client ODBC driver, but might
                // not be required for your data source.
                FractionalSecondsScale = 3
            ]
        ),
        // Please refer to the ODBC specification for SQLGetInfo properties and values.
        // https://github.com/Microsoft/ODBC-Specification/blob/master/Windows/inc/sqlext.h
        SQLGetInfo = Diagnostics.LogValue(
            "SQLGetInfo_Options",
            defaultConfig[SQLGetInfo]
                & [
                    // Place custom overrides here
                    // The values below are required for the SQL Native Client ODBC driver, but might
                    // not be required for your data source.
                    SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
                    SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All]
                ]
        ),
        // SQLGetTypeInfo can be specified in two ways:
        // 1. A #table() value that returns the same type information as an ODBC
        //    call to SQLGetTypeInfo.
        // 2. A function that accepts a table argument, and returns a table. The
        //    argument will contain the original results of the ODBC call to SQLGetTypeInfo.
        //    Your function implementation can modify/add to this table.
        //
        // For details of the format of the types table parameter and expected return value,
        // please see: https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlgettypeinfo-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification.
        SQLGetTypeInfo = (types) =>
            let
                typesFiltered = Table.SelectRows(types, each not Text.Contains(_[TYPE_NAME], "BIGINT")),
                FixColumns = (row) as record =>
                    if row[TYPE_NAME] = "varchar" then
                        Record.TransformFields(row, {
                            { "DATA_TYPE", (val) => -9 },
                            { "COLUMN_SIZE", (val) => 65532 }
                            })
                    else if row[TYPE_NAME] = "float" then
                        Record.TransformFields(row, {
                            { "SEARCHABLE", (val) => 3 }
                            })
                    else
                        row,
                TransformedRows = Table.TransformRows(typesFiltered, each FixColumns(_)), // metadata loss happens here
                EmptyTableWithColumnTypes = Table.FirstN(typesFiltered, 0), // get an empty table with the original column data types
                typesFixed = Table.InsertRows(EmptyTableWithColumnTypes, 0, TransformedRows) // insert the transformed data into the empty table with correct metadata
            in
                if (EnableTraceOutput <> true) then
                    typesFixed
                else
                    let
                        // Outputting the entire table might be too large, and result in the value being truncated.
                        // We can output a row at a time instead with Table.TransformRows()
                        rows = Table.TransformRows(typesFixed, each Diagnostics.LogValue("SQLGetTypeInfo " & _[TYPE_NAME], _)),
                        toTable = Table.FromRecords(rows)
                    in
                        Value.ReplaceType(toTable, Value.Type(typesFixed))
        ,
        // SQLColumns is a function handler that receives the results of an ODBC call
        // to SQLColumns(). The source parameter contains a table with the data type
        // information. This override is typically used to fix up data type mismatches
        // between calls to SQLGetTypeInfo and SQLColumns.
        //
        // For details of the format of the source table parameter, please see:
        // https://docs.microsoft.com/en-us/sql/odbc/reference/syntax/sqlcolumns-function
        //
        // The sample implementation provided here will simply output the original table
        // to the user trace log, without any modification.
        SQLColumns = (catalogName, schemaName, tableName, columnName, source) =>
            if (EnableTraceOutput <> true) then
                source
            else
            // the if statement conditions will force the values to evaluated/written to diagnostics
            if (
                Diagnostics.LogValue("SQLColumns.TableName", tableName) <> "***"
                and Diagnostics.LogValue("SQLColumns.ColumnName", columnName) <> "***"
            ) then
                let
                    // Outputting the entire table might be too large, and result in the value being truncated.
                    // We can output a row at a time instead with Table.TransformRows()
                    rows = Table.TransformRows(source, each Diagnostics.LogValue("SQLColumns", _)),
                    toTable = Table.FromRecords(rows)
                in
                    Value.ReplaceType(toTable, Value.Type(source))
            else
                source
        ,
        // Remove null fields from the ConnectionString
        ConnectionStringNoNulls = Record.SelectFields(
            ConnectionString, Table.SelectRows(Record.ToTable(ConnectionString), each [Value] <> null)[Name]
        ),
        OdbcDatasource = Odbc.DataSource(
            ConnectionStringNoNulls,
            [
                // A logical (true/false) that sets whether to view the tables grouped by their schema names
                HierarchicalNavigation = true,
                // Allows upconversion of numeric types
                SoftNumbers = true,
                // Allow upconversion / resizing of numeric and string types
                TolerateConcatOverflow = true,
                // Enables connection pooling via the system ODBC manager
                ClientConnectionPooling = true,
                // These values should be set by previous steps
                CredentialConnectionString = CredentialConnectionString,
                SqlCapabilities = SqlCapabilities,
                SQLColumns = SQLColumns,
                SQLGetInfo = SQLGetInfo,
                SQLGetTypeInfo = SQLGetTypeInfo
            ]
        )
    in
        OdbcDatasource;

// Data Source Kind description
AnalyticDB.MySQL = [
    // Set the TestConnection handler to enable gateway support.
    // The TestConnection handler will invoke your data source function to
    // validate the credentials the user has provider. Ideally, this is not
    // an expensive operation to perform. By default, the dataSourcePath value
    // will be a json string containing the required parameters of your data
    // source function. These should be parsed and parsed as individual parameters
    // to the specified data source function.
    TestConnection = (dataSourcePath) =>
        let
            json = Json.Document(dataSourcePath), server = json[server]
            // name of function parameter
        in
            {"AnalyticDB.MySQL", server},
    // Set supported types of authentication
    Authentication = [
        // Windows = [],
        UsernamePassword = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
AnalyticDB.MySQL.Publish = [
    Beta = true,
    Category = Extension.LoadString("Category"),
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = Extension.LoadString("LearnMoreURL"),
    SupportsDirectQuery = Config_EnableDirectQuery,
    SourceImage = AnalyticDB.MySQL.Icons,
    SourceTypeImage = AnalyticDB.MySQL.Icons
];

AnalyticDB.MySQL.Icons = [
    Icon16 = { 
        Extension.Contents("AnalyticDB.MySQL16.png"), 
        Extension.Contents("AnalyticDB.MySQL20.png"), 
        Extension.Contents("AnalyticDB.MySQL24.png"), 
        Extension.Contents("AnalyticDB.MySQL32.png") 
    },
    Icon32 = { 
        Extension.Contents("AnalyticDB.MySQL32.png"), 
        Extension.Contents("AnalyticDB.MySQL40.png"), 
        Extension.Contents("AnalyticDB.MySQL48.png"), 
        Extension.Contents("AnalyticDB.MySQL64.png") 
    }
];

// parse address
ParseAddress = (AnalyticDBServer as text) as record =>
    let
        list = Text.Split(AnalyticDBServer, ";"),
        server = List.First(list),
        database = if List.Count(list) > 1 then List.Last(List.FirstN(list, 2)) else null,
        Address = Uri.Parts("http://" & server),
        BadServer = Address[Host] = "" or Address[Scheme] <> "http" or Address[Path] <> "/" or Address[Query] <> [] or Address[Fragment] <> ""
            or Address[UserName] <> "" or Address[Password] <> "",
        Port = if Address[Port] = 80 and not Text.EndsWith(server, ":80") then 
                DefaultPort 
            else Address[Port],
        Host = Address[Host],
        Result = [Host=Host, Port=Port, Database=database]
    in
        if BadServer then 
            error Extension.LoadString("Error_BadServer")
        else Result;

// build settings based on configuration variables
BuildOdbcConfig = () as record =>
    let
        Merge = (previous as record, optional caps as record, optional funcs as record, optional getInfo as record) as record =>
            let
                newCaps = if (caps <> null) then previous[SqlCapabilities] & caps else previous[SqlCapabilities],
                newFuncs = if (funcs <> null) then previous[SQLGetFunctions] & funcs else previous[SQLGetFunctions],
                newGetInfo = if (getInfo <> null) then previous[SQLGetInfo] & getInfo else previous[SQLGetInfo]
            in
                [SqlCapabilities = newCaps, SQLGetFunctions = newFuncs, SQLGetInfo = newGetInfo],
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],
        withParams =
            if (Config_UseParameterBindings = false) then
                let
                    caps = [
                        SupportsNumericLiterals = true,
                        SupportsStringLiterals = true,
                        SupportsOdbcDateLiterals = true,
                        SupportsOdbcTimeLiterals = true,
                        SupportsOdbcTimestampLiterals = true
                    ],
                    funcs = [
                        SQL_API_SQLBINDPARAMETER = false
                    ]
                in
                    Merge(defaultConfig, caps, funcs)
            else
                defaultConfig,
        withEscape =
            if (Config_StringLiteralEscapeCharacters <> null) then
                let
                    caps = [
                        StringLiteralEscapeCharacters = Config_StringLiteralEscapeCharacters
                    ]
                in
                    Merge(withParams, caps)
            else
                withParams,
        withLimitClauseKind = let caps = [
            LimitClauseKind = Config_LimitClauseKind
        ] in Merge(withEscape, caps),
        withCastOrConvert =
            if (Config_UseCastInsteadOfConvert <> null) then
                let
                    value =
                        if (Config_UseCastInsteadOfConvert = true) then
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CAST]
                        else
                            ODBC[SQL_FN_CVT][SQL_FN_CVT_CONVERT],
                    getInfo = [
                        SQL_CONVERT_FUNCTIONS = value
                    ]
                in
                    Merge(withLimitClauseKind, null, null, getInfo)
            else
                withLimitClauseKind,
        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    getInfo = [
                        SQL_SQL_CONFORMANCE = Config_SqlConformance
                    ]
                in
                    Merge(withCastOrConvert, null, null, getInfo)
            else
                withCastOrConvert
    in
        withSqlConformance;

ValidateOptions = (options as nullable record, validOptionsMap as table) as record =>
    let
        ValidKeys = Table.Column(validOptionsMap, "Name"),
        InvalidKeys = List.Difference(Record.FieldNames(options), ValidKeys),
        InvalidKeysText =
            if List.IsEmpty(InvalidKeys) then
                null
            else
                Text.Format(
                    "'#{0}' are not valid options. Valid options are: '#{1}'",
                    {Text.Combine(InvalidKeys, ", "), Text.Combine(ValidKeys, ", ")}
                ),
        ValidateValue = (name, optionType, description, default, validate, value) =>
            if
                (value is null and (Type.IsNullable(optionType) or default <> null))
                or (Type.Is(Value.Type(value), optionType) and validate(value))
            then
                null
            else
                Text.Format(
                    "This function does not support the option '#{0}' with value '#{1}'. Valid value is #{2}.",
                    {name, value, description}
                ),
        InvalidValues = List.RemoveNulls(
            Table.TransformRows(
                validOptionsMap,
                each
                    ValidateValue(
                        [Name],
                        [Type],
                        [Description],
                        [Default],
                        [Validate],
                        Record.FieldOrDefault(options, [Name], [Default])
                    )
            )
        ),
        DefaultOptions = Record.FromTable(
            Table.RenameColumns(Table.SelectColumns(validOptionsMap, {"Name", "Default"}), {"Default", "Value"})
        ),
        NullNotAllowedFields = List.RemoveNulls(
            Table.TransformRows(
                validOptionsMap,
                each
                    if not Type.IsNullable([Type]) and null = Record.FieldOrDefault(options, [Name], [Default]) then
                        [Name]
                    else
                        null
            )
        ),
        NormalizedOptions = DefaultOptions & Record.RemoveFields(options, NullNotAllowedFields, MissingField.Ignore)
    in
        if null = options then
            DefaultOptions
        else if not List.IsEmpty(InvalidKeys) then
            error Error.Record("Expression.Error", InvalidKeysText)
        else if not List.IsEmpty(InvalidValues) then
            error Error.Record("Expression.Error", Text.Combine(InvalidValues, ", "))
        else
            NormalizedOptions;

//
// Load common library functions
//
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name), asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");

Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;

// OdbcConstants contains numeric constants from the ODBC header files, and a
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");
