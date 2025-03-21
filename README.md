
<h1 align="center">
  Processing mapping files for the omics FixID tool
</h1>
<p align="center">
    <a href="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/maven.yml">
        <img alt="Java CI with Maven" src="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/maven.yml/badge.svg" />
    </a>
    <a href="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/chebi.yml">
        <img alt="ChEBI" src="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/chebi.yml/badge.svg" />
    </a>
    <a href="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/hmdb.yml">
        <img alt="HMDB" src="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/hmdb.yml/badge.svg" />
    </a>
    <a href="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/hgnc.yml">
        <img alt="HGNC" src="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/hgnc.yml/badge.svg" />
    </a>
    <a href='https://github.com/sec2pri/mapping_preprocessing/actions/workflows/ncbi.yml'>
        <img src='https://github.com/sec2pri/mapping_preprocessing/actions/workflows/ncbi.yml/badge.svg' alt="NCBI" />
    </a>
    <a href="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/uniprot.yml">
        <img src="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/uniprot.yml/badge.svg" alt="UniProt" />
    </a>  
    <a href="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/wikidata.yml">
        <img alt="Wikidata" src="https://github.com/sec2pri/mapping_preprocessing/actions/workflows/wikidata.yml/badge.svg" /> 
    </a>
</p>

In this repository, the details of data processing to create mapping files for the omics FixID tool are explained. Most of the data processing is done in R, and some is done in Java when the input is too large to be processed in R.

| Datasource | license | citation |
|-----------------|-----------------|-----------------|
| [ChEBI](https://github.com/sec2pri/mapping_preprocessing/blob/main/datasources/chebi/config) | [CC BY 4.0](https://www.ebi.ac.uk/chebi/aboutChebiForward.do#:~:text=The%20data%20on%20this%20website%20is%20available%20under%20the%20Creative%20Commons%20License%20(CC%20BY%204.0).) | Hastings J, Owen G, Dekker A, et al. ChEBI in 2016: Improved services and an expanding collection of metabolites. Nucleic Acids Research. 2016 Jan;44(D1):D1214-9. DOI: 10.1093/nar/gkv1031. PMID: 26467479; PMCID: PMC4702775.|
| [HMDB](https://github.com/sec2pri/mapping_preprocessing/blob/main/datasources/hmdb/config) | [CC0](https://hmdb.ca/about#compliance:~:text=international%20scientific%20conferences.-,Citing%20the%20HMDB,-HMDB%20is%20offered) | Wishart DS, Guo A, Oler E, Wang F, Anjum A, Peters H, Dizon R, Sayeeda Z, Tian S, Lee BL, Berjanskii M, Mah R, Yamamoto M, Jovel J, Torres-Calzada C, Hiebert-Giesbrecht M, Lui VW, Varshavi D, Varshavi D, Allen D, Arndt D, Khetarpal N, Sivakumaran A, Harford K, Sanford S, Yee K, Cao X, Budinski Z, Liigand J, Zhang L, Zheng J, Mandal R, Karu N, Dambrova M, Schiöth HB, Greiner R, Gautam V. HMDB 5.0: the Human Metabolome Database for 2022. Nucleic Acids Res. 2022 Jan 7;50(D1):D622-D631. doi: 10.1093/nar/gkab1062. PMID: 34986597; PMCID: PMC8728138.|
| [HGNC](https://github.com/sec2pri/mapping_preprocessing/blob/main/datasources/hgnc/config) | [link](https://www.genenames.org/about/license/) | Seal RL, Braschi B, Gray K, Jones TEM, Tweedie S, Haim-Vilmovsky L, Bruford EA. Genenames.org: the HGNC resources in 2023. Nucleic Acids Res. 2023 Jan 6;51(D1):D1003-D1009. doi: 10.1093/nar/gkac888. PMID: 36243972; PMCID: PMC9825485. |
| [NCBI](https://github.com/sec2pri/mapping_preprocessing/blob/main/datasources/ncbi/config) | [link](https://www.ncbi.nlm.nih.gov/home/about/policies/) | Sayers EW, Bolton EE, Brister JR, Canese K, Chan J, Comeau DC, Connor R, Funk K, Kelly C, Kim S, Madej T, Marchler-Bauer A, Lanczycki C, Lathrop S, Lu Z, Thibaud-Nissen F, Murphy T, Phan L, Skripchenko Y, Tse T, Wang J, Williams R, Trawick BW, Pruitt KD, Sherry ST. Database resources of the national center for biotechnology information. Nucleic Acids Res. 2022 Jan 7;50(D1):D20-D26. doi: 10.1093/nar/gkab1112. PMID: 34850941; PMCID: PMC8728269. |
| [UniProt](https://github.com/sec2pri/mapping_preprocessing/blob/main/datasources/uniprot/config) | [CC BY 4.0](https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/complete/LICENSE) | UniProt Consortium. UniProt: the universal protein knowledgebase in 2021. Nucleic Acids Res. 2021 Jan 8;49(D1):D480-D489. doi: 10.1093/nar/gkaa1100. PMID: 33237286; PMCID: PMC7778908. |


--------
To install those in Java, you can follow the steps below:

Installation
--------
Java 11 is required.

```shell
cd java
mvn clean install assembly:single
```

How to create mapping files
--------
1) ChEBI SDF 

```shell
java -cp target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.chebi_sdf $inputFile $outputDir
```

2) HMDB XML

```shell
java -cp target/mapping_prerocessing-0.0.1-jar-with-dependencies.jar org.sec2pri.hmdb_xml $inputFile $outputDir
```

**`InputFile`:** the input file;

**`outputDir`:** the directory in which the output should be saved.


Releases
--------
The mapping files are released and archived on [Zenodo]()



