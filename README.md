# create-bridgedb-secondary2primary

Creation of secondary to primary mapping database.

Installation
--------
Java 11 is required.

```shell
mvn clean install assembly:single
```

How to create a Derby file
--------

```shell
java -cp target/create-bridgedb-secondary2primary-0.0.1-SNAPSHOT-jar-with-dependencies.jar org.bridgedb.sec2pri.sec2pri $databaseName $separator $databaseCode
```

**`databaseName`:** database name located in the `input` directory. Some examples of input data can be found [here](input/README.md);

**`separator`:** the field separator character;

**`databaseCode`:** the annotation of data sources database, called SytemCodes extracted from [here](https://bridgedb.github.io/pages/system-codes.html).

Releases
--------

The files are released via the [BridgeDb Website](https://bridgedb.github.io/data/gene_database/)

The mapping files are also archived on [Zenodo]()


