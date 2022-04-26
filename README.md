# create-bridgedb-secondary2primary
Introduction
--------
Many biological databases split/merge or withdraw identifiers. 
Below you can see some examples from [HGNC](http://ftp.ebi.ac.uk/pub/databases/genenames/hgnc/tsv/withdrawn.txt):

HGNC_ID|STATUS|WITHDRAWN_SYMBOL|MERGED_INTO_REPORT(S) (i.e HGNC_ID/SYMBOL/STATUS)
:---|:---|:---|:--- 
HGNC:1531|Merged/Split|CBBM|HGNC:4206/OPN1MW/Approved, HGNC:9936/OPN1LW/Approved
HGNC:354|Merged/Split|AIH2|HGNC:3344/ENAM/Approved
HGNC:440|Entry Withdrawn|ALPPL1| 

#### Withdrawn entries (deleted ids)
Some molecular entries were withdrawn/deleted from a database and they won't exist anymore. `HGNC:440` is an example of withdrawn id from HGNC.

#### Split/merged ids
When an id is split or merged in a database, a new id(s) will be used for that specific entity. The new id(s) is called the primary id(s), while the split/merged id is the secondary id, which will not be used anymore.

secondary id|primary id
:---|:---
HGNC:1531|HGNC:4206
HGNC:1531|HGNC:9936
CBBM|OPN1MW
CBBM|OPN1LW
HGNC:354|HGNC:3344
AIH2|ENAM

The split ids may introduce one-to-multiple mapping issues which should be further evaluated.

### Secondary ids vs duplicate ids
In some databases, multiple ids refer to the same entity. We define these ids as duplicate ids. Below you see an example from [HMDB](https://hmdb.ca/metabolites/HMDB0004160):


Version|Status|Creation Date|Update Date|HMDB ID|Secondary Accession Numbers
:---|:---|:---|:---|:---|:---
5.0|Detected and Quantified|2006-08-13 13:18:56 UTC|2021-09-14 14:59:00 UTC|HMDB0004160|HMDB0004159, HMDB0004161, HMDB04159, HMDB04160, HMDB04161

In this case, the id, currently used by the databases to refer to the entity, is the primary id.
duplicate id|primary id
:---|:---
HMDB0004159|HMDB0004160
HMDB0004161|HMDB0004160
HMDB04159|HMDB0004160
HMDB04160|HMDB0004160
HMDB04161|HMDB0004160

The BridgeDb project is collecting this information to create secondary to primary mapping databases, which will improve data interoperability.


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


<<<<<<< HEAD

=======
>>>>>>> ed07d1ab68684852275f9e69f7a34064684d625b
